import 'package:bitbox_flutter/bitbox_flutter.dart';
import 'package:flutter/material.dart';

class BitboxConnectionIndicator extends StatelessWidget {
  final BitboxConnection connection;

  const BitboxConnectionIndicator({super.key, required this.connection});

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: connection.statusChanges,
    initialData: connection.status,
    builder: (context, snapshot) {
      final (color, label) = switch (snapshot.data!) {
        BitboxConnectionStatus.connected => (Colors.green, 'Connected'),
        BitboxConnectionStatus.pairing => (Colors.amber, 'Pairing'),
        BitboxConnectionStatus.connecting => (Colors.blue, 'Connecting'),
        BitboxConnectionStatus.disconnected => (Colors.red, 'Disconnected'),
      };

      return Chip(
        avatar: Icon(Icons.circle, size: 12, color: color),
        label: Text(label),
        visualDensity: VisualDensity.compact,
      );
    },
  );
}
