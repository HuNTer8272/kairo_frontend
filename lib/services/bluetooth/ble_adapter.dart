import '../../models/bluetooth_device_info.dart';

/// Radio state as reported by the platform.
enum BleRadioState {
  unknown,
  unavailable,
  unauthorized,
  turningOn,
  on,
  turningOff,
  off,
}

/// Bluetooth Low Energy operations the app uses. Implemented by
/// [FlutterBluePlusAdapter] on real hardware and by [MockBleAdapter] in
/// the development-only demo mode.
abstract interface class BleAdapter {
  /// True only for the simulated adapter.
  bool get isMock;

  Future<bool> isSupported();

  /// Emits the current state first, then every change.
  Stream<BleRadioState> radioState();

  /// Asks the user to enable Bluetooth (Android system dialog).
  Future<void> turnOn();

  Stream<bool> isScanning();

  /// All devices seen since the current scan started.
  Stream<List<BleDeviceInfo>> scanResults();

  Future<void> startScan({
    required Duration timeout,
    required bool requireLocationServices,
  });

  Future<void> stopScan();

  Future<void> connect(String id, {required Duration timeout});

  Future<void> disconnect(String id);

  /// Emits the current state first; true while connected.
  Stream<bool> connectionState(String id);

  /// Discovers services and reads standard battery / device information.
  Future<BleDeviceDetails> readDetails(String id);

  Future<int?> readRssi(String id);
}

/// A BLE operation failed; [message] is safe to show to the user.
class BleException implements Exception {
  const BleException(this.message, {this.locationServicesOff = false});

  final String message;

  /// Android ≤ 11 needs Location services on to return scan results.
  final bool locationServicesOff;

  @override
  String toString() => 'BleException: $message';
}
