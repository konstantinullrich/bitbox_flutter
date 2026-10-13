import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:bitbox_flutter/ffi/libbitbox.g.dart';
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

// Must match go/ffi/bridge.h.
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
      : _lib = BitBoxFlutter(_openLibrary()) {
    _ioCallable = NativeCallable<_IoRequestNative>.listener(_onIoRequest);
    _resultCallable = NativeCallable<_ResultNative>.listener(_onResult);
    _lib.BBRegister(_ioCallable.nativeFunction, _resultCallable.nativeFunction);

    _eventCallable = NativeCallable<_EventNative>.listener(_onEvent);
    _lib.BBSetEventCallback(_eventCallable.nativeFunction);
  }

  final BitBoxFlutter _lib;
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

  Future<void> open() => _call((id, _) => _lib.BBOpen(id));

  Future<void> close() => _call((id, _) => _lib.BBClose(id));

  /// Runs pairing; completes once the user accepted or rejected the code on the device.
  /// Returns the resulting status (`unpaired` on success, see [BitboxEvent.status]).
  Future<String> initDevice() =>
      _call((id, _) => _lib.BBInitDevice(id)).then(utf8.decode);

  Future<String> getChannelHash() =>
      _call((id, _) => _lib.BBGetChannelHash(id)).then(utf8.decode);

  Future<void> channelHashVerify(bool ok) =>
      _call((id, _) => _lib.BBChannelHashVerify(id, ok));

  Future<Uint8List> getMasterFingerprint() =>
      _call((id, _) => _lib.BBGetMasterFingerprint(id));

  Future<bool> supportsETH(int chainId) =>
      _call((id, _) => _lib.BBSupportsETH(id, chainId)).then(_toBool);

  Future<bool> supportsLTC() => _call((id, _) => _lib.BBSupportsLTC(id)).then(_toBool);

  Future<bool> supportsERC20(String contractAddress) =>
      _call((id, a) => _lib.BBSupportsERC20(id, a.str(contractAddress))).then(_toBool);

  Future<String> getBTCXPub(
          int coinType, Uint8List keypath, int addressType, bool display) =>
      _call((id, a) => _lib.BBBTCXPub(id, coinType, a.bytes(keypath), keypath.length,
          addressType, display)).then(utf8.decode);

  Future<String> signBTCPsbt(int coinType, String psbt) {
    final encoded = utf8.encode(psbt);
    return _call((id, a) =>
        _lib.BBBTCSignPSBT(id, coinType, a.bytes(encoded), encoded.length))
        .then(utf8.decode);
  }

  Future<Uint8List> signBTCMessage(
          int coinType, Uint8List keypath, Uint8List message) =>
      _call((id, a) => _lib.BBBTCSignMessage(id, coinType, a.bytes(keypath),
          keypath.length, a.bytes(message), message.length));

  Future<String> getETHAddress(
          int chainId, Uint8List keypath, int outputType, bool display) =>
      _call((id, a) => _lib.BBETHGetAddress(id, chainId, a.bytes(keypath),
          keypath.length, outputType, display)).then(utf8.decode);

  Future<Uint8List> signETHTransaction(
    int chainId,
    Uint8List keypath,
    int nonce,
    String gasPriceHex,
    int gasLimit,
    Uint8List recipient,
    String valueHex,
    Uint8List data,
    int recipientAddressCase,
  ) =>
      _call((id, a) => _lib.BBETHSignTransaction(
            id,
            chainId,
            a.bytes(keypath),
            keypath.length,
            nonce,
            a.str(gasPriceHex),
            gasLimit,
            a.bytes(recipient),
            recipient.length,
            a.str(valueHex),
            a.bytes(data),
            data.length,
            recipientAddressCase,
          ));

  Future<Uint8List> signETHTransactionEIP1559(
    int chainId,
    Uint8List keypath,
    int nonce,
    String maxPriorityFeePerGasHex,
    String maxFeePerGasHex,
    int gasLimit,
    Uint8List recipient,
    String valueHex,
    Uint8List data,
    int recipientAddressCase,
  ) =>
      _call((id, a) => _lib.BBETHSignEIP1559(
            id,
            chainId,
            a.bytes(keypath),
            keypath.length,
            nonce,
            a.str(maxPriorityFeePerGasHex),
            a.str(maxFeePerGasHex),
            gasLimit,
            a.bytes(recipient),
            recipient.length,
            a.str(valueHex),
            a.bytes(data),
            data.length,
            recipientAddressCase,
          ));

  Future<Uint8List> signETHRLPTransaction(int chainId, Uint8List keypath,
          String encodedTxHex, bool isEIP1559) =>
      _call((id, a) => _lib.BBETHSignRLPTx(id, chainId, a.bytes(keypath),
          keypath.length, a.str(encodedTxHex), isEIP1559));

  Future<Uint8List> signETHMessage(
          int chainId, Uint8List keypath, Uint8List message) =>
      _call((id, a) => _lib.BBETHSignMessage(id, chainId, a.bytes(keypath),
          keypath.length, a.bytes(message), message.length));

  Future<Uint8List> signETHTypedMessage(
          int chainId, Uint8List keypath, Uint8List jsonMessage) =>
      _call((id, a) => _lib.BBETHSignTypedMessage(id, chainId, a.bytes(keypath),
          keypath.length, a.bytes(jsonMessage), jsonMessage.length));

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
  Future<Uint8List> _call(void Function(int callId, Arena arena) start) {
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
      _lib.BBDeliverIO(reqId, status, arena.bytes(bytes), bytes.length);
    } finally {
      arena.releaseAll();
    }
  }

  /// Copies a Go-owned buffer into Dart memory and frees it.
  Uint8List _takeBytes(Pointer<Uint8> data, int len) {
    if (data == nullptr) return Uint8List(0);
    final bytes = Uint8List.fromList(data.asTypedList(len));
    _lib.BBFree(data);
    return bytes;
  }
}

extension on Arena {
  Pointer<Uint8> bytes(List<int> data) {
    if (data.isEmpty) return nullptr;
    final ptr = allocate<Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    return ptr;
  }

  /// The generated bindings declare C strings as `char *`, i.e. `Pointer<Char>`.
  Pointer<Char> str(String s) => s.toNativeUtf8(allocator: this).cast();
}
