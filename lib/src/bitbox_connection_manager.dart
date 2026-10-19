import 'package:bitbox_flutter/ffi/bitbox_connection.dart';
import 'package:bitbox_flutter/ffi/bitbox_ffi.dart';
import 'package:bitbox_flutter/src/bitbox_device.dart';
import 'package:bitbox_flutter/src/transport/bitbox_ble_transport.dart';
import 'package:bitbox_flutter/src/transport/bitbox_usb_transport.dart';
import 'package:bitbox_flutter/src/usb/bitbox_usb_platform_interface.dart';
import 'package:universal_ble/universal_ble.dart';

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

/// Finds and connects to a BitBox02 Nova over Bluetooth LE. [BitboxDevice.identifier] is
/// the [BleDevice.deviceId].
class BitboxBleConnectionManager extends BitboxConnectionManager {
  BitboxBleConnectionManager({this.scanDuration = const Duration(seconds: 5)});

  /// How long [devices] scans for advertising devices.
  final Duration scanDuration;

  final _transport = BitboxBleTransport();
  late final ffi = BitboxFfi(_transport);

  /// Firmware events, including the pairing code during [initBitBox].
  Stream<BitboxEvent> get events => ffi.events;

  /// Already connected or bonded BitBoxes, plus the ones advertising during [scanDuration].
  @override
  Future<List<BitboxDevice>> get devices async {
    await UniversalBle.requestPermissions();

    final found = <String, BleDevice>{};
    for (final device in await UniversalBle.getSystemDevices(
        withServices: [BitboxBleTransport.serviceUuid])) {
      found[device.deviceId] = device;
    }

    final scan = UniversalBle.scanStream.listen((d) => found[d.deviceId] = d);
    try {
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [BitboxBleTransport.serviceUuid]),
      );
      await Future<void>.delayed(scanDuration);
    } finally {
      await scan.cancel();
      await UniversalBle.stopScan();
    }

    return [for (final d in found.values) _toBitboxDevice(d)];
  }

  @override
  Future<BitboxConnection> connect(BitboxDevice device) async {
    await UniversalBle.requestPermissions();
    await _transport.open(device.identifier);

    await ffi.open();

    return BitboxConnection(ffi);
  }

  static BitboxDevice _toBitboxDevice(BleDevice device) => BitboxDevice(
        identifier: device.deviceId,
        vendorId: 0,
        productId: 0,
        productName: device.name ?? 'BitBox02',
        deviceId: 0,
        deviceName: device.name ?? device.deviceId,
        manufacturerName: 'Shift Crypto',
        configurationCount: 0,
      );
}
