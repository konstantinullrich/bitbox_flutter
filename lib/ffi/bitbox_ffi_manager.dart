import 'dart:typed_data';

import 'package:bitbox_flutter/ffi/bitbox_ffi.dart';
import 'package:bitbox_flutter/ffi/method_channel_transport.dart';
import 'package:bitbox_flutter/src/bitbox_device.dart';
import 'package:bitbox_flutter/usb/bitbox_usb.dart';
import 'package:bitbox_flutter/src/utils/bip32_path_helper.dart';
import 'package:bitbox_flutter/src/utils/bip32_path_to_buffer.dart';

export 'package:bitbox_flutter/ffi/bitbox_ffi.dart'
    show BitboxEvent, BitboxFfiException;

/// Talks to the Go library over dart:ffi. Device listing and USB permission use the
/// `bitbox_usb` method channel; device I/O goes through [MethodChannelBitboxTransport].
class BitboxFfiManager {
  bool _disposed = false;

  final _bitboxUsb = BitboxUsb();
  final _transport = MethodChannelBitboxTransport();
  late final _ffi = BitboxFfi(_transport);

  Future<List<BitboxDevice>> get devices {
    _checkDisposed();
    return _bitboxUsb.listDevices();
  }

  Future<void> connect(BitboxDevice usbDevice) async {
    _checkDisposed();
    if (!await _bitboxUsb.requestPermission(usbDevice)) {
      throw BitboxFfiException('USB permission denied');
    }
    await _transport.open(usbDevice.identifier);
    await _ffi.open();
  }

  Future<void> disconnect() {
    _checkDisposed();
    return _ffi.close();
  }

  /// Firmware events, including the pairing code during [initBitBox].
  Stream<BitboxEvent> get events => _ffi.events;

  /// Pairs with the device. Listen to [events] first to show the pairing code; this
  /// completes once the user accepted it on the device.
  Future<void> initBitBox() async {
    final status = await _ffi.initDevice();
    if (status == 'pairingFailed') {
      throw BitboxFfiException('Pairing was rejected on the device');
    }
    if (status == 'require_app_upgrade') {
      throw BitboxFfiException('Device firmware requires a newer app version');
    }
  }

  Future<String> getChannelHash() => _ffi.getChannelHash();

  Future<void> channelHashVerify([bool ok = true]) =>
      _ffi.channelHashVerify(ok);

  Future<Uint8List> getMasterFingerprint() => _ffi.getMasterFingerprint();

  Future<bool> supportsLTC() => _ffi.supportsLTC();

  Future<bool> supportsETH(int chainId) => _ffi.supportsETH(chainId);

  Future<bool> supportsERC20(String contractAddress) =>
      _ffi.supportsERC20(contractAddress);

  Future<String> getBTCXPub(
    int coinType,
    String keypath, [
    int addressType = 0,
    bool display = false,
  ]) =>
      _ffi.getBTCXPub(coinType, _pack(keypath), addressType, display);

  Future<String> signBTCPsbt(int coinType, String psbt) =>
      _ffi.signBTCPsbt(coinType, psbt);

  Future<Uint8List> signBTCMessage(
          int coinType, String keypath, Uint8List message) =>
      _ffi.signBTCMessage(coinType, _pack(keypath), message);

  Future<String> getETHAddress(
    int chainId,
    String keypath, [
    int outputType = 0,
    bool display = false,
  ]) =>
      _ffi.getETHAddress(chainId, _pack(keypath), outputType, display);

  Future<Uint8List> signETHTransaction(
    int chainId,
    String keypath,
    int nonce,
    BigInt gasPrice,
    int gasLimit,
    Uint8List recipient,
    BigInt value,
    Uint8List data,
    int recipientAddressCase,
  ) =>
      _ffi.signETHTransaction(
        chainId,
        _pack(keypath),
        nonce,
        gasPrice.toRadixString(16),
        gasLimit,
        recipient,
        value.toRadixString(16),
        data,
        recipientAddressCase,
      );

  Future<Uint8List> signETHRLPTransaction(
    int chainId,
    String keypath,
    String transactionData,
    bool isEIP1559,
  ) =>
      _ffi.signETHRLPTransaction(
          chainId, _pack(keypath), transactionData, isEIP1559);

  Future<Uint8List> signETHTransactionEIP1559(
    int chainId,
    String keypath,
    int nonce,
    BigInt maxPriorityFeePerGas,
    BigInt maxFeePerGas,
    int gasLimit,
    Uint8List recipient,
    BigInt value,
    Uint8List data,
    int recipientAddressCase,
  ) =>
      _ffi.signETHTransactionEIP1559(
        chainId,
        _pack(keypath),
        nonce,
        maxPriorityFeePerGas.toRadixString(16),
        maxFeePerGas.toRadixString(16),
        gasLimit,
        recipient,
        value.toRadixString(16),
        data,
        recipientAddressCase,
      );

  Future<Uint8List> signETHMessage(
          int chainId, String keypath, Uint8List message) =>
      _ffi.signETHMessage(chainId, _pack(keypath), message);

  Future<Uint8List> signETHTypedMessage(
          int chainId, String keypath, Uint8List jsonMessage) =>
      _ffi.signETHTypedMessage(chainId, _pack(keypath), jsonMessage);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _ffi.close();
    } finally {
      _ffi.dispose();
    }
  }

  void _checkDisposed() {
    if (_disposed) throw StateError('BitboxFfiManager is disposed');
  }

  static Uint8List _pack(String keypath) =>
      packDerivationPath(BIPPath.fromString(keypath).toPathArray());
}
