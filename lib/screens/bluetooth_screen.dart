import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Opens when the bluetooth icon in the bottom dock is tapped.
class BluetoothScreen extends StatelessWidget {
  const BluetoothScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.bluetooth_rounded,
      title: 'Bluetooth',
      subtitle: 'No paired devices',
    );
  }
}
