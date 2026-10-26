import 'dart:async';

import 'package:bitbox_flutter/ffi/bitbox_connection.dart';
import 'package:bitbox_flutter/ffi/bitbox_ffi.dart';
import 'package:bitbox_flutter/src/bitbox_device.dart';
import 'package:bitbox_flutter/src/transport/bitbox_ble_transport.dart';
import 'package:bitbox_flutter/src/transport/bitbox_usb_transport.dart';
import 'package:bitbox_flutter/src/usb/bitbox_usb_platform_interface.dart';
import 'package:universal_ble/universal_ble.dart';

abstract class BitboxConnectionManager {
  List<BitboxDevice> get devices;

  Stream<BitboxEvent> get events;

  Future<BitboxConnection> connect(BitboxDevice usbDevice);

  Future<void> stopScan();

  bool _isScanning = false;
  StreamController<BitboxDevice> _scanController = StreamController.broadcast();

  void _startScan();

  Stream<BitboxDevice> scan() {
    StreamSubscription<BitboxDevice>? subscription;
    late final StreamController<BitboxDevice> controller;
    controller = StreamController(
      onListen: () {
        if (!_isScanning) _startScan();
        subscription = _scanController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        devices.forEach(controller.add);
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}

class BitboxUsbConnectionManager extends BitboxConnectionManager {
  BitboxUsbConnectionManager({this.maxScanFrequency = const Duration(seconds: 1)});

  final Duration maxScanFrequency;

  final _transport = BitboxUsbTransport();
  late final ffi = BitboxFfi(_transport);

  @override
  Stream<BitboxEvent> get events => ffi.events;

  @override
  List<BitboxDevice> get devices => _devices;

  Future<List<BitboxDevice>> get currentDevices => BitboxUsbPlatform.instance.getDevices();

  List<BitboxDevice> _devices = [];
  Timer? _scanTimer;

  @override
  void _startScan() {
    _scanController = StreamController.broadcast();
    _devices = [];
    _isScanning = true;

    bool polling = false;
    Future<void> poll() async {
      if (polling) return;
      polling = true;
      try {
        final devices = await BitboxUsbPlatform.instance.getDevices();
        if (_scanController.isClosed) return;

        _devices = devices;

        final known = _devices.map((d) => d.identifier).toSet();
        for (final device in devices) {
          if (!known.contains(device.identifier)) _scanController.add(device);
        }

      } catch (e, s) {
        if (!_scanController.isClosed) _scanController.addError(e, s);
      } finally {
        polling = false;
      }
    }

    unawaited(poll());
    _scanTimer = Timer.periodic(maxScanFrequency, (_) => poll());
  }

  @override
  Future<void> stopScan() async {
    if (!_isScanning) return;

    _isScanning = false;
    _scanTimer?.cancel();
    unawaited(_scanController.close());
  }

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
  BitboxBleConnectionManager({this.maxScanDuration = const Duration(minutes: 5)});

  final Duration maxScanDuration;

  final _transport = BitboxBleTransport();
  late final ffi = BitboxFfi(_transport);

  @override
  Stream<BitboxEvent> get events => ffi.events;

  StreamSubscription<BleDevice>? _scanStreamSubscription;
  Timer? _scanTimeout;
  Map<String, BitboxDevice> _foundDevices = {};

  @override
  void _startScan() {
    _scanController = StreamController.broadcast();
    _foundDevices = {};
    _isScanning = true;
    unawaited(_performBleScan());
  }

  Future<void> _performBleScan() async {
    void onFound(BleDevice device) {
      if (_scanController.isClosed || _foundDevices.containsKey(device.deviceId)) return;

      final bbDevice = _toBitboxDevice(device);
      _foundDevices[device.deviceId] = bbDevice;
      _scanController.add(bbDevice);
    }

    try {
      await UniversalBle.requestPermissions();

      (await UniversalBle.getSystemDevices(
        withServices: [BitboxBleTransport.serviceUuid],
      )).forEach(onFound);

      if (_scanController.isClosed) return;

      _scanStreamSubscription = UniversalBle.scanStream.listen(onFound);
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [BitboxBleTransport.serviceUuid]),
      );

      if (!_scanController.isClosed) {
        _scanTimeout = Timer(maxScanDuration, () => unawaited(stopScan()));
      }
    } catch (e, s) {
      if (_scanController.isClosed) return;
      _scanController.addError(e, s);
      await stopScan();
    }
  }

  @override
  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      await UniversalBle.stopScan();
    } finally {
      _isScanning = false;
      _scanTimeout?.cancel();
      unawaited(_scanStreamSubscription?.cancel());
      unawaited(_scanController.close());
    }
  }

  @override
  List<BitboxDevice> get devices => _foundDevices.values.toList();

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
    isUsb: false,
  );
}
