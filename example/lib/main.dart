import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bitbox_flutter/bitbox_flutter.dart';
import 'package:bitbox_flutter_example/widgets/bitbox_connection_indicator.dart';
import 'package:bitbox_flutter_example/widgets/bitbox_device_card.dart';
import 'package:convert/convert.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

final _theme = ThemeData(
  colorSchemeSeed: const Color(0xFF6750A4),
  appBarTheme: const AppBarTheme(centerTitle: true, scrolledUnderElevation: 4),
);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _manager = BitboxUsbConnectionManager();
  StreamSubscription<BitboxDevice>? _scanSubscription;
  StreamSubscription<BitboxConnectionStatus>? _statusSubscription;

  List<BitboxDevice> _devices = [];
  BitboxDevice? _connectedDevice;
  BitboxConnection? _connection;
  bool _pairing = false;

  /// Null until the device has generated the code.
  String? _pairingCode;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _stopScan();
    super.dispose();
  }

  Future<void> _stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _manager.stopScan();
  }

  /// Restarts the scan, so the list only shows devices that are still around.
  Future<void> _startScan() async {
    await _stopScan();
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    if (!mounted) return;

    setState(() {
      _devices = [];
      _connectedDevice = null;
      _connection = null;
    });

    _scanSubscription = _manager.scan().listen(
      (device) => setState(() => _devices = [..._devices, device]),
      onError: (Object e) => print("Scan failed: $e"),
    );
  }

  Future<void> _connect(BitboxDevice device) async {
    await _stopScan();

    // Init blocks until the user accepts the pairing code on the device, so the code
    // arrives as an event while it is still running.
    final events = _manager.events.listen((event) {
      if (event.event == 'channelHashChanged' &&
          event.channelHash.isNotEmpty &&
          !event.channelHashVerified) {
        setState(() => _pairingCode = event.channelHash);
      }
    });

    setState(() => _pairing = true);
    BitboxConnection? connection;
    try {
      connection = await _manager.connect(device);
      _watchStatus(connection);
      await connection.initBitBox();
      await connection.channelHashVerify();
    } catch (e) {
      print("Pairing failed: $e");
      await _statusSubscription?.cancel();
      _statusSubscription = null;
      if (mounted) setState(() => _connection = null);
      return;
    } finally {
      await events.cancel();
      if (mounted) {
        setState(() {
          _pairing = false;
          _pairingCode = null;
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _connectedDevice = device;
      _connection = connection;
    });

    final ltc = await connection.supportsLTC();
    final eth = await connection.supportsETH(1);
    final base = await connection.supportsETH(8453);
    final deuro = await connection.supportsERC20("0xbA3f535bbCcCcA2A154b573Ca6c5A49BAAE0a3ea");
    final usdc = await connection.supportsERC20("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
    print("LTC: $ltc\nETH: $eth\nBASE: $base\ndEURO: $deuro\nUSDC: $usdc");
  }

  /// Shows [connection] in the app bar and goes back to scanning once the device is gone.
  void _watchStatus(BitboxConnection connection) {
    setState(() => _connection = connection);
    _statusSubscription = connection.statusChanges.listen((status) {
      // While pairing, a lost device fails the pairing call instead.
      if (status != BitboxConnectionStatus.disconnected || _connectedDevice == null) return;
      print("BitBox disconnected");
      unawaited(connection.disconnect().catchError((_) {}));
      _startScan();
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme,
    home: Scaffold(
      appBar: AppBar(
        title: const Text('BitBox'),
        actions: [
          if (_connection case final connection?)
            BitboxConnectionIndicator(connection: connection),
          IconButton(onPressed: _startScan, icon: const Icon(Icons.refresh), tooltip: 'Scan again'),
        ],
      ),
      body:
          _pairing
              ? PairingView(pairingCode: _pairingCode)
              : _connectedDevice != null
              ? BitboxScreen(device: _connectedDevice!, connection: _connection!)
              : _devices.isEmpty
              ? const _EmptyView()
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _devices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder:
                    (context, i) =>
                        BitboxDeviceCard(device: _devices[i], onTap: () => _connect(_devices[i])),
              ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_other, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              'No BitBox devices found',
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure your device is connected and powered on',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class PairingView extends StatelessWidget {
  /// Null until the device has generated the code.
  final String? pairingCode;

  const PairingView({super.key, this.pairingCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = pairingCode;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (code == null) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text("Connecting to BitBox…", style: theme.textTheme.bodyLarge),
            ] else ...[
              Text("Pairing code", style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    code,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Check that your BitBox shows the same code, then confirm on the device.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

const _btcPath = "m/84'/0'/0'";
const _ethPath = "m/44'/60'/0'/0/0";
const _ethRecipient = "0xCf99569890771d869BfC28C776D07F59b0636D72";
const _typedMessage =
    '{"types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"},{"name":"verifyingContract","type":"address"}],"Person":[{"name":"name","type":"string"},{"name":"wallet","type":"address"}],"Mail":[{"name":"from","type":"Person"},{"name":"to","type":"Person"},{"name":"contents","type":"string"}]},"primaryType":"Mail","domain":{"name":"Ether Mail","version":"1","chainId":1,"verifyingContract":"0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"},"message":{"from":{"name":"Cow","wallet":"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},"to":{"name":"Bob","wallet":"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},"contents":"Hello, Bob!"}}';

class BitboxScreen extends StatefulWidget {
  final BitboxDevice device;
  final BitboxConnection connection;
  final BitboxBitcoin bitcoin;
  final BitboxEthereum ethereum;

  BitboxScreen({super.key, required this.device, required this.connection})
    : bitcoin = BitboxBitcoin(connection.ffi),
      ethereum = BitboxEthereum(connection.ffi);

  @override
  State<BitboxScreen> createState() => _BitboxScreenState();
}

class _BitboxScreenState extends State<BitboxScreen> {
  /// Runs a device call and shows its result, or the error, in a snackbar.
  Future<void> _run(String label, Future<Object?> Function() action) async {
    String message;
    try {
      final result = await action();
      print(result);
      message = '$label: $result';
    } catch (e) {
      print("$label failed: $e");
      message = '$label failed: $e';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bitcoin = widget.bitcoin;
    final ethereum = widget.ethereum;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BitboxDeviceCard(device: widget.device),
        const Divider(height: 32),
        _Section(
          title: 'Bitcoin',
          icon: Icons.currency_bitcoin,
          actions: {
            'Get BTC XPub': () => _run('XPub', () => bitcoin.getXPub(_btcPath)),
            "Sign Message 'Hey Bitbox'":
                () => _run(
                  'Signature',
                  () => bitcoin.signMessage("$_btcPath/0/0", utf8.encode("Hey Bitbox")),
                ),
          },
        ),
        const SizedBox(height: 8),
        _Section(
          title: 'Ethereum',
          icon: Icons.diamond_outlined,
          actions: {
            'Get ETH Address': () => _run('Address', () => ethereum.getAddress(_ethPath)),
            "Sign Message 'Hey Bitbox'":
                () => _run(
                  'Signature',
                  () => ethereum.signMessage(_ethPath, utf8.encode("Hey Bitbox")),
                ),
            'Sign Typed Message':
                () => _run(
                  'Signature',
                  () => ethereum.signTypedMessage(_ethPath, utf8.encode(_typedMessage)),
                ),
            'Sign Transaction':
                () => _run(
                  'Signature',
                  () => ethereum.signTransaction(
                    _ethPath,
                    1,
                    BigInt.from(100000000),
                    1000,
                    hexToBytes(_ethRecipient),
                    BigInt.parse("1000000000000000000"),
                    Uint8List(0),
                    0,
                  ),
                ),
            'Sign EIP1559 Transaction':
                () => _run(
                  'Signature',
                  () => ethereum.signTransactionEIP1559(
                    _ethPath,
                    1,
                    BigInt.from(1),
                    BigInt.from(10000000000),
                    1000,
                    hexToBytes(_ethRecipient),
                    BigInt.parse("1000000000000000000"),
                    Uint8List(0),
                    0,
                  ),
                ),
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;

  /// Button label to the callback it runs.
  final Map<String, VoidCallback> actions;

  const _Section({required this.title, required this.icon, required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ExpansionTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        children: [
          for (final MapEntry(key: label, value: onPressed) in actions.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: FilledButton.tonal(
                onPressed: onPressed,
                child: Align(alignment: Alignment.centerLeft, child: Text(label)),
              ),
            ),
        ],
      ),
    );
  }
}

Uint8List hexToBytes(String hexStr) {
  final bytes = hex.decode(hexStr.startsWith('0x') ? hexStr.substring(2) : hexStr);
  return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
}
