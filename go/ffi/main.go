// Command ffi builds the BitBox bridge as a C shared library for dart:ffi:
//
//	go build -buildmode=c-shared -o libbitbox.so ./ffi
//
// Threading model: every export returns immediately. Anything that talks to the device runs
// in a goroutine and reports back through the registered result callback. This is required,
// not just nice to have: device I/O is performed by Dart, so a synchronous export that does
// I/O would block the Dart isolate while waiting for that same isolate to answer -> deadlock.
package main

/*
#include "bridge.h"
*/
import "C"

import (
	"encoding/hex"
	"errors"
	"fmt"
	"sync"
	"unsafe"

	"github.com/konstantinullrich/bitbox_flutter/api"
)

func main() {}

var errClosed = errors.New("transport closed")

var (
	ioMu      sync.Mutex
	ioFn      C.bb_io_request_fn
	resultFn  C.bb_result_fn
	ioNextID  int64
	ioPending = map[int64]chan ioResult{}

	// opMu serializes device operations; the firmware API is not safe for concurrent queries.
	opMu sync.Mutex
)

type ioResult struct {
	data []byte
	err  error
}

// ioRequest hands a transfer to Dart and parks the goroutine until BBDeliverIO answers.
func ioRequest(op C.int32_t, payload []byte, readLen int) ([]byte, error) {
	ch := make(chan ioResult, 1)

	ioMu.Lock()
	if ioFn == nil {
		ioMu.Unlock()
		return nil, errors.New("bridge not registered")
	}
	ioNextID++
	id := ioNextID
	ioPending[id] = ch
	fn := ioFn
	ioMu.Unlock()

	data, length := cBytes(payload)
	if op == C.BB_IO_READ {
		length = readLen
	}
	callIO(fn, id, op, data, length)

	r := <-ch
	return r.data, r.err
}

// failPendingIO unblocks every goroutine waiting on Dart, e.g. when the device is unplugged.
func failPendingIO(err error) {
	ioMu.Lock()
	defer ioMu.Unlock()
	for id, ch := range ioPending {
		ch <- ioResult{err: err}
		delete(ioPending, id)
	}
}

// dartTransport implements api.GoReadWriteCloserInterface on top of the Dart I/O callback.
type dartTransport struct{}

func (dartTransport) Read(n int) ([]byte, error) {
	return ioRequest(C.BB_IO_READ, nil, n)
}

func (dartTransport) Write(p []byte) (int, error) {
	if _, err := ioRequest(C.BB_IO_WRITE, p, 0); err != nil {
		return 0, err
	}
	return len(p), nil
}

func (dartTransport) Close() error {
	_, err := ioRequest(C.BB_IO_CLOSE, nil, 0)
	return err
}

// runAsync runs fn off the calling thread and posts its outcome to Dart under callID.
// The api package panics on errors; those are recovered here instead of killing the app.
func runAsync(callID C.int64_t, fn func() ([]byte, error)) {
	go func() {
		var out []byte
		var err error
		func() {
			defer func() {
				if r := recover(); r != nil {
					err = fmt.Errorf("%v", r)
				}
			}()
			opMu.Lock()
			defer opMu.Unlock()
			out, err = fn()
		}()
		postResult(int64(callID), out, err)
	}()
}

func postResult(callID int64, out []byte, err error) {
	ioMu.Lock()
	fn := resultFn
	ioMu.Unlock()
	if fn == nil {
		return
	}
	status := int32(0)
	if err != nil {
		status, out = 1, []byte(err.Error())
	}
	data, length := cBytes(out)
	callResult(fn, callID, status, data, length)
}

func goBytes(data *C.uint8_t, length C.int32_t) []byte {
	return C.GoBytes(unsafe.Pointer(data), C.int(length))
}

// --- Bridge plumbing --------------------------------------------------------------------

//export BBRegister
func BBRegister(io C.bb_io_request_fn, result C.bb_result_fn) {
	ioMu.Lock()
	defer ioMu.Unlock()
	ioFn, resultFn = io, result
}

