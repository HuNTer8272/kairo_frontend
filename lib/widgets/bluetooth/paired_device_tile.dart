import 'package:flutter/material.dart';

import '../../models/bluetooth_device_info.dart';
import '../../models/bluetooth_state.dart';

/// A device paired in Android's Bluetooth settings. Read-only: shows what
/// Android reports (type, media/call connection) without offering actions
/// the app cannot actually perform.
class PairedDeviceTile extends StatelessWidget {
  const PairedDeviceTile({super.key, required this.device});

  final PairedDeviceInfo device;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = device.isConnected;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: connected ? scheme.primaryContainer : scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(
              _icon,
              size: 20,
              color: connected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.transport.label} · ${device.category.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: connected ? FontWeight.w700 : FontWeight.w500,
              color: connected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String get _status {
    final audio = device.audioConnected == true;
    final calls = device.callsConnected == true;
    if (audio && calls) return 'Media + Calls';
    if (audio) return 'Media audio';
    if (calls) return 'Calls';
    return 'Paired';
  }

  IconData get _icon => switch (device.category) {
        BluetoothDeviceCategory.audio => Icons.headphones_rounded,
        BluetoothDeviceCategory.phone => Icons.smartphone_rounded,
        BluetoothDeviceCategory.computer => Icons.computer_rounded,
        BluetoothDeviceCategory.peripheral => Icons.keyboard_rounded,
        BluetoothDeviceCategory.wearable => Icons.watch_rounded,
        BluetoothDeviceCategory.other => Icons.devices_other_rounded,
      };
}
