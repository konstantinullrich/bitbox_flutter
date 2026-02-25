import 'dart:convert';

import 'package:bitbox_flutter/usb/bitbox_device.dart';
import 'package:bitbox_flutter/usb/bitbox_usb_platform_interface.dart';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

BitboxUsbPlatform createIosPlatformInstance() => MethodChannelBitboxIos();

/// An implementation of [BitboxUsbPlatform] that uses method channels.
class MethodChannelBitboxIos extends BitboxUsbPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('bitbox_usb');

  @override
  Future<bool> startScan() async {
    final result = await methodChannel.invokeMethod<bool>('iosStartScan');

    return result!;
  }

  @override
  Future<bool> isBluetoothConnected() async {
    final result = await methodChannel.invokeMethod<bool>('iosGetConnectionStatus');

    return result!;
  }

  @override
  Future<bool> completeConnect() async {
    print('[bitbox_flutter] completeConnect');

    final result = await methodChannel.invokeMethod<bool>('iosFinalConnectDeviceOperation');
    print('[bitbox_flutter] completeConnect $result');

    return result ?? false;
  }

  @override
  Future<List<BitboxDevice>> getDevices() async {
    final devicesJson = await methodChannel.invokeMethod<String>('getDevices');

    final devices = (jsonDecode(devicesJson!) as Map<String, dynamic>)['peripherals'] as List;
    return devices
        .map((device) => BitboxDevice.fromIdentifier(device["identifier"], name: device["name"]))
        .toList();
  }

  @override
  Future<bool> open(BitboxDevice usbDevice) async {
    print('[bitbox_flutter] open ${usbDevice.productName} ${usbDevice.toMap()}');
    final open = await methodChannel.invokeMethod<bool>(
      'open',
      usbDevice.identifier,
    );
    print('[bitbox_flutter] open $open');

    return open ?? false;
  }

  @override
  Future<bool> close() async {
    final closed = await methodChannel.invokeMethod<bool>('close');

    return closed ?? false;
  }

  @override
  Future<bool> initBitBox() async {
    print('[bitbox_flutter] initBitBox');
    final result = await methodChannel.invokeMethod<bool>('initBitBox');
    print('[bitbox_flutter] initBitBox $result');

    return result ?? false;
  }

  @override
  Future<bool> channelHashVerify() async {
    final result = await methodChannel.invokeMethod<bool>('channelHashVerify');

    return result ?? false;
  }

  @override
  Future<String> getChannelHash() async {
    final result = await methodChannel.invokeMethod<String>('getChannelHash');

    return result ?? '';
  }

  @override
  Future<Uint8List> getMasterFingerprint() async {
    final result = await methodChannel.invokeMethod<Uint8List>('getMasterFingerprint');

    return result ?? Uint8List(0);
  }

  @override
  Future<bool> supportsETH(int chainId) async {
    final result = await methodChannel.invokeMethod<bool>('supportsETH', {
      'chainId': chainId,
    });

    return result ?? false;
  }

  @override
  Future<bool> supportsERC20(String contractAddress) async {
    final result = await methodChannel.invokeMethod<bool>('supportsERC20', {
      'contractAddress': contractAddress,
    });

    return result ?? false;
  }

  @override
  Future<bool> supportsLTC() async {
    final result = await methodChannel.invokeMethod<bool>('supportsLTC');

    return result ?? false;
  }

  @override
  Future<String> getBTCXPub(
    int coinType,
    Uint8List keypath,
    int addressType,
    bool display,
  ) async {
    final result = await methodChannel.invokeMethod<String>('getBTCXPub', {
      'coinType': coinType,
      'keypath': hex.encode(keypath),
      'addressType': addressType,
      'display': display,
    });

    return result ?? '';
  }

  @override
  Future<String> signBTCPsbt(int coinType, String psbt) async {
    final result = await methodChannel
        .invokeMethod<String>('signBTCPsbt', {'coinType': coinType, 'psbt': psbt});

    return result ?? "";
  }

  @override
  Future<Uint8List> signBTCMessage(
    int chainId,
    Uint8List keypath,
    Uint8List message,
  ) async {
    final result = await methodChannel.invokeMethod<Uint8List>(
      'signBTCMessage',
      {'coinType': chainId, 'keypath': hex.encode(keypath), 'message': message},
    );

    return result ?? Uint8List(0);
  }

  @override
  Future<String> getETHAddress(
    int chainId,
    Uint8List keypath,
    int outputType,
    bool display,
  ) async {
    final result = await methodChannel.invokeMethod<String>('getETHAddress', {
      'chainId': chainId,
      'keypath': hex.encode(keypath),
      'outputType': outputType,
      'display': display,
    });

    return result ?? '';
  }

  @override
  Future<Uint8List> signETHRPLTransaction(
      int chainId, Uint8List keypath, String transactionData, bool isEIP1559) async {
    final result = await methodChannel.invokeMethod<Uint8List>('signETHRLPTransaction', {
      'chainId': chainId,
      'keypath': hex.encode(keypath),
      'txData': transactionData,
      'isEIP1559': isEIP1559,
    });

    return result ?? Uint8List(0);
  }

  @override
  Future<Uint8List> signETHTransaction(
    int chainId,
    Uint8List keypath,
    int nonce,
    String gasPrice,
    int gasLimit,
    Uint8List recipient,
    String value,
    Uint8List data,
    int recipientAddressCase,
  ) async {
    final result = await methodChannel.invokeMethod<Uint8List>('signETHTransaction', {
      'chainId': chainId,
      'keypath': hex.encode(keypath),
      'nonce': nonce,
      'gasPrice': gasPrice,
      'gasLimit': gasLimit,
      'recipient': recipient,
      'value': value,
      'data': data,
      'recipientAddressCase': recipientAddressCase,
    });

    return result ?? Uint8List(0);
  }

  @override
  Future<Uint8List> signETHTransactionEIP1559(
    int chainId,
    Uint8List keypath,
    int nonce,
    String maxPriorityFeePerGas,
    String maxFeePerGas,
    int gasLimit,
    Uint8List recipient,
    String value,
    Uint8List data,
    int recipientAddressCase,
  ) async {
    final result = await methodChannel.invokeMethod<Uint8List>('signETHTransactionEIP1559', {
      'chainId': chainId,
      'keypath': hex.encode(keypath),
      'nonce': nonce,
      'maxPriorityFeePerGas': maxPriorityFeePerGas,
      'maxFeePerGas': maxFeePerGas,
      'gasLimit': gasLimit,
      'recipient': recipient,
      'value': value,
      'data': data,
      'recipientAddressCase': recipientAddressCase,
    });

    return result ?? Uint8List(0);
  }

  @override
  Future<Uint8List> signETHMessage(
    int chainId,
    Uint8List keypath,
    Uint8List message,
  ) async {
    final result = await methodChannel.invokeMethod<Uint8List>(
      'signETHMessage',
      {'chainId': chainId, 'keypath': hex.encode(keypath), 'message': message},
    );

    return result ?? Uint8List(0);
  }

  @override
  Future<Uint8List> signETHTypedMessage(
    int chainId,
    Uint8List keypath,
    Uint8List jsonMessage,
  ) async {
    final result = await methodChannel.invokeMethod<Uint8List>(
      'signETHTypedMessage',
      {
        'chainId': chainId,
        'keypath': hex.encode(keypath),
        'jsonMessage': jsonMessage,
      },
    );

    return result ?? Uint8List(0);
  }

  @override
  Future<bool> requestPermission(BitboxDevice usbDevice) async => true;
}