// BBDeliverIO completes a transfer started by ioRequest. Non-blocking; Dart may free data
// as soon as it returns.
//
//export BBDeliverIO
func BBDeliverIO(reqID C.int64_t, status C.int32_t, data *C.uint8_t, length C.int32_t) {
	ioMu.Lock()
	ch, ok := ioPending[int64(reqID)]
	delete(ioPending, int64(reqID))
	ioMu.Unlock()
	if !ok {
		return // already failed by failPendingIO
	}
	b := goBytes(data, length)
	if status != 0 {
		ch <- ioResult{err: errors.New(string(b))}
		return
	}
	ch <- ioResult{data: b}
}

//export BBFree
func BBFree(p *C.uint8_t) {
	C.free(unsafe.Pointer(p))
}

// --- Device API ---------------------------------------------------------------------------

//export BBOpen
func BBOpen(callID C.int64_t) {
	runAsync(callID, func() ([]byte, error) {
		api.GetDevice(dartTransport{})
		forwardEvents(api.Device())
		return nil, nil
	})
}

// BBClose fails in-flight transfers first so a hung operation releases opMu.
//
//export BBClose
func BBClose(callID C.int64_t) {
	failPendingIO(errClosed)
	runAsync(callID, func() ([]byte, error) {
		return nil, dartTransport{}.Close()
	})
}

// BBInitDevice runs the attestation check, unlock and noise pairing. It blocks until the user
// accepts or rejects the pairing code on the device and returns the resulting status, e.g.
// "unpaired" (confirm with BBChannelHashVerify) or "pairingFailed".
//
//export BBInitDevice
func BBInitDevice(callID C.int64_t) {
	runAsync(callID, func() ([]byte, error) {
		api.InitDevice()
		return []byte(api.Device().Status()), nil
	})
}

//export BBGetChannelHash
func BBGetChannelHash(callID C.int64_t) {
	runAsync(callID, func() ([]byte, error) {
		return []byte(api.GetChannelHash()), nil
	})
}

//export BBChannelHashVerify
func BBChannelHashVerify(callID C.int64_t, ok C.bool) {
	runAsync(callID, func() ([]byte, error) {
		api.ChannelHashVerify(bool(ok))
		return nil, nil
	})
}

//export BBGetMasterFingerprint
func BBGetMasterFingerprint(callID C.int64_t) {
	runAsync(callID, func() ([]byte, error) {
		return api.GetMasterFingerprint(), nil
	})
}

//export BBBTCXPub
func BBBTCXPub(callID C.int64_t, coinType C.int32_t, keypath *C.uint8_t, keypathLen C.int32_t, addressType C.int32_t, display C.bool) {
	// Copy inputs before returning: Dart frees them as soon as this call returns.
	path := hex.EncodeToString(goBytes(keypath, keypathLen))
	runAsync(callID, func() ([]byte, error) {
		return []byte(api.BTCXPub(int(coinType), path, int(addressType), bool(display))), nil
	})
}

//export BBBTCSignPSBT
func BBBTCSignPSBT(callID C.int64_t, coinType C.int32_t, psbt *C.uint8_t, psbtLen C.int32_t) {
	p := string(goBytes(psbt, psbtLen))
	runAsync(callID, func() ([]byte, error) {
		return []byte(api.BTCSignPSBT(int(coinType), p)), nil
	})
}

//export BBSupportsETH
func BBSupportsETH(callID C.int64_t, chainID C.int64_t) {
	runAsync(callID, func() ([]byte, error) {
		return boolResult(api.SupportsETH(int(chainID))), nil
	})
}

//export BBSupportsLTC
func BBSupportsLTC(callID C.int64_t) {
	runAsync(callID, func() ([]byte, error) {
		return boolResult(api.SupportsLTC()), nil
	})
}

//export BBSupportsERC20
func BBSupportsERC20(callID C.int64_t, contractAddress *C.char) {
	contract := C.GoString(contractAddress)
	runAsync(callID, func() ([]byte, error) {
		return boolResult(api.SupportsERC20(contract)), nil
	})
}

//export BBBTCSignMessage
func BBBTCSignMessage(callID C.int64_t, coinType C.int32_t, keypath *C.uint8_t, keypathLen C.int32_t, msg *C.uint8_t, msgLen C.int32_t) {
	path := hex.EncodeToString(goBytes(keypath, keypathLen))
	m := goBytes(msg, msgLen)
	runAsync(callID, func() ([]byte, error) {
		return api.BTCSignMessage(int(coinType), path, m), nil
	})
}

