#ifndef BITBOX_BRIDGE_H
#define BITBOX_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

// Both callbacks are Dart NativeCallable.listener pointers: they can be invoked from any
// thread, return immediately and are delivered asynchronously on the Dart isolate.
// Buffers passed to them are malloc'd by Go and must be released by Dart via BBFree.

// Go asks Dart to perform a USB transfer. For BB_IO_READ, len is the number of bytes
// wanted and data is NULL. For BB_IO_WRITE, data/len hold the bytes to write.
// Dart answers with BBDeliverIO(req_id, ...).
typedef void (*bb_io_request_fn)(int64_t req_id, int32_t op, uint8_t *data, int32_t len);

// Go reports the outcome of an async call started by Dart. status 0 = ok and data holds
// the result; status != 0 = error and data holds a UTF-8 error message.
typedef void (*bb_result_fn)(int64_t call_id, int32_t status, uint8_t *data, int32_t len);

enum {
  BB_IO_READ = 0,
  BB_IO_WRITE = 1,
  BB_IO_CLOSE = 2,
};

#endif
