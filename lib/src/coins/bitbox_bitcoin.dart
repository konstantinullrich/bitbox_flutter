import 'dart:convert';
import 'dart:typed_data';

import 'package:bitbox_flutter/ffi/bitbox_ffi.dart';
import 'package:bitbox_flutter/ffi/utils/arena_extension.dart';
import 'package:bitbox_flutter/src/utils/bip32_path_helper.dart';
import 'package:bitbox_flutter/src/utils/bip32_path_to_buffer.dart';

class BitboxBitcoin {
  BitboxBitcoin(this._bitboxFfi, {this.coinType = 0});

  final BitboxFfi _bitboxFfi;
  final int coinType;

  Future<Uint8List> getMasterFingerprint() =>
      _bitboxFfi.call((id, _) => _bitboxFfi.lib.BBGetMasterFingerprint(id));

  Future<String> getXPub(
    String keypath, {
    int addressType = 0,
    bool display = false,
  }) {
    final keypathBuf = packDerivationPath(BIPPath.fromString(keypath).toPathArray());
    return _bitboxFfi
        .call(
          (id, a) => _bitboxFfi.lib.BBBTCXPub(
            id,
            coinType,
            a.bytes(keypathBuf),
            keypathBuf.length,
            addressType,
            display,
          ),
        )
        .then(utf8.decode);
  }

  Future<String> signPsbt(String psbt) {
    final encoded = utf8.encode(psbt);
    return _bitboxFfi
        .call(
          (id, a) => _bitboxFfi.lib.BBBTCSignPSBT(
            id,
            coinType,
            a.bytes(encoded),
            encoded.length,
          ),
        )
        .then(utf8.decode);
  }

  Future<Uint8List> signMessage(String keypath, Uint8List message) {
    final keypathBuf = packDerivationPath(BIPPath.fromString(keypath).toPathArray());
    return _bitboxFfi.call(
      (id, a) => _bitboxFfi.lib.BBBTCSignMessage(
        id,
        coinType,
        a.bytes(keypathBuf),
        keypathBuf.length,
        a.bytes(message),
        message.length,
      ),
    );
  }
}
