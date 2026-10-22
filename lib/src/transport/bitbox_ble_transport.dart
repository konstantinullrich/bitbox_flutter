import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bitbox_flutter/src/transport/bitbox_transport.dart';
import 'package:bitbox_flutter/src/transport/bitbox_transport_exception.dart';
import 'package:universal_ble/universal_ble.dart';

/// Talks to a BitBox02 Nova over Bluetooth LE.
///
/// The device exposes the same u2fhid packets as over USB: every notification on the
/// reader characteristic is one 64-byte packet, and writes must be multiples of 64 bytes.
/// GATT layout as in the BitBoxApp (frontends/ios/BitBoxApp/BitBoxApp/Bluetooth.swift).
class BitboxBleTransport implements BitboxTransport {
  static const serviceUuid = 'e1511a45-f3db-44c0-82b8-6c880790d1f1';
  static const writerUuid = '799d485c-d354-4ed0-b577-f8ee79ec275a';
  static const readerUuid = '419572a5-9f53-4eb1-8db7-61bcab928867';
  static const productUuid = '9d1c9a77-8b03-4e49-8053-3955cda7da93';

  static const _packetSize = 64;

  /// The BLE firmware accepts at most 5 packets per write.
  static const _maxWriteSize = 5 * _packetSize;

  /// ATT header bytes that don't count towards the payload.
  static const _attOverhead = 3;

  /// Leaves the user time to confirm the system pairing dialog.
  static const _pairingTimeout = Duration(minutes: 2);

  String? _deviceId;
  int _writeSize = _packetSize;

  final _buffer = BytesBuilder(copy: false);
  Completer<void>? _dataAvailable;
  BitboxTransportException? _error;

  StreamSubscription<Uint8List>? _notifications;
  StreamSubscription<bool>? _connection;

  /// Connects to [deviceId] (a [BleDevice.deviceId]) and subscribes to device packets.
  ///
  /// Bonds first where the OS has a pairing API (Android, Windows, Linux); elsewhere the
  /// first encrypted access triggers bonding. Either way the system pairing dialog may
  /// appear here.
  Future<void> open(String deviceId) async {
    if (_deviceId != null) await close();
    _error = null;
    _buffer.clear();

    await UniversalBle.connect(deviceId);
    _deviceId = deviceId;
    try {
      _connection = UniversalBle.connectionStream(deviceId).listen((connected) {
        if (!connected) _fail('the device disconnected');
      });

      final services = await UniversalBle.discoverServices(deviceId);
      final reader = services
          .where((s) => _sameUuid(s.uuid, serviceUuid))
          .expand((s) => s.characteristics)
          .where((c) => _sameUuid(c.uuid, readerUuid))
          .firstOrNull;
      if (reader == null) {
        throw BitboxTransportException('$deviceId is not a BitBox');
      }

      // Android defaults to a 23-byte MTU, too small for a single packet. Elsewhere the
      // OS negotiates it and requestMtu just reports the result.
      int mtu;
      try {
        mtu = await UniversalBle.requestMtu(deviceId, 517);
      } catch (_) {
        mtu = _packetSize + _attOverhead;
      }
      _writeSize = min(_maxWriteSize, (mtu - _attOverhead) ~/ _packetSize * _packetSize);
      if (_writeSize < _packetSize) {
        throw BitboxTransportException('MTU $mtu is too small for a $_packetSize-byte packet');
      }

      await _pairDeviceIfNeeded(deviceId);

      _notifications = UniversalBle.characteristicValueStream(deviceId, readerUuid).listen(_onPacket);
      if (reader.properties.contains(CharacteristicProperty.notify)) {
        await UniversalBle.subscribeNotifications(deviceId, serviceUuid, readerUuid);
      } else {
        await UniversalBle.subscribeIndications(deviceId, serviceUuid, readerUuid);
      }
    } catch (_) {
      await close();
      rethrow;
    }
  }

  /// Pair the device if needed.
  Future<void> _pairDeviceIfNeeded(String deviceId) async {
    /// [Android] Pairing seems to work well
    if (!Platform.isAndroid) {
      /// [iOS] Pairing HANGS ENDLESSLY ; seems to work well without requesting explicit pairing
      /// [Web] Not sure what happens ; seems to work well without requesting explicit pairing
      return;
    }

    final isPaired = await UniversalBle.isPaired(
      deviceId,
      pairingCommand: BleCommand(
        service: serviceUuid,
        characteristic: writerUuid,
      ),
    );

    if (isPaired == false) {
      await UniversalBle.pair(
        deviceId,
        pairingCommand: Platform.isAndroid
            ? null
            : BleCommand(
                service: serviceUuid,
                characteristic: writerUuid,
              ),
      );
    }
  }

  /// Reads the product JSON (e.g. `{"p":"bb02p-multi","v":"9.23.0"}`).
  Future<Uint8List> readProduct() =>
      UniversalBle.read(_requireDeviceId(), serviceUuid, productUuid);

  @override
  Future<Uint8List> read(int length) async {
    while (_buffer.length < length) {
      if (_error case final error?) throw error;
      _requireDeviceId();
      await (_dataAvailable ??= Completer<void>()).future;
    }
    final bytes = _buffer.takeBytes();
    if (bytes.length > length) _buffer.add(Uint8List.sublistView(bytes, length));
    return Uint8List.sublistView(bytes, 0, length);
  }

  @override
  Future<void> write(Uint8List data) async {
    final deviceId = _requireDeviceId();
    if (_error case final error?) throw error;
    // u2fhid hands over whole messages padded to 64 bytes; split them to what fits.
    for (var offset = 0; offset < data.length; offset += _writeSize) {
      final chunk = Uint8List.sublistView(data, offset, min(offset + _writeSize, data.length));
      await UniversalBle.write(deviceId, serviceUuid, writerUuid, chunk);
    }
  }

  @override
  Future<void> close() async {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    _deviceId = null;
    _fail('transport closed');

    await _notifications?.cancel();
    await _connection?.cancel();
    _notifications = null;
    _connection = null;
    try {
      await UniversalBle.unsubscribe(deviceId, serviceUuid, readerUuid);
    } catch (_) {
      // Already disconnected.
    }
    await UniversalBle.disconnect(deviceId);
  }

  void _onPacket(Uint8List packet) {
    _buffer.add(packet);
    _wake();
  }

  void _fail(String message) {
    _error ??= BitboxTransportException(message);
    _wake();
  }

  void _wake() {
    final waiter = _dataAvailable;
    _dataAvailable = null;
    waiter?.complete();
  }

  String _requireDeviceId() =>
      _deviceId ?? (throw BitboxTransportException('transport is not open'));

  static bool _sameUuid(String a, String b) => a.toLowerCase() == b.toLowerCase();
}
