import 'dart:async';

import '../../models/bluetooth_device_info.dart';
import 'ble_adapter.dart';

/// Development-only simulated BLE radio. Enabled only with
/// `--dart-define=BLUETOOTH_MOCK=true`; the UI always labels it
/// "Demo/Mock Mode". Devices are named "Demo …" so they can never be
/// mistaken for real hardware. No battery level is simulated.
class MockBleAdapter implements BleAdapter {
  final _radio = StreamController<BleRadioState>.broadcast();
  final _scanning = StreamController<bool>.broadcast();
  final _results = StreamController<List<BleDeviceInfo>>.broadcast();
  final Map<String, StreamController<bool>> _links = {};
  final Set<String> _connected = {};
  Timer? _scanTimer;

  static final List<BleDeviceInfo> _demoDevices = [
    BleDeviceInfo(
      id: 'DE:MO:00:00:00:01',
      name: 'Demo Heart-Rate Strap',
      rssi: -58,
      connectable: true,
      lastSeen: DateTime(2026),
      appearance: 13 << 6,
      serviceUuids: const ['180d', '180f'],
    ),
    BleDeviceInfo(
      id: 'DE:MO:00:00:00:02',
      name: 'Demo Tag',
      rssi: -74,
      connectable: true,
      lastSeen: DateTime(2026),
      appearance: 8 << 6,
    ),
    BleDeviceInfo(
      id: 'DE:MO:00:00:00:03',
      name: null,
      rssi: -88,
      connectable: false,
      lastSeen: DateTime(2026),
    ),
  ];

  @override
  bool get isMock => true;

  @override
  Future<bool> isSupported() async => true;

  @override
  Stream<BleRadioState> radioState() async* {
    yield BleRadioState.on;
    yield* _radio.stream;
  }

  @override
  Future<void> turnOn() async => _radio.add(BleRadioState.on);

  @override
  Stream<bool> isScanning() => _scanning.stream;

  @override
  Stream<List<BleDeviceInfo>> scanResults() => _results.stream;

  @override
  Future<void> startScan({
    required Duration timeout,
    required bool requireLocationServices,
  }) async {
    _scanTimer?.cancel();
    _results.add(const []);
    _scanning.add(true);
    var shown = 0;
    _scanTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (shown < _demoDevices.length) {
        shown++;
        _results.add([
          for (final d in _demoDevices.take(shown))
            BleDeviceInfo(
              id: d.id,
              name: d.name,
              rssi: d.rssi,
              connectable: d.connectable,
              lastSeen: DateTime.now(),
              appearance: d.appearance,
              serviceUuids: d.serviceUuids,
            ),
        ]);
      }
      if (timer.tick * 900 >= timeout.inMilliseconds) stopScan();
    });
  }

  @override
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    _scanning.add(false);
  }

  @override
  Future<void> connect(String id, {required Duration timeout}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (id == _demoDevices[1].id) {
      throw const BleException('Demo: simulated connection failure');
    }
    _connected.add(id);
    _link(id).add(true);
  }

  @override
  Future<void> disconnect(String id) async {
    _connected.remove(id);
    _link(id).add(false);
  }

  @override
  Stream<bool> connectionState(String id) async* {
    yield _connected.contains(id);
    yield* _link(id).stream;
  }

  @override
  Future<BleDeviceDetails> readDetails(String id) async =>
      const BleDeviceDetails(
        manufacturer: 'Demo',
        model: 'Mock device',
        services: ['1800', '1801', '180d'],
      );

  @override
  Future<int?> readRssi(String id) async => null;

  StreamController<bool> _link(String id) =>
      _links.putIfAbsent(id, StreamController<bool>.broadcast);
}
