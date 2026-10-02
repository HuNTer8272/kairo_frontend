import 'package:flutter/material.dart';

/// "Scan" / "Stop scanning" toggle for the Bluetooth header.
class BluetoothScanButton extends StatelessWidget {
  const BluetoothScanButton({
    super.key,
    required this.scanning,
    required this.onScan,
    required this.onStop,
  });

  final bool scanning;

  /// Null disables the button (e.g. Bluetooth is off).
  final VoidCallback? onScan;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: scanning ? onStop : onScan,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(
          color: scanning
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outlineVariant,
        ),
        backgroundColor: scanning ? scheme.primaryContainer : null,
        foregroundColor:
            scanning ? scheme.onPrimaryContainer : scheme.onSurface,
      ),
      icon: scanning
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.bluetooth_searching_rounded, size: 18),
      label: Text(scanning ? 'Stop scanning' : 'Scan'),
    );
  }
}
