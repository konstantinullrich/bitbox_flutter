import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Raw USB access to a BitBox. Implemented per platform (e.g. a method channel to Kotlin
/// doing `bulkTransfer` on a background thread, or hidapi on desktop).
abstract interface class BitboxTransport {
  Future<Uint8List> read(int length);

  Future<void> write(Uint8List data);

  Future<void> close();
}

class BitboxFfiException implements Exception {
  BitboxFfiException(this.message);

  final String message;

  @override
  String toString() => 'BitboxFfiException: $message';
}

// Must match go/ffi/bridge.h.
const _ioRead = 0;
const _ioWrite = 1;
const _ioClose = 2;

typedef _IoRequestNative = Void Function(
    Int64 reqId, Int32 op, Pointer<Uint8> data, Int32 len);
typedef _ResultNative = Void Function(
    Int64 callId, Int32 status, Pointer<Uint8> data, Int32 len);

typedef _CallC = Void Function(Int64);
typedef _CallDart = void Function(int);

DynamicLibrary _openLibrary() {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libbitbox.so');
  }
  if (Platform.isWindows) return DynamicLibrary.open('bitbox.dll');
  // iOS/macOS: statically linked into the app or bundled via the podspec.
  return DynamicLibrary.process();
}

/// Async bridge to the Go BitBox library (go/ffi).
///
/// No call into Go blocks: Go runs device operations in goroutines, asks Dart for USB
/// transfers through [_onIoRequest] and reports results through [_onResult]. Both are
/// `NativeCallable.listener`s, so Go may invoke them from any thread.
///
/// Keypaths are passed packed (see `packDerivationPath`); big integers as hex strings.
class BitboxFfi {
  BitboxFfi(this._transport, [DynamicLibrary? lib])
      : _lib = lib ?? _openLibrary() {
    _ioCallable = NativeCallable<_IoRequestNative>.listener(_onIoRequest);
    _resultCallable = NativeCallable<_ResultNative>.listener(_onResult);
    _lib.lookupFunction<
        Void Function(Pointer<NativeFunction<_IoRequestNative>>,
            Pointer<NativeFunction<_ResultNative>>),
        void Function(Pointer<NativeFunction<_IoRequestNative>>,
            Pointer<NativeFunction<_ResultNative>>)>('BBRegister')(
        _ioCallable.nativeFunction, _resultCallable.nativeFunction);
  }

  final DynamicLibrary _lib;
  final BitboxTransport _transport;

  late final NativeCallable<_IoRequestNative> _ioCallable;
  late final NativeCallable<_ResultNative> _resultCallable;

  late final _free = _lib.lookupFunction<Void Function(Pointer<Uint8>),
      void Function(Pointer<Uint8>)>('BBFree');
  late final _deliverIO = _lib.lookupFunction<
      Void Function(Int64, Int32, Pointer<Uint8>, Int32),
      void Function(int, int, Pointer<Uint8>, int)>('BBDeliverIO');

  late final _open = _lib.lookupFunction<_CallC, _CallDart>('BBOpen');
  late final _close = _lib.lookupFunction<_CallC, _CallDart>('BBClose');
  late final _initDevice =
      _lib.lookupFunction<_CallC, _CallDart>('BBInitDevice');
  late final _getChannelHash =
      _lib.lookupFunction<_CallC, _CallDart>('BBGetChannelHash');
  late final _channelHashVerify = _lib.lookupFunction<
      Void Function(Int64, Bool), void Function(int, bool)>('BBChannelHashVerify');
  late final _getMasterFingerprint =
      _lib.lookupFunction<_CallC, _CallDart>('BBGetMasterFingerprint');
  late final _supportsETH = _lib.lookupFunction<Void Function(Int64, Int64),
      void Function(int, int)>('BBSupportsETH');
  late final _supportsLTC =
      _lib.lookupFunction<_CallC, _CallDart>('BBSupportsLTC');
  late final _supportsERC20 = _lib.lookupFunction<
      Void Function(Int64, Pointer<Utf8>),
      void Function(int, Pointer<Utf8>)>('BBSupportsERC20');

  late final _btcXPub = _lib.lookupFunction<
      Void Function(Int64, Int32, Pointer<Uint8>, Int32, Int32, Bool),
      void Function(int, int, Pointer<Uint8>, int, int, bool)>('BBBTCXPub');
  late final _btcSignPsbt = _lib.lookupFunction<
      Void Function(Int64, Int32, Pointer<Uint8>, Int32),
      void Function(int, int, Pointer<Uint8>, int)>('BBBTCSignPSBT');
  late final _btcSignMessage = _lib.lookupFunction<
      Void Function(Int64, Int32, Pointer<Uint8>, Int32, Pointer<Uint8>, Int32),
      void Function(
          int, int, Pointer<Uint8>, int, Pointer<Uint8>, int)>('BBBTCSignMessage');

