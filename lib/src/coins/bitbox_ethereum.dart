import 'dart:convert';
import 'dart:typed_data';

import 'package:bitbox_flutter/ffi/bitbox_ffi.dart';
import 'package:bitbox_flutter/ffi/utils/arena_extension.dart';
import 'package:bitbox_flutter/src/utils/bip32_path_helper.dart';
import 'package:bitbox_flutter/src/utils/bip32_path_to_buffer.dart';

class BitboxEthereum {
  BitboxEthereum(this._bitboxFfi, {this.chainId = 1});

  final BitboxFfi _bitboxFfi;
  final int chainId;

  Future<String> getAddress(
    String keypath, {
    int outputType = 0,
    bool display = false,
  }) {
    final keypathBuf = packDerivationPath(BIPPath.fromString(keypath).toPathArray());
    return _bitboxFfi
        .call(
          (id, a) => _bitboxFfi.lib.BBETHGetAddress(
            id,
            chainId,
            a.bytes(keypathBuf),
            keypathBuf.length,
            outputType,
            display,
          ),
        )
        .then(utf8.decode);
  }

  Future<Uint8List> signTransaction(
    String keypath,
    int nonce,
    BigInt gasPrice,
    int gasLimit,
    Uint8List recipient,
    BigInt value,
    Uint8List data,
    int recipientAddressCase,
  ) {
    final keypathBuf = packDerivationPath(BIPPath.fromString(keypath).toPathArray());
    return _bitboxFfi.call((id, a) => _bitboxFfi.lib.BBETHSignTransaction(
          id,
          chainId,
          a.bytes(keypathBuf),
          keypathBuf.length,
          nonce,
          a.str(gasPrice.toRadixString(16)),
          gasLimit,
          a.bytes(recipient),
          recipient.length,
          a.str(value.toRadixString(16)),
          a.bytes(data),
          data.length,
          recipientAddressCase,
        ));
  }

  Future<Uint8List> signTransactionEIP1559(
    String keypath,
    int nonce,
    BigInt maxPriorityFeePerGas,
    BigInt maxFeePerGas,
    int gasLimit,
    Uint8List recipient,
    BigInt value,
    Uint8List data,
    int recipientAddressCase,
  ) {
    final keypathBuf = packDerivationPath(BIPPath.fromString(keypath).toPathArray());
    return _bitboxFfi.call(
      (id, a) => _bitboxFfi.lib.BBETHSignEIP1559(
        id,
        chainId,
        a.bytes(keypathBuf),
        keypathBuf.length,
        nonce,
        a.str(maxPriorityFeePerGas.toRadixString(16)),
        a.str(maxFeePerGas.toRadixString(16)),
        gasLimit,
        a.bytes(recipient),
        recipient.length,
        a.str(value.toRadixString(16)),
        a.bytes(data),
        data.length,
        recipientAddressCase,
      ),
    );
  }

  Future<Uint8List> signRLPTransaction(String keypath, String encodedTxHex, bool isEIP1559) {
    final keypathBuf = packDerivationPath(BIPPath.fromString(keypath).toPathArray());
    return _bitboxFfi.call(
      (id, a) => _bitboxFfi.lib.BBETHSignRLPTx(
        id,
        chainId,
        a.bytes(keypathBuf),
        keypathBuf.length,
        a.str(encodedTxHex),
        isEIP1559,
      ),
    );
  }

  Future<Uint8List> signMessage(String keypath, Uint8List message) {
    final keypathBuf = packDerivationPath(BIPPath.fromString(keypath).toPathArray());
    return _bitboxFfi.call(
      (id, a) => _bitboxFfi.lib.BBETHSignMessage(
        id,
        chainId,
        a.bytes(keypathBuf),
        keypathBuf.length,
        a.bytes(message),
        message.length,
      ),
    );
  }

  Future<Uint8List> signTypedMessage(String keypath, Uint8List jsonMessage) {
    final keypathBuf = packDerivationPath(BIPPath.fromString(keypath).toPathArray());
    return _bitboxFfi.call(
      (id, a) => _bitboxFfi.lib.BBETHSignTypedMessage(
        id,
        chainId,
        a.bytes(keypathBuf),
        keypathBuf.length,
        a.bytes(jsonMessage),
        jsonMessage.length,
      ),
    );
  }
}
