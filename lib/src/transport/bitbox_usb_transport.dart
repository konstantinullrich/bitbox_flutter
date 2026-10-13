import 'package:bitbox_flutter/src/transport/bitbox_transport.dart';
import 'package:bitbox_flutter/src/transport/bitbox_transport_exception.dart';
import 'package:flutter/services.dart';

class BitboxUsbTransport implements BitboxTransport {
  static const _channel = MethodChannel('bitbox_usb_transport');

  Future<void> open(String identifier) => _channel.invokeMethod('open', {'identifier': identifier});

  @override
  Future<Uint8List> read(int length) async =>
      (await _channel.invokeMethod<Uint8List>('read', {'length': length})) ??
      (throw BitboxTransportException("Something went wrong reading from the USB Interface"));

  @override
  Future<void> write(Uint8List data) => _channel.invokeMethod('write', {'data': data});

  @override
  Future<void> close() => _channel.invokeMethod('close');
}