  late final _ethGetAddress = _lib.lookupFunction<
      Void Function(Int64, Int64, Pointer<Uint8>, Int32, Int32, Bool),
      void Function(int, int, Pointer<Uint8>, int, int, bool)>('BBETHGetAddress');
  late final _ethSignTransaction = _lib.lookupFunction<
      Void Function(Int64, Int64, Pointer<Uint8>, Int32, Int64, Pointer<Utf8>,
          Int64, Pointer<Uint8>, Int32, Pointer<Utf8>, Pointer<Uint8>, Int32, Int32),
      void Function(int, int, Pointer<Uint8>, int, int, Pointer<Utf8>, int,
          Pointer<Uint8>, int, Pointer<Utf8>, Pointer<Uint8>, int, int)>(
      'BBETHSignTransaction');
  late final _ethSignEIP1559 = _lib.lookupFunction<
      Void Function(Int64, Int64, Pointer<Uint8>, Int32, Int64, Pointer<Utf8>,
          Pointer<Utf8>, Int64, Pointer<Uint8>, Int32, Pointer<Utf8>,
          Pointer<Uint8>, Int32, Int32),
      void Function(int, int, Pointer<Uint8>, int, int, Pointer<Utf8>,
          Pointer<Utf8>, int, Pointer<Uint8>, int, Pointer<Utf8>,
          Pointer<Uint8>, int, int)>('BBETHSignEIP1559');
  late final _ethSignRLPTx = _lib.lookupFunction<
      Void Function(Int64, Int64, Pointer<Uint8>, Int32, Pointer<Utf8>, Bool),
      void Function(
          int, int, Pointer<Uint8>, int, Pointer<Utf8>, bool)>('BBETHSignRLPTx');
  late final _ethSignMessage = _lib.lookupFunction<
      Void Function(Int64, Int64, Pointer<Uint8>, Int32, Pointer<Uint8>, Int32),
      void Function(
          int, int, Pointer<Uint8>, int, Pointer<Uint8>, int)>('BBETHSignMessage');
  late final _ethSignTypedMessage = _lib.lookupFunction<
      Void Function(Int64, Int64, Pointer<Uint8>, Int32, Pointer<Uint8>, Int32),
      void Function(int, int, Pointer<Uint8>, int, Pointer<Uint8>,
          int)>('BBETHSignTypedMessage');

  int _nextCallId = 0;
  final _pending = <int, Completer<Uint8List>>{};

  // --- Public API -------------------------------------------------------------------------

  Future<void> open() => _call((id, _) => _open(id));

  Future<void> close() => _call((id, _) => _close(id));

  Future<void> initDevice() => _call((id, _) => _initDevice(id));

  Future<String> getChannelHash() =>
      _call((id, _) => _getChannelHash(id)).then(utf8.decode);

  Future<void> channelHashVerify(bool ok) =>
      _call((id, _) => _channelHashVerify(id, ok));

  Future<Uint8List> getMasterFingerprint() =>
      _call((id, _) => _getMasterFingerprint(id));

  Future<bool> supportsETH(int chainId) =>
      _call((id, _) => _supportsETH(id, chainId)).then(_toBool);

  Future<bool> supportsLTC() => _call((id, _) => _supportsLTC(id)).then(_toBool);

  Future<bool> supportsERC20(String contractAddress) =>
      _call((id, a) => _supportsERC20(id, a.str(contractAddress))).then(_toBool);

  Future<String> getBTCXPub(
          int coinType, Uint8List keypath, int addressType, bool display) =>
      _call((id, a) => _btcXPub(id, coinType, a.bytes(keypath), keypath.length,
          addressType, display)).then(utf8.decode);

  Future<String> signBTCPsbt(int coinType, String psbt) {
    final encoded = utf8.encode(psbt);
    return _call((id, a) =>
            _btcSignPsbt(id, coinType, a.bytes(encoded), encoded.length))
        .then(utf8.decode);
  }

  Future<Uint8List> signBTCMessage(
          int coinType, Uint8List keypath, Uint8List message) =>
      _call((id, a) => _btcSignMessage(id, coinType, a.bytes(keypath),
          keypath.length, a.bytes(message), message.length));

  Future<String> getETHAddress(
          int chainId, Uint8List keypath, int outputType, bool display) =>
      _call((id, a) => _ethGetAddress(id, chainId, a.bytes(keypath),
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
      _call((id, a) => _ethSignTransaction(
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
      _call((id, a) => _ethSignEIP1559(
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
      _call((id, a) => _ethSignRLPTx(id, chainId, a.bytes(keypath),
          keypath.length, a.str(encodedTxHex), isEIP1559));

  Future<Uint8List> signETHMessage(
          int chainId, Uint8List keypath, Uint8List message) =>
      _call((id, a) => _ethSignMessage(id, chainId, a.bytes(keypath),
          keypath.length, a.bytes(message), message.length));

  Future<Uint8List> signETHTypedMessage(
          int chainId, Uint8List keypath, Uint8List jsonMessage) =>
      _call((id, a) => _ethSignTypedMessage(id, chainId, a.bytes(keypath),
          keypath.length, a.bytes(jsonMessage), jsonMessage.length));

  /// Releases the callbacks. Only call once no Go operation is in flight.
  void dispose() {
    _ioCallable.close();
    _resultCallable.close();
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
      _deliverIO(reqId, status, arena.bytes(bytes), bytes.length);
    } finally {
      arena.releaseAll();
    }
  }

  /// Copies a Go-owned buffer into Dart memory and frees it.
  Uint8List _takeBytes(Pointer<Uint8> data, int len) {
    if (data == nullptr) return Uint8List(0);
    final bytes = Uint8List.fromList(data.asTypedList(len));
    _free(data);
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

  Pointer<Utf8> str(String s) => s.toNativeUtf8(allocator: this);
}
