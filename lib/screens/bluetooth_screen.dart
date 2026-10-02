import 'package:flutter/material.dart';

import '../models/bluetooth_device_info.dart';
import '../models/bluetooth_state.dart';
import '../services/bluetooth/bluetooth_service.dart';
import '../widgets/bluetooth/bluetooth_device_tile.dart';
import '../widgets/bluetooth/bluetooth_empty_state.dart';
import '../widgets/bluetooth/bluetooth_section_header.dart';
import '../widgets/bluetooth/bluetooth_status_header.dart';
import '../widgets/bluetooth/connected_device_card.dart';
import '../widgets/bluetooth/paired_device_tile.dart';
import '../widgets/common/message_banner.dart';

/// Opens when the bluetooth icon in the bottom dock is tapped.
///
/// Left: BLE devices connected to this app, then devices paired with
/// Android (Classic audio/phones, read-only). Right: nearby BLE devices.
class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key, this.bluetooth});

  /// Shared service owned by the app shell. When null (older shells) the
  /// screen owns a service for its own lifetime.
  final BluetoothService? bluetooth;

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  late final BluetoothService _bluetooth =
      widget.bluetooth ?? BluetoothService();
  bool get _ownsService => widget.bluetooth == null;
  bool _namedOnly = true;

  @override
  void initState() {
    super.initState();
    _bluetooth.open();
  }

  @override
  void dispose() {
    if (_ownsService) {
      _bluetooth.dispose();
    } else {
      _bluetooth.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: ListenableBuilder(
        listenable: _bluetooth,
        builder: (context, _) {
          final message = _bluetooth.message;
          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  // Top inset clears the status bar, as on the Music screen.
                  padding: const EdgeInsets.fromLTRB(56, 72, 56, 24),
                  child: Column(
                    children: [
                      BluetoothStatusHeader(bluetooth: _bluetooth),
                      const SizedBox(height: 24),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: KeyedSubtree(
                            key: ValueKey(_bluetooth.isOn),
                            child: _bluetooth.isOn
                                ? _buildDevices(context)
                                : _buildUnavailable(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (message != null)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 20,
                  child: Center(
                    child: MessageBanner(
                      message: message,
                      onDismiss: _bluetooth.clearMessage,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnavailable() {
    final bt = _bluetooth;
    switch (bt.availability) {
      case BluetoothAvailability.checking:
        return const BluetoothEmptyState(
          busy: true,
          title: 'Checking Bluetooth',
          message: 'Reading the Bluetooth state of this tablet.',
        );
      case BluetoothAvailability.unsupported:
        return const BluetoothEmptyState(
          icon: Icons.bluetooth_disabled_rounded,
          title: 'Bluetooth unavailable',
          message: 'This device does not report a Bluetooth Low Energy '
              'radio, so nearby devices cannot be found here.',
        );
      case BluetoothAvailability.permissionRequired:
        return BluetoothEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Allow Bluetooth access',
          message: 'KAIRO needs the Nearby devices permission to find and '
              'connect to Bluetooth devices. It is not used for location.',
          primaryLabel: 'Allow access',
          onPrimary: bt.requestPermission,
        );
      case BluetoothAvailability.permissionBlocked:
        return BluetoothEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Bluetooth access is off',
          message: 'Permission was denied. Turn on Nearby devices for KAIRO '
              'in Android settings, then come back here.',
          primaryLabel: 'Open app settings',
          onPrimary: bt.openAppSettings,
        );
      case BluetoothAvailability.off:
        return BluetoothEmptyState(
          icon: Icons.bluetooth_disabled_rounded,
          title: 'Bluetooth is off',
          message: 'Turn on Bluetooth to find nearby devices and see your '
              'paired phones and audio devices.',
          primaryLabel: 'Turn on Bluetooth',
          onPrimary: bt.turnOn,
          secondaryLabel: 'Android Bluetooth settings',
          onSecondary: bt.isMock ? null : bt.openSystemBluetoothSettings,
        );
      case BluetoothAvailability.turningOn:
      case BluetoothAvailability.turningOff:
        return BluetoothEmptyState(
          busy: true,
          title: bt.availability == BluetoothAvailability.turningOn
              ? 'Turning on Bluetooth'
              : 'Turning off Bluetooth',
          message: 'One moment…',
        );
      case BluetoothAvailability.on:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDevices(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildLeftColumn()),
        const SizedBox(width: 28),
        Expanded(flex: 6, child: _buildNearby()),
      ],
    );
  }

  Widget _buildLeftColumn() {
    final bt = _bluetooth;
    final linked = bt.linkedDevices;
    final paired = bt.pairedDevices;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const BluetoothSectionHeader(
          title: 'Connected',
          subtitle: 'Bluetooth Low Energy devices connected to KAIRO',
        ),
        if (linked.isEmpty)
          _HintCard(
            icon: Icons.link_off_rounded,
            text: 'No BLE device connected. Choose one from the nearby list.',
          )
        else
          for (final d in linked) ...[
            ConnectedDeviceCard(
              key: ValueKey('connected-${d.id}'),
              device: d,
              linkState: bt.linkState(d.id),
              details: bt.details(d.id),
              loadingDetails: bt.isLoadingDetails(d.id),
              rssi: bt.rssi(d.id),
              onDisconnect: () => bt.disconnect(d.id),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 24),
        BluetoothSectionHeader(
          title: 'Paired with Android',
          subtitle: 'Phones, headphones and car audio (Bluetooth Classic)',
          trailing: bt.isMock
              ? null
              : TextButton.icon(
                  onPressed: bt.openSystemBluetoothSettings,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Android settings'),
                ),
        ),
        if (bt.pairedError != null)
          _HintCard(
            icon: Icons.error_outline_rounded,
            text: 'Could not read paired devices: ${bt.pairedError}',
          )
        else if (paired.isEmpty)
          _HintCard(
            icon: Icons.devices_other_rounded,
            text: bt.isMock
                ? 'Paired devices are not simulated in Demo/Mock Mode.'
                : 'No devices are paired with this tablet.',
          )
        else
          for (final p in paired) ...[
            PairedDeviceTile(key: ValueKey('paired-${p.address}'), device: p),
            const SizedBox(height: 8),
          ],
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pairing, media audio and hands-free calls for these '
                  'devices are handled by Android. KAIRO shows their status '
                  'but cannot connect or disconnect them. That needs native '
                  'Android Bluetooth Classic integration.',
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
    );
  }

  Widget _buildNearby() {
    final bt = _bluetooth;
    final all = bt.availableDevices;
    final visible = _namedOnly ? all.where((d) => d.hasName).toList() : all;
    final hidden = all.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BluetoothSectionHeader(
          title: 'Nearby BLE devices',
          subtitle: bt.isScanning
              ? 'Scanning… ${all.length} found'
              : (bt.hasScanned ? '${all.length} found' : null),
          trailing: FilterChip(
            label: const Text('Named only'),
            selected: _namedOnly,
            onSelected: (value) => setState(() => _namedOnly = value),
          ),
        ),
        if (bt.isScanning)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Expanded(child: _nearbyList(visible, hidden)),
      ],
    );
  }

  Widget _nearbyList(List<BleDeviceInfo> visible, int hidden) {
    final bt = _bluetooth;
    if (visible.isEmpty) {
      if (bt.isScanning) {
        return const BluetoothEmptyState(
          compact: true,
          busy: true,
          title: 'Searching for devices',
          message: 'Make sure the device is powered on and advertising.',
        );
      }
      if (bt.locationServicesOff) {
        return const BluetoothEmptyState(
          compact: true,
          icon: Icons.location_off_rounded,
          title: 'Location services are off',
          message: 'Android 11 and older only return Bluetooth scan results '
              'while Location services are on.',
        );
      }
      if (bt.hasScanned) {
        return BluetoothEmptyState(
          compact: true,
          icon: Icons.bluetooth_searching_rounded,
          title: 'No nearby Bluetooth devices found',
          message: hidden > 0
              ? '$hidden unnamed device${hidden == 1 ? '' : 's'} hidden.'
              : 'Only BLE devices that are advertising appear here. '
                  'Headphones and phones are usually paired in Android '
                  'settings instead.',
          primaryLabel: hidden > 0 ? 'Show unnamed' : 'Scan again',
          onPrimary: hidden > 0
              ? () => setState(() => _namedOnly = false)
              : bt.startScan,
        );
      }
      return BluetoothEmptyState(
        compact: true,
        icon: Icons.bluetooth_searching_rounded,
        title: 'Ready to scan',
        message: 'Scan to find Bluetooth Low Energy devices nearby.',
        primaryLabel: 'Scan',
        onPrimary: bt.startScan,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: visible.length + (hidden > 0 ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == visible.length) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _namedOnly = false),
              child: Text(
                'Show $hidden unnamed device${hidden == 1 ? '' : 's'}',
              ),
            ),
          );
        }
        final d = visible[index];
        return BluetoothDeviceTile(
          key: ValueKey('nearby-${d.id}'),
          device: d,
          linkState: bt.linkState(d.id),
          error: bt.linkError(d.id),
          onConnect: () => bt.connect(d.id),
        );
      },
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
