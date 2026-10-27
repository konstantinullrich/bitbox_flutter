import 'dart:async';

import 'package:bitbox_flutter/src/transport/bitbox_transport.dart';

import 'bitbox_ffi.dart';

/// Talks to the Go library over dart:ffi. Device listing and USB permission use the
/// `bitbox_usb` method channel; device I/O goes through [MethodChannelBitboxTransport].
class BitboxConnection {
  BitboxConnection(this.ffi, this._transport);

  final BitboxFfi ffi;
  final BitboxTransport _transport;
  bool _disposed = false;

  BitboxConnectionStatus get status => _transport.connectionState;

  /// Emits every change of [status].
  Stream<BitboxConnectionStatus> get statusChanges => _transport.connectionStateChanges;

  Future<void> disconnect() {
    _checkDisposed();
    return ffi.close();
  }

  /// Pairs with the device. Listen to [events] first to show the pairing code; this
  /// completes once the user accepted it on the device.
  Future<void> initBitBox() async {
    final status = await ffi.initDevice();
    if (status == 'pairingFailed') {
      throw BitboxFfiException('Pairing was rejected on the device');
    }
    if (status == 'require_app_upgrade') {
      throw BitboxFfiException('Device firmware requires a newer app version');
    }
  }

  Future<String> getChannelHash() => ffi.getChannelHash();

  Future<void> channelHashVerify([bool ok = true]) => ffi.channelHashVerify(ok);

  Future<bool> supportsLTC() => ffi.supportsLTC();

  Future<bool> supportsETH(int chainId) => ffi.supportsETH(chainId);

  Future<bool> supportsERC20(String contractAddress) =>
      ffi.supportsERC20(contractAddress);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await ffi.close();
    } finally {
      ffi.dispose();
    }
  }

  void _checkDisposed() {
    if (_disposed) throw StateError('BitboxFfiManager is disposed');
  }
}