//export BBETHGetAddress
func BBETHGetAddress(callID C.int64_t, chainID C.int64_t, keypath *C.uint8_t, keypathLen C.int32_t, outputType C.int32_t, display C.bool) {
	path := hex.EncodeToString(goBytes(keypath, keypathLen))
	runAsync(callID, func() ([]byte, error) {
		return []byte(api.ETHGetAddress(int(chainID), path, int(outputType), bool(display), []byte{})), nil
	})
}

// BBETHSignTransaction takes gasPrice and value as hex strings without 0x prefix.
//
//export BBETHSignTransaction
func BBETHSignTransaction(callID C.int64_t, chainID C.int64_t, keypath *C.uint8_t, keypathLen C.int32_t, nonce C.int64_t, gasPrice *C.char, gasLimit C.int64_t, recipient *C.uint8_t, recipientLen C.int32_t, value *C.char, data *C.uint8_t, dataLen C.int32_t, recipientAddressCase C.int32_t) {
	path := hex.EncodeToString(goBytes(keypath, keypathLen))
	gp, v := C.GoString(gasPrice), C.GoString(value)
	to, d := goBytes(recipient, recipientLen), goBytes(data, dataLen)
	runAsync(callID, func() ([]byte, error) {
		return api.ETHSignTransaction(int(chainID), path, int(nonce), gp, int(gasLimit), to, v, d, int(recipientAddressCase)), nil
	})
}

// BBETHSignEIP1559 takes the fee values and value as hex strings without 0x prefix.
//
//export BBETHSignEIP1559
func BBETHSignEIP1559(callID C.int64_t, chainID C.int64_t, keypath *C.uint8_t, keypathLen C.int32_t, nonce C.int64_t, maxPriorityFeePerGas *C.char, maxFeePerGas *C.char, gasLimit C.int64_t, recipient *C.uint8_t, recipientLen C.int32_t, value *C.char, data *C.uint8_t, dataLen C.int32_t, recipientAddressCase C.int32_t) {
	path := hex.EncodeToString(goBytes(keypath, keypathLen))
	prio, fee, v := C.GoString(maxPriorityFeePerGas), C.GoString(maxFeePerGas), C.GoString(value)
	to, d := goBytes(recipient, recipientLen), goBytes(data, dataLen)
	runAsync(callID, func() ([]byte, error) {
		return api.ETHSignEIP1559(int(chainID), path, int(nonce), prio, fee, int(gasLimit), to, v, d, int(recipientAddressCase)), nil
	})
}

// BBETHSignRLPTx takes the RLP-encoded unsigned transaction as a hex string.
//
//export BBETHSignRLPTx
func BBETHSignRLPTx(callID C.int64_t, chainID C.int64_t, keypath *C.uint8_t, keypathLen C.int32_t, encodedTx *C.char, isEIP1559 C.bool) {
	path := hex.EncodeToString(goBytes(keypath, keypathLen))
	tx := C.GoString(encodedTx)
	runAsync(callID, func() ([]byte, error) {
		return api.ETHSignRPLTx(int(chainID), path, tx, bool(isEIP1559)), nil
	})
}

//export BBETHSignMessage
func BBETHSignMessage(callID C.int64_t, chainID C.int64_t, keypath *C.uint8_t, keypathLen C.int32_t, msg *C.uint8_t, msgLen C.int32_t) {
	path := hex.EncodeToString(goBytes(keypath, keypathLen))
	m := goBytes(msg, msgLen)
	runAsync(callID, func() ([]byte, error) {
		return api.ETHSignMessage(int(chainID), path, m), nil
	})
}

//export BBETHSignTypedMessage
func BBETHSignTypedMessage(callID C.int64_t, chainID C.int64_t, keypath *C.uint8_t, keypathLen C.int32_t, jsonMsg *C.uint8_t, jsonMsgLen C.int32_t) {
	path := hex.EncodeToString(goBytes(keypath, keypathLen))
	m := goBytes(jsonMsg, jsonMsgLen)
	runAsync(callID, func() ([]byte, error) {
		return api.ETHSignTypedMessage(int(chainID), path, m), nil
	})
}

func boolResult(b bool) []byte {
	if b {
		return []byte{1}
	}
	return []byte{0}
}
