import 'package:flutter/material.dart';

import '../../models/bluetooth_device_info.dart';
import '../../models/bluetooth_state.dart';
import '../../services/bluetooth/bluetooth_service.dart';

/// Phone icon, title and a live status line describing whether a phone is
/// paired with Android and connected for calls over Bluetooth.
class PhoneStatusHeader extends StatelessWidget {
  const PhoneStatusHeader({
    super.key,
    required this.bluetooth,
    required this.phone,
    this.onOpenBluetooth,
  });

  final BluetoothService bluetooth;
  final PairedDeviceInfo? phone;

  /// Opens the Bluetooth screen to pair a device; null hides the shortcut.
  final VoidCallback? onOpenBluetooth;

  bool get _connected => phone?.callsConnected == true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _connected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            border: Border.all(
              color: _connected
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outlineVariant,
            ),
          ),
          child: Icon(
            _connected ? Icons.phone_in_talk_rounded : Icons.phone_rounded,
            color: _connected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Phone',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _status,
                  key: ValueKey(_status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (onOpenBluetooth != null && !_connected) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onOpenBluetooth,
            icon: const Icon(Icons.bluetooth_rounded, size: 18),
            label: const Text('Bluetooth'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
        ],
      ],
    );
  }

  String get _status {
    switch (bluetooth.availability) {
      case BluetoothAvailability.checking:
        return 'Checking Bluetooth…';
      case BluetoothAvailability.unsupported:
        return 'Bluetooth unavailable';
      case BluetoothAvailability.permissionRequired:
      case BluetoothAvailability.permissionBlocked:
        return 'Bluetooth permission required';
      case BluetoothAvailability.off:
        return 'Bluetooth is off';
      case BluetoothAvailability.turningOn:
        return 'Turning on Bluetooth…';
      case BluetoothAvailability.turningOff:
        return 'Turning off Bluetooth…';
      case BluetoothAvailability.on:
        final p = phone;
        if (p == null) return 'No phone paired';
        return p.callsConnected == true
            ? '${p.displayName} connected for calls'
            : '${p.displayName} paired — not connected for calls';
    }
  }
}
