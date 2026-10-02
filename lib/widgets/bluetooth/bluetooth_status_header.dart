import 'package:flutter/material.dart';

import '../../models/bluetooth_state.dart';
import '../../services/bluetooth/bluetooth_service.dart';
import 'bluetooth_scan_button.dart';

/// Bluetooth icon, title, live status line and the scan/refresh actions.
class BluetoothStatusHeader extends StatelessWidget {
  const BluetoothStatusHeader({super.key, required this.bluetooth});

  final BluetoothService bluetooth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = bluetooth.isOn;
    final connected = bluetooth.linkedDevices
        .where((d) => bluetooth.linkState(d.id) == BluetoothLinkState.connected)
        .toList();

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                on ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            border: Border.all(
              color: on
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outlineVariant,
            ),
          ),
          child: Icon(
            _icon(connected.isNotEmpty),
            color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Bluetooth',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  if (bluetooth.isMock) ...[
                    const SizedBox(width: 12),
                    const _MockBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _status(connected.map((d) => d.displayName).toList()),
                  key: ValueKey(
                      _status(connected.map((d) => d.displayName).toList())),
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
        if (on) ...[
          BluetoothScanButton(
            scanning: bluetooth.isScanning,
            onScan: bluetooth.startScan,
            onStop: bluetooth.stopScan,
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Refresh',
            onPressed: bluetooth.refresh,
            style: IconButton.styleFrom(
              side: BorderSide(color: scheme.outlineVariant),
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ],
    );
  }

  IconData _icon(bool connected) {
    if (connected) return Icons.bluetooth_connected_rounded;
    return switch (bluetooth.availability) {
      BluetoothAvailability.on => bluetooth.isScanning
          ? Icons.bluetooth_searching_rounded
          : Icons.bluetooth_rounded,
      _ => Icons.bluetooth_disabled_rounded,
    };
  }

  String _status(List<String> connectedNames) {
    switch (bluetooth.availability) {
      case BluetoothAvailability.checking:
        return 'Checking Bluetooth…';
      case BluetoothAvailability.unsupported:
        return 'Bluetooth unavailable';
      case BluetoothAvailability.permissionRequired:
      case BluetoothAvailability.permissionBlocked:
        return 'Permission required';
      case BluetoothAvailability.off:
        return 'Bluetooth Off';
      case BluetoothAvailability.turningOn:
        return 'Turning on…';
      case BluetoothAvailability.turningOff:
        return 'Turning off…';
      case BluetoothAvailability.on:
        if (connectedNames.length == 1) {
          return 'Connected · ${connectedNames.single}';
        }
        if (connectedNames.length > 1) {
          return 'Connected · ${connectedNames.length} devices';
        }
        final connecting = bluetooth.linkedDevices.any(
            (d) => bluetooth.linkState(d.id) == BluetoothLinkState.connecting);
        if (connecting) return 'Connecting…';
        if (bluetooth.isScanning) return 'Scanning…';
        return 'Ready to connect';
    }
  }
}

class _MockBadge extends StatelessWidget {
  const _MockBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Simulated devices for development. Not real Bluetooth.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.error),
        ),
        child: Text(
          'Demo/Mock Mode',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.error,
          ),
        ),
      ),
    );
  }
}
