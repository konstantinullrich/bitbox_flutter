import 'dart:async';

import 'package:bitbox_flutter/usb/bitbox_device.dart';
import 'package:bitbox_flutter/usb/bitbox_usb.dart';
import 'package:bitbox_flutter/usb/bitbox_usb_platform_interface.dart';
import 'package:bitbox_flutter/usb/src/bip32_path_helper.dart';
import 'package:bitbox_flutter/usb/src/bip32_path_to_buffer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BitboxManager {
  bool _disposed = false;

  final _bitboxUsb = BitboxUsb();

  Future<void> connect(BitboxDevice usbDevice) async {
    if (_disposed) throw Exception("Is disposed");

    await _bitboxUsb.requestPermission(usbDevice);
    await _bitboxUsb.open(usbDevice);
  }

  Future<void> disconnect() async {
    if (_disposed) throw Exception("Is disposed");

    await _bitboxUsb.close();
  }

  Future<bool> initBitBox() => BitboxUsbPlatform.instance.initBitBox();

  Future<Uint8List> getMasterFingerprint() =>
      BitboxUsbPlatform.instance.getMasterFingerprint();

  Future<String> getChannelHash() =>
      BitboxUsbPlatform.instance.getChannelHash();

  Future<bool> channelHashVerify() =>
      BitboxUsbPlatform.instance.channelHashVerify();

  Future<bool> supportsLTC() => BitboxUsbPlatform.instance.supportsLTC();

  Future<bool> supportsETH(int chainId) =>
      BitboxUsbPlatform.instance.supportsETH(chainId);

  Future<bool> supportsERC20(String contractAddress) =>
      BitboxUsbPlatform.instance.supportsERC20(contractAddress);

  Future<String> getBTCXPub(
    int coinType,
    String keypath, [
    int addressType = 0,
    bool display = false,
  ]) async {
    final bipPath = BIPPath.fromString(keypath);
    return BitboxUsbPlatform.instance.getBTCXPub(
      coinType,
      packDerivationPath(bipPath.toPathArray()),
      addressType,
      display,
    );
  }

  Future<String> signBTCPsbt(int coinType, String psbt) =>
      BitboxUsbPlatform.instance.signBTCPsbt(coinType, psbt);

  Future<Uint8List> signBTCMessage(
      int coinType, String keypath, Uint8List message) {
    final bipPath = BIPPath.fromString(keypath);
    return BitboxUsbPlatform.instance.signBTCMessage(
        coinType, packDerivationPath(bipPath.toPathArray()), message);
  }

  Future<String> getETHAddress(
    int chainId,
    String keypath, [
    int outputType = 0,
    bool display = false,
  ]) async {
    final bipPath = BIPPath.fromString(keypath);
    return BitboxUsbPlatform.instance.getETHAddress(
      chainId,
      packDerivationPath(bipPath.toPathArray()),
      outputType,
      display,
    );
  }

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
  ) {
    final bipPath = BIPPath.fromString(keypath);
    return BitboxUsbPlatform.instance.signETHTransaction(
      chainId,
      packDerivationPath(bipPath.toPathArray()),
      nonce,
      gasPrice.toRadixString(16),
      gasLimit,
      recipient,
      value.toRadixString(16),
      data,
      recipientAddressCase,
    );
  }

  Future<Uint8List> signETHRLPTransaction(
    int chainId,
    String keypath,
    String transactionData,
    bool isEIP1559,
  ) {
    final bipPath = BIPPath.fromString(keypath);
    return BitboxUsbPlatform.instance.signETHRPLTransaction(
      chainId,
      packDerivationPath(bipPath.toPathArray()),
      transactionData,
      isEIP1559,
    );
  }

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
  ) {
    final bipPath = BIPPath.fromString(keypath);
    return BitboxUsbPlatform.instance.signETHTransactionEIP1559(
      chainId,
      packDerivationPath(bipPath.toPathArray()),
      nonce,
      maxPriorityFeePerGas.toRadixString(16),
      maxFeePerGas.toRadixString(16),
      gasLimit,
      recipient,
      value.toRadixString(16),
      data,
      recipientAddressCase,
    );
  }

  Future<Uint8List> signETHMessage(
    int chainId,
    String keypath,
    Uint8List message,
  ) {
    final bipPath = BIPPath.fromString(keypath);
    return BitboxUsbPlatform.instance.signETHMessage(
      chainId,
      packDerivationPath(bipPath.toPathArray()),
      message,
    );
  }

  Future<Uint8List> signETHTypedMessage(
    int chainId,
    String keypath,
    Uint8List jsonMessage,
  ) {
    final bipPath = BIPPath.fromString(keypath);
    return BitboxUsbPlatform.instance.signETHTypedMessage(
      chainId,
      packDerivationPath(bipPath.toPathArray()),
      jsonMessage,
    );
  }

  Future<List<BitboxDevice>> get devices async {
    if (_disposed) throw Exception("Is disposed");

    return _bitboxUsb.listDevices();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _bitboxUsb.close();
  }
}
