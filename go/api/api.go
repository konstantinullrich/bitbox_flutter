package api

import (
	"io"
	"os/exec"
	"runtime"
	"strings"
	"time"

	"github.com/BitBoxSwiss/bitbox02-api-go/api/firmware"
	"github.com/BitBoxSwiss/bitbox02-api-go/api/firmware/mocks"
	"github.com/konstantinullrich/bitbox_flutter/u2fhid"
)

// fixTimezone sets the local timezone on Android. This is a workaround to the bug that on Android,
// time.Local is hard-coded to UTC. See https://github.com/golang/go/issues/20455.
//
// We need the correct timezone to be able to send the `time.Now().Zone()` offset to the BitBox02.
// Without it, the BitBox02 will always display UTC time instead of local time.
//
// This fix is copied from https://github.com/golang/go/issues/20455#issuecomment-342287698.
func fixTimezone() {
	if runtime.GOOS != "android" {
		// Only run the fix on Android.
		return
	}
	out, err := exec.Command("/system/bin/getprop", "persist.sys.timezone").Output()
	if err != nil {
		return
	}
	z, err := time.LoadLocation(strings.TrimSpace(string(out)))
	if err != nil {
		return
	}
	time.Local = z
}

func init() {
	fixTimezone()
}

// GoReadWriteCloserInterface adapts io.ReadWriteCloser's Read method to return the read bytes
// instead of filling a caller-provided slice, which suits transports that live outside Go.
type GoReadWriteCloserInterface interface {
	Read(n int) ([]byte, error)
	io.Writer
	io.Closer
}

// readWriteCloser implements io.ReadWriteCloser, translating from GoReadWriteCloserInterface. All methods
// are as-is except for Read().
type readWriteCloser struct {
	GoReadWriteCloserInterface
}

// Read implements io.ReadWriteCloser, translating GoReadWriteCloserInterface.Read, which returns a slice
//
//	instead of receiving it as an argument.
func (r readWriteCloser) Read(readBytesOut []byte) (int, error) {
	readBytes, err := r.GoReadWriteCloserInterface.Read(len(readBytesOut))
	if err != nil {
		return 0, err
	}
	copy(readBytesOut, readBytes)
	return len(readBytes), nil
}

var bitbox *firmware.Device

func GetDevice(device GoReadWriteCloserInterface) {
	const bitboxCMD = 0x80 + 0x40 + 0x01
	comm := u2fhid.NewCommunication(readWriteCloser{device}, bitboxCMD)
	bitbox = firmware.NewDevice(nil, nil, &mocks.Config{}, comm, &mocks.Logger{})
}

// Device returns the device created by GetDevice, for callers that need the full firmware
// API (e.g. events).
func Device() *firmware.Device {
	return bitbox
}

func GetChannelHash() string {
	hash, _ := bitbox.ChannelHash()
	return hash
}

func ChannelHashVerify(ok bool) {
	bitbox.ChannelHashVerify(ok)
}

func InitDevice() {
	err := bitbox.Init()
	if err != nil {
		panic(err)
	}
}

func SupportsETH(chainId int) bool {
	return bitbox.SupportsETH(uint64(chainId))
}

func SupportsLTC() bool {
	return bitbox.SupportsLTC()
}

func SupportsERC20(contractAddress string) bool {
	return bitbox.SupportsERC20(contractAddress)
}
