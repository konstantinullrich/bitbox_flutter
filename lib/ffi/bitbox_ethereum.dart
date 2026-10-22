import 'dart:typed_data';

import 'package:bitbox_flutter/ffi/bitbox_ffi.dart';
import 'package:bitbox_flutter/ffi/utils/arena_extension.dart';

extension BitboxEthereum on BitboxFfi {
  Future<Uint8List> signETHTransaction(
    int chainId,
    Uint8List keypath,
    int nonce,
    String gasPriceHex,
    int gasLimit,
    Uint8List recipient,
    String valueHex,
    Uint8List data,
    int recipientAddressCase,
  ) =>
      call((id, a) => lib.BBETHSignTransaction(
            id,
            chainId,
            a.bytes(keypath),
            keypath.length,
            nonce,
            a.str(gasPriceHex),
            gasLimit,
            a.bytes(recipient),
            recipient.length,
            a.str(valueHex),
            a.bytes(data),
            data.length,
            recipientAddressCase,
          ));

  Future<Uint8List> signETHTransactionEIP1559(
    int chainId,
    Uint8List keypath,
    int nonce,
    String maxPriorityFeePerGasHex,
    String maxFeePerGasHex,
    int gasLimit,
    Uint8List recipient,
    String valueHex,
    Uint8List data,
    int recipientAddressCase,
  ) =>
      call((id, a) => lib.BBETHSignEIP1559(
            id,
            chainId,
            a.bytes(keypath),
            keypath.length,
            nonce,
            a.str(maxPriorityFeePerGasHex),
            a.str(maxFeePerGasHex),
            gasLimit,
            a.bytes(recipient),
            recipient.length,
            a.str(valueHex),
            a.bytes(data),
            data.length,
            recipientAddressCase,
          ));

  Future<Uint8List> signETHRLPTransaction(
          int chainId, Uint8List keypath, String encodedTxHex, bool isEIP1559) =>
      call((id, a) => lib.BBETHSignRLPTx(
          id, chainId, a.bytes(keypath), keypath.length, a.str(encodedTxHex), isEIP1559));

  Future<Uint8List> signETHMessage(int chainId, Uint8List keypath, Uint8List message) =>
      call((id, a) => lib.BBETHSignMessage(
          id, chainId, a.bytes(keypath), keypath.length, a.bytes(message), message.length));

  Future<Uint8List> signETHTypedMessage(int chainId, Uint8List keypath, Uint8List jsonMessage) =>
      call((id, a) => lib.BBETHSignTypedMessage(
          id, chainId, a.bytes(keypath), keypath.length, a.bytes(jsonMessage), jsonMessage.length));
}
