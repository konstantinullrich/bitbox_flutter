import 'package:bitbox_flutter/src/bitbox_device.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'bitbox_usb_method_channel.dart'
    if (dart.library.html) 'web_ledger_usb.dart'
    if (dart.library.js) 'web_ledger_usb.dart'
    if (dart.library.js_interop) 'web_ledger_usb.dart';

abstract class BitboxUsbPlatform extends PlatformInterface {
  BitboxUsbPlatform() : super(token: _token);

  static final Object _token = Object();

  static BitboxUsbPlatform _instance = createPlatformInstance();

  /// The default instance of [BitboxUsbPlatform] to use.
  ///
  /// Defaults to [MethodChannelBitboxUsb] or [WebLedgerUsb] if running on web.
  static BitboxUsbPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BitboxUsbPlatform] when
  /// they register themselves.
  static set instance(BitboxUsbPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<List<BitboxDevice>> getDevices();

  Future<bool> requestPermission(BitboxDevice usbDevice);
}
