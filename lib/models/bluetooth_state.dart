/// Whether Bluetooth can be used at all, as shown by the UI.
enum BluetoothAvailability {
  /// Still asking the platform.
  checking,

  /// This device has no Bluetooth LE radio (or the platform has no support).
  unsupported,

  /// Runtime permission not granted yet; asking is still possible.
  permissionRequired,

  /// Permission denied permanently; only system settings can grant it.
  permissionBlocked,
  off,
  turningOn,
  turningOff,
  on,
}

/// Connection state of one BLE device, from this app's point of view.
enum BluetoothLinkState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  failed,
}

/// Radio technology a device uses, as reported by Android.
enum BluetoothTransport {
  ble,
  classic,

  /// Classic + LE ("dual mode"), e.g. most phones and car kits.
  dual,
  unknown;

  String get label => switch (this) {
        ble => 'BLE',
        classic => 'Classic',
        dual => 'Classic + BLE',
        unknown => 'Unknown',
      };
}

/// Android's major device class for paired devices.
enum BluetoothDeviceCategory {
  audio,
  phone,
  computer,
  peripheral,
  wearable,
  other;

  static BluetoothDeviceCategory fromName(String? name) =>
      values.asNameMap()[name] ?? other;

  String get label => switch (this) {
        audio => 'Audio',
        phone => 'Phone',
        computer => 'Computer',
        peripheral => 'Input device',
        wearable => 'Wearable',
        other => 'Device',
      };
}
