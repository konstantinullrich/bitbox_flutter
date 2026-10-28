import 'dart:typed_data';

import 'package:bitbox_flutter/bitbox_flutter.dart';
import 'package:bitbox_flutter/src/utils/bip32_path_helper.dart';
import 'package:bitbox_flutter/src/utils/bip32_path_to_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BIPPath', () {
    test('parses hardened and normal levels', () {
      expect(
        BIPPath.fromString("m/84'/0h/0H/1/2").toPathArray(),
        [84 + BIPPath.hardened, BIPPath.hardened, BIPPath.hardened, 1, 2],
      );
    });

    test('round-trips through toString', () {
      expect(BIPPath.fromString("m/44'/60'/0'/0/0").toString(), "m/44'/60'/0'/0/0");
    });

    test('rejects an index that is already hardened', () {
      expect(() => BIPPath.fromString('m/2147483648'), throwsException);
    });
  });

  test('packDerivationPath writes each level as big-endian uint32', () {
    expect(
      packDerivationPath([84 + BIPPath.hardened, 1]),
      Uint8List.fromList([0x80, 0, 0, 84, 0, 0, 0, 1]),
    );
  });

  test('BitboxDevice survives a toMap/fromMap round trip', () {
    const device = BitboxDevice(
      identifier: '/dev/bus/usb/001/002',
      vendorId: 0x03eb,
      productId: 0x2403,
      productName: 'BitBox02',
      deviceId: 1002,
      deviceName: '/dev/bus/usb/001/002',
      manufacturerName: 'Shift Crypto AG',
      configurationCount: 1,
      isUsb: true,
    );

    expect(BitboxDevice.fromMap(device.toMap()).toMap(), device.toMap());
  });
}
