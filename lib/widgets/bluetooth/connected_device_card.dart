import 'package:flutter/material.dart';

import '../../models/bluetooth_device_info.dart';
import '../../models/bluetooth_state.dart';
import 'bluetooth_device_tile.dart';
import 'bluetooth_signal_indicator.dart';

/// A BLE device this app is connected (or connecting) to, with the
/// information read from its GATT services and a Disconnect action.
class ConnectedDeviceCard extends StatelessWidget {
  const ConnectedDeviceCard({
    super.key,
    required this.device,
    required this.linkState,
    required this.details,
    required this.loadingDetails,
    required this.rssi,
    required this.onDisconnect,
  });

  final BleDeviceInfo device;
  final BluetoothLinkState linkState;
  final BleDeviceDetails? details;
  final bool loadingDetails;
  final int? rssi;
  final VoidCallback onDisconnect;

  static const Set<String> _genericServices = {'1800', '1801'};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = linkState == BluetoothLinkState.connected;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: connected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BleDeviceIcon(device: device, active: connected),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        'BLE',
                        if (device.kind != null) device.kind!,
                        _stateLabel,
                      ].join(' · '),
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
              OutlinedButton(
                onPressed: linkState == BluetoothLinkState.disconnecting
                    ? null
                    : onDisconnect,
                child: Text(
                  linkState == BluetoothLinkState.connecting
                      ? 'Cancel'
                      : 'Disconnect',
                ),
              ),
            ],
          ),
          if (connected) ...[
            const SizedBox(height: 14),
            _info(scheme),
          ],
        ],
      ),
    );
  }

  String get _stateLabel => switch (linkState) {
        BluetoothLinkState.connecting => 'Connecting…',
        BluetoothLinkState.connected => 'Connected',
        BluetoothLinkState.disconnecting => 'Disconnecting…',
        _ => 'Disconnected',
      };

  Widget _info(ColorScheme scheme) {
    final d = details;
    final services = [
      for (final s in d?.services ?? const <String>[])
        if (!_genericServices.contains(s)) BleDeviceDetails.serviceName(s),
    ];
    final chips = <Widget>[
      if (rssi != null && rssi != 0)
        _InfoChip(child: BluetoothSignalIndicator(rssi: rssi)),
      if (d?.batteryLevel != null)
        _InfoChip(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_batteryIcon(d!.batteryLevel!), size: 16),
              const SizedBox(width: 4),
              Text('${d.batteryLevel}%', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      if (d?.manufacturer != null)
        _InfoChip(
            child:
                Text(d!.manufacturer!, style: const TextStyle(fontSize: 12))),
      if (d?.model != null)
        _InfoChip(child: Text(d!.model!, style: const TextStyle(fontSize: 12))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: chips),
        if (loadingDetails)
          _note(scheme, 'Reading device information…')
        else if (d == null)
          _note(scheme, 'Device information unavailable')
        else ...[
          if (services.isNotEmpty)
            _note(scheme, 'Services: ${services.join(', ')}'),
          if (d.batteryLevel == null &&
              d.manufacturer == null &&
              d.model == null)
            _note(scheme,
                'This device does not expose battery or model information.'),
        ],
        _note(
          scheme,
          'BLE data link only. Not used for media audio or phone calls.',
        ),
      ],
    );
  }

  Widget _note(ColorScheme scheme, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      );

  static IconData _batteryIcon(int level) {
    if (level >= 90) return Icons.battery_full_rounded;
    if (level >= 60) return Icons.battery_5_bar_rounded;
    if (level >= 35) return Icons.battery_3_bar_rounded;
    if (level >= 15) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
