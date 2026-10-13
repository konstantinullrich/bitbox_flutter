import 'package:bitbox_flutter/src/bitbox_device.dart';
import 'package:bitbox_flutter/usb/bitbox_usb_platform_interface.dart';

class BitboxUsb {
  Future<List<BitboxDevice>> listDevices() =>
      BitboxUsbPlatform.instance.getDevices();

  Future<bool> requestPermission(BitboxDevice usbDevice) =>
      BitboxUsbPlatform.instance.requestPermission(usbDevice);
}
