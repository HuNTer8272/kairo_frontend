import 'package:permission_handler/permission_handler.dart' as ph;

enum BluetoothPermissionStatus { granted, denied, permanentlyDenied }

/// Runtime permissions needed for BLE scanning and connecting.
abstract interface class BluetoothPermissions {
  Future<BluetoothPermissionStatus> check(int? sdkInt);
  Future<BluetoothPermissionStatus> request(int? sdkInt);
  Future<bool> openAppSettings();
}

class PlatformBluetoothPermissions implements BluetoothPermissions {
  const PlatformBluetoothPermissions();

  /// Android 12+ (API 31): BLUETOOTH_SCAN (declared neverForLocation) and
  /// BLUETOOTH_CONNECT. Android 11 and older: BLE scanning is gated by
  /// location, and BLUETOOTH/BLUETOOTH_ADMIN are install-time permissions.
  /// Non-Android platforms: the plugin handles its own prompts.
  static List<ph.Permission> _required(int? sdkInt) {
    if (sdkInt == null) return const [];
    if (sdkInt >= 31) {
      return [ph.Permission.bluetoothScan, ph.Permission.bluetoothConnect];
    }
    return [ph.Permission.locationWhenInUse];
  }

  @override
  Future<BluetoothPermissionStatus> check(int? sdkInt) async =>
      _combine([for (final p in _required(sdkInt)) await p.status]);

  @override
  Future<BluetoothPermissionStatus> request(int? sdkInt) async {
    final permissions = _required(sdkInt);
    if (permissions.isEmpty) return BluetoothPermissionStatus.granted;
    final results = await permissions.request();
    return _combine(results.values.toList());
  }

  @override
  Future<bool> openAppSettings() => ph.openAppSettings();

  static BluetoothPermissionStatus _combine(
    List<ph.PermissionStatus> statuses,
  ) {
    if (statuses.every((s) => s.isGranted || s.isLimited)) {
      return BluetoothPermissionStatus.granted;
    }
    if (statuses.any((s) => s.isPermanentlyDenied || s.isRestricted)) {
      return BluetoothPermissionStatus.permanentlyDenied;
    }
    return BluetoothPermissionStatus.denied;
  }
}

/// Used with the mock adapter.
class GrantedBluetoothPermissions implements BluetoothPermissions {
  const GrantedBluetoothPermissions();

  @override
  Future<BluetoothPermissionStatus> check(int? sdkInt) async =>
      BluetoothPermissionStatus.granted;

  @override
  Future<BluetoothPermissionStatus> request(int? sdkInt) async =>
      BluetoothPermissionStatus.granted;

  @override
  Future<bool> openAppSettings() async => false;
}
