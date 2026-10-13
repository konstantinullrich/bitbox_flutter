import 'package:bitbox_flutter/src/bitbox_device.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bitbox_usb_platform_interface.dart';

BitboxUsbPlatform createPlatformInstance() => MethodChannelBitboxUsb();

/// An implementation of [BitboxUsbPlatform] that uses method channels.
class MethodChannelBitboxUsb extends BitboxUsbPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('bitbox_usb');

  @override
  Future<List<BitboxDevice>> getDevices() async {
    final devices =
        (await methodChannel.invokeMethod<List<dynamic>>('getDevices')) ?? [];

    return devices.map((device) => BitboxDevice.fromMap(device)).toList();
  }

  @override
  Future<bool> requestPermission(BitboxDevice usbDevice) async {
    final granted = await methodChannel.invokeMethod<bool>(
      'requestPermission',
      usbDevice.toMap(),
    );

    return granted ?? false;
  }
}
