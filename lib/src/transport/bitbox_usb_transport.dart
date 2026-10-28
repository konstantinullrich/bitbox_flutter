import 'dart:async';

import 'package:bitbox_flutter/src/transport/bitbox_transport.dart';
import 'package:bitbox_flutter/src/transport/bitbox_transport_exception.dart';
import 'package:bitbox_flutter/src/usb/bitbox_usb_platform_interface.dart';
import 'package:flutter/services.dart';

class BitboxUsbTransport extends BitboxTransport {
  BitboxUsbTransport({this.pollInterval = const Duration(seconds: 1)});

  static const _channel = MethodChannel('bitbox_usb_transport');

  /// How often the device list is checked to notice that the device was unplugged.
  final Duration pollInterval;

  Timer? _pollTimer;

  Future<void> open(String identifier) async {
    _pollTimer?.cancel();
    setConnectionState(BitboxConnectionStatus.connecting);
    try {
      await _channel.invokeMethod('open', {'identifier': identifier});
    } catch (_) {
      setConnectionState(BitboxConnectionStatus.disconnected);
      rethrow;
    }
    setConnectionState(BitboxConnectionStatus.connected);
    _pollTimer = _isConnectedTimer(identifier);
  }

  Timer _isConnectedTimer(String identifier) {
    var polling = false;
    return Timer.periodic(pollInterval, (timer) async {
      if (polling) return;
      polling = true;
      try {
        final devices = await BitboxUsbPlatform.instance.getDevices();
        if (!timer.isActive) return;
        if (!devices.any((d) => d.identifier == identifier)) {
          timer.cancel();
          setConnectionState(BitboxConnectionStatus.disconnected);
        }
      } catch (_) {
      } finally {
        polling = false;
      }
    });
  }

  @override
  Future<Uint8List> read(int length) async =>
      (await _channel.invokeMethod<Uint8List>('read', {'length': length})) ??
      (throw BitboxTransportException("Something went wrong reading from the USB Interface"));

  @override
  Future<void> write(Uint8List data) => _channel.invokeMethod('write', {'data': data});

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    _pollTimer = null;
    setConnectionState(BitboxConnectionStatus.disconnected);
    return _channel.invokeMethod('close');
  }
}
