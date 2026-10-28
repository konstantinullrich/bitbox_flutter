import 'dart:async';

import 'package:flutter/foundation.dart';

enum BitboxConnectionStatus { disconnected, connecting, connected }

abstract class BitboxTransport {
  BitboxConnectionStatus get connectionState => _connectionState;

  Stream<BitboxConnectionStatus> get connectionStateChanges => _connectionStateChanges.stream;

  Future<Uint8List> read(int length);

  Future<void> write(Uint8List data);

  Future<void> close();

  final _connectionStateChanges = StreamController<BitboxConnectionStatus>.broadcast();

  BitboxConnectionStatus _connectionState = BitboxConnectionStatus.disconnected;

  @protected
  void setConnectionState(BitboxConnectionStatus state) {
    if (state == _connectionState) return;
    _connectionState = state;
    _connectionStateChanges.add(state);
  }
}
