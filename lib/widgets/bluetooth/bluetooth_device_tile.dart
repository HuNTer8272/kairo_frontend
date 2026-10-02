import 'package:flutter/material.dart';

import '../../models/bluetooth_device_info.dart';
import '../../models/bluetooth_state.dart';
import '../../theme/app_colors.dart';
import 'bluetooth_signal_indicator.dart';

/// One BLE device found by a scan, with its Connect action.
class BluetoothDeviceTile extends StatelessWidget {
  const BluetoothDeviceTile({
    super.key,
    required this.device,
    required this.linkState,
    required this.onConnect,
    this.error,
  });

  final BleDeviceInfo device;
  final BluetoothLinkState linkState;
  final VoidCallback onConnect;

  /// Why the last connection attempt failed.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = [
      'BLE',
      if (device.kind != null) device.kind!,
      device.id,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          BleDeviceIcon(device: device),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: device.hasName
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (linkState == BluetoothLinkState.failed && error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Connection failed · $error',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.alert,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          BluetoothSignalIndicator(rssi: device.rssi),
          const SizedBox(width: 14),
          SizedBox(width: 112, child: _action(scheme)),
        ],
      ),
    );
  }

  Widget _action(ColorScheme scheme) {
    if (!device.connectable) {
      return Text(
        'Broadcast only',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      );
    }
    if (linkState == BluetoothLinkState.connecting) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Connecting', style: TextStyle(fontSize: 13)),
        ],
      );
    }
    return FilledButton(
      onPressed: onConnect,
      child: Text(
        linkState == BluetoothLinkState.failed ? 'Retry' : 'Connect',
      ),
    );
  }
}

/// Icon for a BLE device, chosen from its advertised appearance.
class BleDeviceIcon extends StatelessWidget {
  const BleDeviceIcon({super.key, required this.device, this.active = false});

  final BleDeviceInfo device;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: active ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outlineVariant,
        ),
      ),
      child: Icon(
        _icon,
        size: 20,
        color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
      ),
    );
  }

  IconData get _icon => switch (device.kind) {
        'Phone' => Icons.smartphone_rounded,
        'Computer' => Icons.computer_rounded,
        'Watch' => Icons.watch_rounded,
        'Audio sink' || 'Audio source' => Icons.headphones_rounded,
        'Heart-rate sensor' => Icons.monitor_heart_outlined,
        'Input device' || 'Remote control' => Icons.keyboard_rounded,
        'Tag' || 'Keyring' => Icons.sell_outlined,
        'Thermometer' => Icons.thermostat_rounded,
        'Fitness sensor' || 'Cycling sensor' => Icons.directions_run_rounded,
        _ => Icons.bluetooth_rounded,
      };
}
