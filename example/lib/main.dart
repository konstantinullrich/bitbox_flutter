import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:bitbox_flutter/bitbox_manager.dart';
import 'package:bitbox_flutter/usb/bitbox_usb_platform_interface.dart';
import 'package:bitbox_flutter/usb/bitbox_device.dart';
import 'package:bitbox_flutter_example/widgets/bitbox_device_card.dart';
import 'package:convert/convert.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

typedef CallbackProgress = Void Function(Int);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<BitboxDevice> _devices = [];
  BitboxDevice? _connectedDevice;
  final _bitboxFlutterPlugin = BitboxManager();

  @override
  void initState() {
    super.initState();
    // initPlatformState();
  }

  bool uninit = true;
  Future<void> initPlatformState() async {
    if (uninit) {
      await BitboxUsbPlatform.instance.requestPermission(BitboxDevice.fromIdentifier(""));
      uninit = false;
    }

    List<BitboxDevice> device;
    device = await _bitboxFlutterPlugin.devices;
    if (!mounted) return;

    setState(() {
      _devices = device;
      _connectedDevice = null;
    });
  }

  Future<void> onPressDevice(BitboxDevice usbDevice) async {
    await _bitboxFlutterPlugin.connect(usbDevice);

    bool isConnected = await BitboxUsbPlatform.instance.completeConnect();

    int tries = 0;
    while (!isConnected) {
      print("Tries: $tries");
      Future.delayed(Duration(milliseconds: 500));
      isConnected = await BitboxUsbPlatform.instance.completeConnect();
    }

    setState(() => _connectedDevice = usbDevice);
    print("Connected!");

    await _bitboxFlutterPlugin.initBitBox();

    await BitboxUsbPlatform.instance.channelHashVerify();
    final masterFP = await _bitboxFlutterPlugin.getMasterFingerprint();

    print("masterFP: $masterFP");

    final ltc = await _bitboxFlutterPlugin.supportsLTC();
    final eth = await _bitboxFlutterPlugin.supportsETH(1);
    final base = await _bitboxFlutterPlugin.supportsETH(8453);
    final deuro = await _bitboxFlutterPlugin.supportsERC20(
      "0xbA3f535bbCcCcA2A154b573Ca6c5A49BAAE0a3ea",
    );
    final usdc = await _bitboxFlutterPlugin.supportsERC20(
      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    );

    print("LTC: $ltc\nETH: $eth\nBASE: $base\ndEURO: $deuro\nUSDC: $usdc");
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      appBar: AppBar(
        title: const Text('BitBox'),
        actions: [
          IconButton(onPressed: initPlatformState, icon: Icon(Icons.refresh)),
        ],
      ),
      body:
          _connectedDevice != null
              ? BitboxScreen(
                usbDevice: _connectedDevice!,
                usbManager: _bitboxFlutterPlugin,
              )
              : Center(
                child: ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, i) {
                    final device = _devices[i];
                    return GestureDetector(
                      onTap: () => onPressDevice(device),
                      child: BitboxDeviceCard(device: device),
                    );
                  },
                ),
              ),
    ),
  );
}

class BitboxScreen extends StatefulWidget {
  final BitboxDevice usbDevice;
  final BitboxManager usbManager;

  const BitboxScreen({
    super.key,
    required this.usbDevice,
    required this.usbManager,
  });

  @override
  State<StatefulWidget> createState() => _BitboxScreenState();
}

