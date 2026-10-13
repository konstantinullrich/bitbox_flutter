import 'package:bitbox_flutter/ffi/bitbox_connection.dart';
import 'package:bitbox_flutter/ffi/bitbox_ffi.dart';
import 'package:bitbox_flutter/src/bitbox_device.dart';
import 'package:bitbox_flutter/src/transport/bitbox_usb_transport.dart';
import 'package:bitbox_flutter/src/usb/bitbox_usb_platform_interface.dart';

abstract class BitboxConnectionManager {
  Future<List<BitboxDevice>> get devices;

  Future<BitboxConnection> connect(BitboxDevice usbDevice);
}

class BitboxUsbConnectionManager extends BitboxConnectionManager {
  final _transport = BitboxUsbTransport();
  late final ffi = BitboxFfi(_transport);

  /// Firmware events, including the pairing code during [initBitBox].
  Stream<BitboxEvent> get events => ffi.events;

  @override
  Future<List<BitboxDevice>> get devices => BitboxUsbPlatform.instance.getDevices();

  @override
  Future<BitboxConnection> connect(BitboxDevice usbDevice) async {
    if (!await BitboxUsbPlatform.instance.requestPermission(usbDevice)) {
      throw BitboxFfiException('USB permission denied');
    }
    await _transport.open(usbDevice.identifier);

    await ffi.open();

    return BitboxConnection(ffi);
  }
}
