import 'dart:ffi';

import 'package:ffi/ffi.dart';

extension BytesAndStrings on Arena {
  Pointer<Uint8> bytes(List<int> data) {
    if (data.isEmpty) return nullptr;
    final ptr = allocate<Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    return ptr;
  }

  Pointer<Char> str(String s) => s.toNativeUtf8(allocator: this).cast();
}
