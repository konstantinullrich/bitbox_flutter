import 'package:bitbox_flutter/src/bitbox_device.dart';
import 'package:flutter/material.dart';

class BitboxDeviceCard extends StatelessWidget {
  final BitboxDevice device;

  const BitboxDeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(24),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainer,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Image.asset("assets/bitbox.png", width: 50),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(
              device.productName,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    ),
  );
}
