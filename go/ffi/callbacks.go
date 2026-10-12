package main

// cgo can't call C function pointers directly, so we go through static trampolines.
// They live in this file because a file containing //export may only have declarations
// in its preamble.

/*
#include "bridge.h"

static inline void bb_call_io(bb_io_request_fn fn, int64_t id, int32_t op, uint8_t *data, int32_t len) {
	fn(id, op, data, len);
}

static inline void bb_call_result(bb_result_fn fn, int64_t id, int32_t status, uint8_t *data, int32_t len) {
	fn(id, status, data, len);
}
*/
import "C"

import "unsafe"

func callIO(fn C.bb_io_request_fn, id int64, op C.int32_t, data *C.uint8_t, length int) {
	C.bb_call_io(fn, C.int64_t(id), op, data, C.int32_t(length))
}

func callResult(fn C.bb_result_fn, id int64, status int32, data *C.uint8_t, length int) {
	C.bb_call_result(fn, C.int64_t(id), C.int32_t(status), data, C.int32_t(length))
}

// cBytes copies b into C memory that Dart releases with BBFree. Returns nil for empty input.
func cBytes(b []byte) (*C.uint8_t, int) {
	if len(b) == 0 {
		return nil, 0
	}
	p := C.malloc(C.size_t(len(b)))
	copy(unsafe.Slice((*byte)(p), len(b)), b)
	return (*C.uint8_t)(p), len(b)
}
