# bitbox_flutter

A Flutter plugin for the [BitBox02](https://bitbox.swiss) hardware wallet. It wraps
[bitbox02-api-go](https://github.com/BitBoxSwiss/bitbox02-api-go) through `dart:ffi`.

| Platform | Transport                               |
|----------|-----------------------------------------|
| Android  | USB (`BitboxUsbConnectionManager`), BLE |
| iOS      | BLE (`BitboxBleConnectionManager`)      |

BLE requires a BitBox02 Nova.

## Requirements

- Dart 3.10+. The Go library is built by a build hook (`hook/build.dart`).
- [Go](https://go.dev/dl) on the build machine.
- Android: the Android NDK. iOS: Xcode.

## Usage

```dart
final manager = BitboxUsbConnectionManager(); // or BitboxBleConnectionManager()

final device = await manager.scan().first;
await manager.stopScan();

// Pairing: the code shows up as an event while initBitBox() is running.
final events = manager.events.listen((e) {
  if (e.event == 'channelHashChanged' && !e.channelHashVerified) {
    print('Pairing code: ${e.channelHash}');
  }
});
final connection = await manager.connect(device);
await connection.initBitBox();
await connection.channelHashVerify();
await events.cancel();

final bitcoin = BitboxBitcoin(connection.ffi);
final xpub = await bitcoin.getXPub("m/84'/0'/0'");

final ethereum = BitboxEthereum(connection.ffi, chainId: 1);
final address = await ethereum.getAddress("m/44'/60'/0'/0/0");
```

See `example/` for a complete app.

## Development

After changing the Go exports in `go/ffi`, regenerate the header and Dart bindings:

```sh
dart run tool/ffigen.dart
```
