package api

import (
	"encoding/hex"
	"math/big"

	"github.com/BitBoxSwiss/bitbox02-api-go/api/firmware"
	"github.com/BitBoxSwiss/bitbox02-api-go/api/firmware/messages"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/rlp"
)

func ETHGetAddress(chainId int, keypath string, outputType int, display bool, contractAddress []byte) string {
	keypathData, err := hexToUint32Slice(keypath)
	if err != nil {
		panic(err)
	}

	pub, err := bitbox.ETHPub(uint64(chainId), keypathData, messages.ETHPubRequest_OutputType(outputType), display, contractAddress)
	if err != nil {
		panic(err)
	}
	return pub
}

type dynamicFeeTxPayload struct {
	ChainID    uint64
	Nonce      uint64
	GasTipCap  *big.Int // a.k.a. maxPriorityFeePerGas
	GasFeeCap  *big.Int // a.k.a. maxFeePerGas
	Gas        uint64
	To         *common.Address `rlp:"nil"`
	Value      *big.Int
	Data       []byte
	AccessList any

	// Signature values
	V *big.Int `rlp:"optional"`
	R *big.Int `rlp:"optional"`
	S *big.Int `rlp:"optional"`
}

type legacyTxPayload struct {
	Nonce    uint64
	GasPrice *big.Int
	Gas      uint64
	To       *common.Address `rlp:"nil"`
	Value    *big.Int
	Data     []byte
	V, R, S  *big.Int `rlp:"optional"`
}

func ETHSignRPLTx(chainId int, keypath string, encodedTx string, isEIP1559 bool) []byte {
	keypathData, err := hexToUint32Slice(keypath)
	if err != nil {
		panic(err)
	}

	txEncoded, _ := hex.DecodeString(encodedTx)

	var signature []byte
	if isEIP1559 {
		var tx dynamicFeeTxPayload
		err = rlp.DecodeBytes(txEncoded, &tx)
		if err != nil {
			panic(err)
		}

		signature, err = bitbox.ETHSignEIP1559(
			uint64(chainId),
			keypathData,
			tx.Nonce,
			tx.GasTipCap,
			tx.GasFeeCap,
			tx.Gas,
			[20]byte(tx.To.Bytes()),
			tx.Value,
			tx.Data,
			firmware.ETHIdentifyCase(tx.To.String()),
		)
	} else {
		var tx legacyTxPayload
		err = rlp.DecodeBytes(txEncoded, &tx)
		if err != nil {
			panic(err)
		}
		signature, err = bitbox.ETHSign(
			uint64(chainId),
			keypathData,
			tx.Nonce,
			tx.GasPrice,
			tx.Gas,
			[20]byte(tx.To.Bytes()),
			tx.Value,
			tx.Data,
			firmware.ETHIdentifyCase(tx.To.String()),
		)
	}

	if err != nil {
		panic(err)
	}

	return signature
}

func ETHSignTransaction(chainId int, keypath string, nonce int, gasPrice string, gasLimit int, recipient []byte, value string, data []byte, recipientAddressCase int) []byte {
	keypathData, err := hexToUint32Slice(keypath)
	if err != nil {
		panic(err)
	}

	gasPriceBI := new(big.Int)
	gasPriceBI, _ = gasPriceBI.SetString(gasPrice, 16)

	valueBI := new(big.Int)
	valueBI, _ = valueBI.SetString(value, 16)

	signature, err := bitbox.ETHSign(uint64(chainId), keypathData, uint64(nonce), gasPriceBI, uint64(gasLimit), [20]byte(recipient), valueBI, data, messages.ETHAddressCase(recipientAddressCase))
	if err != nil {
		panic(err)
	}
	return signature
}

func ETHSignEIP1559(chainId int, keypath string, nonce int, maxPriorityFeePerGas string, maxFeePerGas string, gasLimit int, recipient []byte, value string, data []byte, recipientAddressCase int) []byte {
	keypathData, err := hexToUint32Slice(keypath)
	if err != nil {
		panic(err)
	}

	maxPriorityFeePerGasBI := new(big.Int)
	maxPriorityFeePerGasBI, _ = maxPriorityFeePerGasBI.SetString(maxPriorityFeePerGas, 16)

	maxFeePerGasBI := new(big.Int)
	maxFeePerGasBI, _ = maxFeePerGasBI.SetString(maxFeePerGas, 16)

	valueBI := new(big.Int)
	valueBI, _ = valueBI.SetString(value, 16)

	signature, err := bitbox.ETHSignEIP1559(uint64(chainId), keypathData, uint64(nonce), maxPriorityFeePerGasBI, maxFeePerGasBI, uint64(gasLimit), [20]byte(recipient), valueBI, data, messages.ETHAddressCase(recipientAddressCase))
	if err != nil {
		panic(err)
	}

	return signature
}

func ETHSignMessage(chainId int, keypath string, msg []byte) []byte {
	keypathData, err := hexToUint32Slice(keypath)
	if err != nil {
		panic(err)
	}

	signature, err := bitbox.ETHSignMessage(uint64(chainId), keypathData, msg)
	if err != nil {
		panic(err)
	}
	return signature
}

func ETHSignTypedMessage(chainId int, keypath string, jsonMsg []byte) []byte {
	keypathData, err := hexToUint32Slice(keypath)
	if err != nil {
		panic(err)
	}

	signature, err := bitbox.ETHSignTypedMessage(uint64(chainId), keypathData, jsonMsg)
	if err != nil {
		panic(err)
	}

	return signature
}
