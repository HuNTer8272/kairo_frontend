import 'package:flutter/material.dart';

import '../models/bluetooth_device_info.dart';
import '../models/bluetooth_state.dart';
import '../services/bluetooth/bluetooth_service.dart';
import '../widgets/phone/phone_dial_pad.dart';
import '../widgets/phone/phone_idle_panel.dart';
import '../widgets/phone/phone_recents_panel.dart';
import '../widgets/phone/phone_status_header.dart';

/// Opens when the phone icon in the bottom dock is tapped.
///
/// KAIRO cannot place or receive calls itself: Android does not let a
/// normal app register as a Bluetooth HFP hands-free unit, so there is no
/// way for this tablet to behave like a car kit without a privileged
/// system/AOSP layer (see the Bluetooth implementation audit). This
/// screen shows what is genuinely known instead — whether a phone is
/// paired with Android and connected for calls, read from the same
/// native channel as the Bluetooth screen — plus a dial pad that opens
/// the phone's own dialer app with a number pre-filled.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key, this.bluetooth, this.onOpenBluetooth});

  /// Shared service owned by the app shell. When null (standalone use)
  /// the screen owns a service for its own lifetime, same pattern as
  /// BluetoothScreen.
  final BluetoothService? bluetooth;

  /// Navigates to the Bluetooth screen to pair a device; null hides the
  /// shortcut buttons that would otherwise call it.
  final VoidCallback? onOpenBluetooth;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  late final BluetoothService _bluetooth =
      widget.bluetooth ?? BluetoothService();
  bool get _ownsService => widget.bluetooth == null;

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

  /// The paired phone most relevant to show: connected for calls first,
  /// otherwise the first device Android reports as a phone.
  PairedDeviceInfo? get _phone {
    final phones = _bluetooth.pairedDevices
        .where((d) => d.category == BluetoothDeviceCategory.phone)
        .toList();
    if (phones.isEmpty) return null;
    for (final p in phones) {
      if (p.callsConnected == true) return p;
    }
    return phones.first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: ListenableBuilder(
        listenable: _bluetooth,
        builder: (context, _) {
          final phone = _phone;
          return Padding(
            // Top inset clears the status bar, as on Bluetooth/Music.
            padding: const EdgeInsets.fromLTRB(56, 72, 56, 24),
            child: Column(
              children: [
                PhoneStatusHeader(
                  bluetooth: _bluetooth,
                  phone: phone,
                  onOpenBluetooth: widget.onOpenBluetooth,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(flex: 3, child: PhoneRecentsPanel()),
                      const SizedBox(width: 28),
                      Expanded(
                        flex: 5,
                        child: PhoneIdlePanel(
                          bluetooth: _bluetooth,
                          phone: phone,
                          onOpenBluetooth: widget.onOpenBluetooth,
                        ),
                      ),
                      const SizedBox(width: 28),
                      const Expanded(flex: 4, child: PhoneDialPad()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
