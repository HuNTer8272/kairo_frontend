import 'bluetooth_state.dart';

/// A BLE device seen in a scan. Every field comes from the advertisement;
/// nothing is filled in when the device does not report it.
class BleDeviceInfo {
  const BleDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
    required this.connectable,
    required this.lastSeen,
    this.appearance,
    this.serviceUuids = const [],
  });

  /// MAC address on Android.
  final String id;

  /// Advertised or cached name; null when the device sends none.
  final String? name;
  final int rssi;
  final bool connectable;
  final DateTime lastSeen;

  /// GAP Appearance value, when advertised.
  final int? appearance;
  final List<String> serviceUuids;

  bool get hasName => name != null && name!.isNotEmpty;
  String get displayName => hasName ? name! : 'Unnamed device';

  /// Device kind decoded from the advertised GAP Appearance category.
  String? get kind =>
      appearance == null ? null : _appearanceKinds[appearance! >> 6];

  static const Map<int, String> _appearanceKinds = {
    1: 'Phone',
    2: 'Computer',
    3: 'Watch',
    5: 'Display',
    6: 'Remote control',
    7: 'Eyewear',
    8: 'Tag',
    9: 'Keyring',
    10: 'Media player',
    12: 'Thermometer',
    13: 'Heart-rate sensor',
    15: 'Input device',
    17: 'Fitness sensor',
    18: 'Cycling sensor',
    33: 'Audio sink',
    34: 'Audio source',
  };
}

/// Information read from a connected BLE device's GATT services.
/// Each field is null when the device does not expose it.
class BleDeviceDetails {
  const BleDeviceDetails({
    this.batteryLevel,
    this.manufacturer,
    this.model,
    this.services = const [],
  });

  /// Battery Service (0x180F) level, 0–100.
  final int? batteryLevel;

  /// Device Information Service (0x180A) strings.
  final String? manufacturer;
  final String? model;

  /// Short service UUIDs ("180f") or full 128-bit UUIDs.
  final List<String> services;

  static String serviceName(String uuid) =>
      _serviceNames[uuid.toLowerCase()] ?? uuid.toUpperCase();

  static const Map<String, String> _serviceNames = {
    '1800': 'Generic Access',
    '1801': 'Generic Attribute',
    '180a': 'Device Information',
    '180d': 'Heart Rate',
    '180f': 'Battery',
    '1812': 'Human Interface',
    '1816': 'Cycling Speed',
    '1818': 'Cycling Power',
    '1819': 'Location',
    '181c': 'User Data',
    '1809': 'Health Thermometer',
    '1805': 'Current Time',
    '184e': 'Audio Stream Control',
  };
}

/// A device paired with Android itself (Settings › Bluetooth), usually
/// Bluetooth Classic phones, headphones and car kits. Read-only: Android
/// does not let ordinary apps connect or disconnect these.
class PairedDeviceInfo {
  const PairedDeviceInfo({
    required this.address,
    required this.name,
    required this.transport,
    required this.category,
    this.audioConnected,
    this.callsConnected,
  });

  factory PairedDeviceInfo.fromMap(Map<Object?, Object?> map) {
    return PairedDeviceInfo(
      address: map['address'] as String,
      name: map['name'] as String?,
      transport: switch (map['type']) {
        'classic' => BluetoothTransport.classic,
        'le' => BluetoothTransport.ble,
        'dual' => BluetoothTransport.dual,
        _ => BluetoothTransport.unknown,
      },
      category: BluetoothDeviceCategory.fromName(map['category'] as String?),
      audioConnected: map['audioConnected'] as bool?,
      callsConnected: map['callsConnected'] as bool?,
    );
  }

  final String address;
  final String? name;
  final BluetoothTransport transport;
  final BluetoothDeviceCategory category;

  /// A2DP (media audio) connection; null when Android has not reported it.
  final bool? audioConnected;

  /// HFP/HSP (calls) connection; null when Android has not reported it.
  final bool? callsConnected;

  String get displayName => name == null || name!.isEmpty ? address : name!;

  bool get isConnected => audioConnected == true || callsConnected == true;
}
