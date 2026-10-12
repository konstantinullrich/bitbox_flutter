import 'package:flutter/services.dart';

import 'bitbox_ffi.dart';

/// [BitboxTransport] backed by `BitboxUsbTransport.kt` on Android.
///
/// Permission must already be granted (see `BitboxUsb.requestPermission`) before [open].
class MethodChannelBitboxTransport implements BitboxTransport {
  static const _channel = MethodChannel('bitbox_usb_transport');

  Future<void> open(String identifier) =>
      _channel.invokeMethod('open', {'identifier': identifier});

  @override
  Future<Uint8List> read(int length) async =>
      (await _channel.invokeMethod<Uint8List>('read', {'length': length}))!;

  @override
  Future<void> write(Uint8List data) =>
      _channel.invokeMethod('write', {'data': data});

  @override
  Future<void> close() => _channel.invokeMethod('close');
}
