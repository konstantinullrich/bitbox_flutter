import 'dart:typed_data';

abstract interface class BitboxTransport {
  Future<Uint8List> read(int length);

  Future<void> write(Uint8List data);

  Future<void> close();
}
