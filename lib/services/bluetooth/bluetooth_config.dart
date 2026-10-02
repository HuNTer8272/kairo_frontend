/// Build-time Bluetooth settings.
abstract final class BluetoothConfig {
  /// Development-only simulated adapter, off unless the app is built with
  /// `--dart-define=BLUETOOTH_MOCK=true`. The UI labels it "Demo/Mock Mode".
  static const bool mockMode = bool.fromEnvironment('BLUETOOTH_MOCK');

  static const Duration scanTimeout = Duration(seconds: 15);
  static const Duration connectTimeout = Duration(seconds: 15);
}
