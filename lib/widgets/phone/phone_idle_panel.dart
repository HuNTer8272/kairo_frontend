import 'package:flutter/material.dart';

import '../../models/bluetooth_device_info.dart';
import '../../models/bluetooth_state.dart';
import '../../services/bluetooth/bluetooth_service.dart';
import '../bluetooth/bluetooth_empty_state.dart';

/// Center panel: what KAIRO actually knows about phone/call connectivity.
///
/// KAIRO has no Telecom/HFP integration — Android does not let a normal
/// app register as a Bluetooth hands-free unit or control calls. This
/// panel only shows the Bluetooth call-audio connection state Android
/// itself reports for a paired phone. It never shows a fake call, fake
/// contact, or claims call control that does not exist.
class PhoneIdlePanel extends StatelessWidget {
  const PhoneIdlePanel({
    super.key,
    required this.bluetooth,
    required this.phone,
    this.onOpenBluetooth,
  });

  final BluetoothService bluetooth;
  final PairedDeviceInfo? phone;

  /// Opens the Bluetooth screen to pair a device; null hides the shortcut.
  final VoidCallback? onOpenBluetooth;

  @override
  Widget build(BuildContext context) {
    if (!bluetooth.isOn) return _bluetoothOff();
    final p = phone;
    if (p == null) return _noPhone();
    if (p.callsConnected != true) return _notConnected(p);
    return _connected(context, p);
  }

  Widget _bluetoothOff() {
    switch (bluetooth.availability) {
      case BluetoothAvailability.checking:
        return const BluetoothEmptyState(
          busy: true,
          title: 'Checking Bluetooth',
          message: 'Reading the Bluetooth state of this tablet.',
        );
      case BluetoothAvailability.unsupported:
        return const BluetoothEmptyState(
          icon: Icons.phonelink_erase_rounded,
          title: 'Bluetooth unavailable',
          message: 'This tablet does not report a Bluetooth radio, so '
              'phone status cannot be read here.',
        );
      case BluetoothAvailability.permissionRequired:
        return BluetoothEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Allow Bluetooth access',
          message: 'KAIRO needs the Nearby devices permission to see '
              'whether your phone is connected for calls.',
          primaryLabel: 'Allow access',
          onPrimary: bluetooth.requestPermission,
        );
      case BluetoothAvailability.permissionBlocked:
        return BluetoothEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Bluetooth access is off',
          message: 'Permission was denied. Turn on Nearby devices for '
              'KAIRO in Android settings, then come back here.',
          primaryLabel: 'Open app settings',
          onPrimary: bluetooth.openAppSettings,
        );
      case BluetoothAvailability.turningOn:
      case BluetoothAvailability.turningOff:
        return BluetoothEmptyState(
          busy: true,
          title: bluetooth.availability == BluetoothAvailability.turningOn
              ? 'Turning on Bluetooth'
              : 'Turning off Bluetooth',
          message: 'One moment…',
        );
      case BluetoothAvailability.off:
        return BluetoothEmptyState(
          icon: Icons.bluetooth_disabled_rounded,
          title: 'Bluetooth is off',
          message:
              'Turn on Bluetooth to see your phone\'s connection status.',
          primaryLabel: 'Turn on Bluetooth',
          onPrimary: bluetooth.turnOn,
        );
      case BluetoothAvailability.on:
        return const SizedBox.shrink();
    }
  }

  Widget _noPhone() {
    return BluetoothEmptyState(
      icon: Icons.phonelink_setup_rounded,
      title: 'No phone paired',
      message: 'Pair your phone with this tablet in Bluetooth settings to '
          'see its connection status here.',
      primaryLabel: onOpenBluetooth != null ? 'Open Bluetooth' : null,
      onPrimary: onOpenBluetooth,
    );
  }

  Widget _notConnected(PairedDeviceInfo phone) {
    return BluetoothEmptyState(
      icon: Icons.phone_disabled_rounded,
      title: '${phone.displayName} is paired',
      message: 'Android is not reporting an active call-audio connection '
          'right now. Check that Bluetooth is on and your phone is in '
          'range.',
      primaryLabel: onOpenBluetooth != null ? 'Open Bluetooth' : null,
      onPrimary: onOpenBluetooth,
    );
  }

  Widget _connected(BuildContext context, PairedDeviceInfo phone) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.55),
                ),
              ),
              child: Icon(
                Icons.phone_in_talk_rounded,
                size: 42,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              phone.displayName,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Connected for calls over Bluetooth',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'KAIRO cannot place, answer, or end calls — Android '
                      'does not let a normal app control calls this way. '
                      'Manage calls from your phone. The dial pad here '
                      'opens your phone\'s dialer with a number ready to '
                      'call.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
