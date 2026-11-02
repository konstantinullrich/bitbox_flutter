package main

/*
#include "bridge.h"
*/
import "C"

import (
	"encoding/json"
	"sync"

	"github.com/BitBoxSwiss/bitbox02-api-go/api/firmware"
)

var (
	eventMu sync.Mutex
	eventFn C.bb_event_fn
)

type eventPayload struct {
	Event               string `json:"event"`
	Status              string `json:"status"`
	ChannelHash         string `json:"channelHash"`
	ChannelHashVerified bool   `json:"channelHashVerified"`
}

//export BBSetEventCallback
func BBSetEventCallback(fn C.bb_event_fn) {
	eventMu.Lock()
	defer eventMu.Unlock()
	eventFn = fn
}

// forwardEvents posts every firmware event to Dart together with a snapshot of the pairing
// state. The pairing code is only observable this way: Init fires channelHashChanged and then
// blocks until the user confirms on the device.
func forwardEvents(device *firmware.Device) {
	device.SetOnEvent(func(event firmware.Event, _ interface{}) {
		eventMu.Lock()
		fn := eventFn
		eventMu.Unlock()
		if fn == nil {
			return
		}
		hash, verified := device.ChannelHash()
		payload, err := json.Marshal(eventPayload{
			Event:               string(event),
			Status:              string(device.Status()),
			ChannelHash:         hash,
			ChannelHashVerified: verified,
		})
		if err != nil {
			return
		}
		data, length := cBytes(payload)
		callEvent(fn, data, length)
	})
}