class _BitboxScreenState extends State<BitboxScreen> {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      BitboxDeviceCard(device: widget.usbDevice),
      ExpansionTile(
        title: const Text('Bitcoin'),
        children: <Widget>[
          MaterialButton(
            onPressed: () async {
              final address = await widget.usbManager.getBTCXPub(
                0,
                "m/84'/0'/0'",
                1,
              );
              print(address);
            },
            child: const Text("Get BTC XPub"),
          ),
          MaterialButton(
            onPressed: () async {
              final sig = await widget.usbManager.signBTCMessage(
                0,
                "m/84'/0'/0'/0/0",
                utf8.encode("Hey Bitbox"),
              );
              print(sig);
            },
            child: const Text("Sign Message 'Hey Bitbox'"),
          ),
        ],
      ),
      ExpansionTile(
        title: const Text('Ethereum'),
        children: <Widget>[
          MaterialButton(
            onPressed: () async {
              final address = await widget.usbManager.getETHAddress(
                1,
                "m/44'/60'/0'/0/0",
              );
              print(address);
            },
            child: const Text("Get ETH Address"),
          ),
          MaterialButton(
            onPressed: () async {
              final sig = await widget.usbManager.signETHMessage(
                1,
                "m/44'/60'/0'/0/0",
                utf8.encode("Hey Bitbox"),
              );
              print(sig);
            },
            child: const Text("Sign Message 'Hey Bitbox'"),
          ),
          MaterialButton(
            onPressed: () async {
              final sig = await widget.usbManager.signETHTypedMessage(
                1,
                "m/44'/60'/0'/0/0",
                utf8.encode(
                  '{"types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"},{"name":"verifyingContract","type":"address"}],"Person":[{"name":"name","type":"string"},{"name":"wallet","type":"address"}],"Mail":[{"name":"from","type":"Person"},{"name":"to","type":"Person"},{"name":"contents","type":"string"}]},"primaryType":"Mail","domain":{"name":"Ether Mail","version":"1","chainId":1,"verifyingContract":"0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"},"message":{"from":{"name":"Cow","wallet":"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},"to":{"name":"Bob","wallet":"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},"contents":"Hello, Bob!"}}',
                ),
              );
              print(sig);
            },
            child: const Text("Sign Typed Message"),
          ),
          MaterialButton(
            onPressed: () async {
              final sig = await widget.usbManager.signETHTypedMessage(
                1,
                "m/44'/60'/0'/0/0",
                utf8.encode(
                  '{"types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"},{"name":"verifyingContract","type":"address"}],"Person":[{"name":"name","type":"string"},{"name":"wallet","type":"address"}],"Mail":[{"name":"from","type":"Person"},{"name":"to","type":"Person"},{"name":"contents","type":"string"}]},"primaryType":"Mail","domain":{"name":"Ether Mail","version":"1","chainId":1,"verifyingContract":"0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"},"message":{"from":{"name":"Cow","wallet":"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},"to":{"name":"Bob","wallet":"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},"contents":"Hello, Bob!"}}',
                ),
              );
              print(sig);
            },
            child: const Text("Sign Typed Message"),
          ),
          MaterialButton(
            onPressed: () async {
              final sig = await widget.usbManager.signETHTransaction(
                1,
                "m/44'/60'/0'/0/0",
                1,
                BigInt.from(100000000),
                1000,
                hexToBytes("0xCf99569890771d869BfC28C776D07F59b0636D72"),
                BigInt.parse("1000000000000000000"),
                Uint8List(0),
                0,
              );
              print(sig);
            },
            child: const Text("Sign Transaction"),
          ),
          MaterialButton(
            onPressed: () async {
              final sig = await widget.usbManager.signETHTransactionEIP1559(
                1,
                "m/44'/60'/0'/0/0",
                1,
                BigInt.from(1),
                BigInt.from(10000000000),
                1000,
                hexToBytes("0xCf99569890771d869BfC28C776D07F59b0636D72"),
                BigInt.parse("1000000000000000000"),
                Uint8List(0),
                0,
              );
              print(sig);
            },
            child: const Text("Sign EIP1559 Transaction"),
          ),
        ],
      ),

    ],
  );
}

String strip0x(String hex) {
  if (hex.startsWith('0x')) return hex.substring(2);
  return hex;
}

Uint8List hexToBytes(String hexStr) {
  final bytes = hex.decode(strip0x(hexStr));
  if (bytes is Uint8List) return bytes;

  return Uint8List.fromList(bytes);
}
