import 'dart:typed_data';

Uint8List packDerivationPath(List<int> path) {
  final data = ByteData(path.length * 4);
  for (var i = 0; i < path.length; i++) {
    data.setUint32(i * 4, path[i]);
  }
  return data.buffer.asUint8List();
}
