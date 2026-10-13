import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:bitbox_flutter/ffi/libbitbox.g.dart';
import 'package:bitbox_flutter/ffi/utils/arena_extension.dart';
import 'package:bitbox_flutter/src/transport/bitbox_transport.dart';
import 'package:ffi/ffi.dart';

class BitboxFfiException implements Exception {
  BitboxFfiException(this.message);

  final String message;

  @override
  String toString() => 'BitboxFfiException: $message';
}

/// A firmware event with a snapshot of the pairing state.
///
/// During pairing, a `channelHashChanged` event with a non-empty [channelHash] and
/// [channelHashVerified] == false means the code is on the device screen and waiting
/// for the user; a second one with [channelHashVerified] == true follows once accepted.
class BitboxEvent {
  BitboxEvent({
    required this.event,
    required this.status,
    required this.channelHash,
    required this.channelHashVerified,
  });

  factory BitboxEvent.fromJson(Map<String, dynamic> json) => BitboxEvent(
        event: json['event'] as String,
        status: json['status'] as String,
        channelHash: json['channelHash'] as String,
        channelHashVerified: json['channelHashVerified'] as bool,
      );

  /// `channelHashChanged`, `statusChanged` or `attestationCheckDone`.
  final String event;

  /// Device status, e.g. `connected`, `unpaired`, `pairingFailed`, `initialized`.
  final String status;

  /// The pairing code, formatted as on the device (two lines of two 5-char groups).
  final String channelHash;

  final bool channelHashVerified;

  @override
  String toString() =>
      'BitboxEvent($event, status: $status, verified: $channelHashVerified)';
}

const _ioRead = 0;
const _ioWrite = 1;
const _ioClose = 2;

typedef _IoRequestNative = Void Function(
    Int64 reqId, Int32 op, Pointer<Uint8> data, Int32 len);
typedef _ResultNative = Void Function(
    Int64 callId, Int32 status, Pointer<Uint8> data, Int32 len);

typedef _EventNative = Void Function(Pointer<Uint8> data, Int32 len);

DynamicLibrary _openLibrary() {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libbitbox.so');
  }
  if (Platform.isWindows) return DynamicLibrary.open('bitbox.dll');
  // iOS/macOS: statically linked into the app or bundled via the podspec.
  return DynamicLibrary.process();
}

class BitboxFfi {
  BitboxFfi(this._transport)
      : lib = BitBoxFlutter(_openLibrary()) {
    _ioCallable = NativeCallable<_IoRequestNative>.listener(_onIoRequest);
    _resultCallable = NativeCallable<_ResultNative>.listener(_onResult);
    lib.BBRegister(_ioCallable.nativeFunction, _resultCallable.nativeFunction);

    _eventCallable = NativeCallable<_EventNative>.listener(_onEvent);
    lib.BBSetEventCallback(_eventCallable.nativeFunction);
  }

  final BitBoxFlutter lib;
  final BitboxTransport _transport;

  late final NativeCallable<_IoRequestNative> _ioCallable;
  late final NativeCallable<_ResultNative> _resultCallable;
  late final NativeCallable<_EventNative> _eventCallable;

  final _events = StreamController<BitboxEvent>.broadcast();

  /// Firmware events; listen before [initDevice] to receive the pairing code.
  Stream<BitboxEvent> get events => _events.stream;

  int _nextCallId = 0;
  final _pending = <int, Completer<Uint8List>>{};

  // --- Public API -------------------------------------------------------------------------

  Future<void> open() => call((id, _) => lib.BBOpen(id));

  Future<void> close() => call((id, _) => lib.BBClose(id));

  /// Runs pairing; completes once the user accepted or rejected the code on the device.
  /// Returns the resulting status (`unpaired` on success, see [BitboxEvent.status]).
  Future<String> initDevice() =>
      call((id, _) => lib.BBInitDevice(id)).then(utf8.decode);

  Future<String> getChannelHash() =>
      call((id, _) => lib.BBGetChannelHash(id)).then(utf8.decode);

  Future<void> channelHashVerify(bool ok) =>
      call((id, _) => lib.BBChannelHashVerify(id, ok));

  Future<Uint8List> getMasterFingerprint() =>
      call((id, _) => lib.BBGetMasterFingerprint(id));

  Future<bool> supportsETH(int chainId) =>
      call((id, _) => lib.BBSupportsETH(id, chainId)).then(_toBool);

  Future<bool> supportsLTC() => call((id, _) => lib.BBSupportsLTC(id)).then(_toBool);

  Future<bool> supportsERC20(String contractAddress) =>
      call((id, a) => lib.BBSupportsERC20(id, a.str(contractAddress))).then(_toBool);

  /// Releases the callbacks. Only call once no Go operation is in flight.
  void dispose() {
    _ioCallable.close();
    _resultCallable.close();
    _eventCallable.close();
    _events.close();
    for (final c in _pending.values) {
      c.completeError(BitboxFfiException('disposed'));
    }
    _pending.clear();
  }

  // --- Calls: Dart -> Go -> result callback -----------------------------------------------

  /// Starts a Go call. Arguments allocated from the arena are freed as soon as [start]
  /// returns, which is safe because every export copies its inputs synchronously.
  Future<Uint8List> call(void Function(int callId, Arena arena) start) {
    final id = _nextCallId++;
    final completer = Completer<Uint8List>();
    _pending[id] = completer;
    final arena = Arena();
    try {
      start(id, arena);
    } catch (_) {
      _pending.remove(id);
      rethrow;
    } finally {
      arena.releaseAll();
    }
    return completer.future;
  }

  void _onResult(int callId, int status, Pointer<Uint8> data, int len) {
    final bytes = _takeBytes(data, len);
    final completer = _pending.remove(callId);
    if (completer == null) return;
    if (status == 0) {
      completer.complete(bytes);
    } else {
      completer.completeError(BitboxFfiException(utf8.decode(bytes)));
    }
  }

  void _onEvent(Pointer<Uint8> data, int len) {
    final json = jsonDecode(utf8.decode(_takeBytes(data, len)));
    _events.add(BitboxEvent.fromJson(json as Map<String, dynamic>));
  }

  static bool _toBool(Uint8List bytes) => bytes.isNotEmpty && bytes[0] == 1;

  // --- I/O: Go -> Dart transport -> BBDeliverIO -------------------------------------------

  void _onIoRequest(int reqId, int op, Pointer<Uint8> data, int len) {
    final Future<List<int>> io = switch (op) {
      _ioRead => _transport.read(len),
      _ioWrite => _transport.write(_takeBytes(data, len)).then((_) => const []),
      _ioClose => _transport.close().then((_) => const []),
      _ => Future.error('unknown io op $op'),
    };
    io.then(
      (bytes) => _deliver(reqId, 0, bytes),
      onError: (Object e) => _deliver(reqId, 1, utf8.encode('$e')),
    );
  }

  void _deliver(int reqId, int status, List<int> bytes) {
    final arena = Arena();
    try {
      lib.BBDeliverIO(reqId, status, arena.bytes(bytes), bytes.length);
    } finally {
      arena.releaseAll();
    }
  }

  /// Copies a Go-owned buffer into Dart memory and frees it.
  Uint8List _takeBytes(Pointer<Uint8> data, int len) {
    if (data == nullptr) return Uint8List(0);
    final bytes = Uint8List.fromList(data.asTypedList(len));
    lib.BBFree(data);
    return bytes;
  }
}
