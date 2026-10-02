import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_tablet_ui/models/bluetooth_device_info.dart';
import 'package:vehicle_tablet_ui/models/bluetooth_state.dart';
import 'package:vehicle_tablet_ui/screens/bluetooth_screen.dart';
import 'package:vehicle_tablet_ui/services/bluetooth/ble_adapter.dart';
import 'package:vehicle_tablet_ui/services/bluetooth/bluetooth_permissions.dart';
import 'package:vehicle_tablet_ui/services/bluetooth/bluetooth_service.dart';
import 'package:vehicle_tablet_ui/services/bluetooth/bluetooth_system.dart';
import 'package:vehicle_tablet_ui/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAdapter adapter;
  late _FakeSystem system;
  late _FakePermissions permissions;
  BluetoothService? service;

  BluetoothService create() => service = BluetoothService(
        adapter: adapter,
        system: system,
        permissions: permissions,
      );

  setUp(() {
    adapter = _FakeAdapter();
    system = _FakeSystem();
    permissions = _FakePermissions();
  });
  tearDown(() {
    service?.dispose();
    service = null;
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('availability', () {
    test('unsupported hardware', () async {
      adapter.supported = false;
      final s = create();
      await s.open();
      expect(s.availability, BluetoothAvailability.unsupported);
    });

    test('asks before requesting, then follows the radio', () async {
      permissions.status = BluetoothPermissionStatus.denied;
      final s = create();
      await s.open();
      expect(s.availability, BluetoothAvailability.permissionRequired);
      expect(permissions.requests, 0, reason: 'no prompt on open');

      permissions.grantOnRequest = true;
      await s.requestPermission();
      adapter.radio.add(BleRadioState.on);
      await settle();
      expect(s.availability, BluetoothAvailability.on);
      expect(adapter.scans, 1, reason: 'scans once when shown');
    });

    test('permanent denial offers app settings', () async {
      permissions.status = BluetoothPermissionStatus.permanentlyDenied;
      final s = create();
      await s.open();
      expect(s.availability, BluetoothAvailability.permissionBlocked);
    });

    test('radio off clears links and results', () async {
      final s = await _connected(create, adapter);
      adapter.radio.add(BleRadioState.off);
      await settle();
      expect(s.availability, BluetoothAvailability.off);
      expect(s.linkedDevices, isEmpty);
      expect(s.availableDevices, isEmpty);
    });

    test('Android 12+ does not require Location services to scan', () async {
      system.sdk = 34;
      final s = create();
      await s.open();
      adapter.radio.add(BleRadioState.on);
      await settle();
      expect(adapter.lastRequireLocation, isFalse);
      expect(s.isOn, isTrue);
    });

    test('Android 11 requires Location services to scan', () async {
      system.sdk = 30;
      final s = create();
      await s.open();
      adapter.radio.add(BleRadioState.on);
      await settle();
      expect(adapter.lastRequireLocation, isTrue);
    });
  });

  group('scanning', () {
    test('named devices first, then by signal; empty scan is reported',
        () async {
      final s = create();
      await s.open();
      adapter.radio.add(BleRadioState.on);
      await settle();

      adapter.scanning.add(true);
      adapter.results.add([
        _device('A', null, -40),
        _device('B', 'Sensor', -80),
        _device('C', 'Tag', -50),
      ]);
      await settle();
      expect(s.isScanning, isTrue);
      expect(s.availableDevices.map((d) => d.id), ['C', 'B', 'A']);

      adapter.results.add(const []);
      adapter.scanning.add(false);
      await settle();
      expect(s.hasScanned, isTrue);
      expect(s.availableDevices, isEmpty);
    });

    test('scan errors are surfaced, not swallowed', () async {
      adapter.scanError = const BleException(
        'Turn on Location services',
        locationServicesOff: true,
      );
      final s = create();
      await s.open();
      adapter.radio.add(BleRadioState.on);
      await settle();
      expect(s.locationServicesOff, isTrue);
      expect(s.message, contains('Location'));
    });
  });

  group('connections', () {
    test('connect moves the device to the connected list with details',
        () async {
      final s = await _connected(create, adapter);
      expect(s.linkState('B'), BluetoothLinkState.connected);
      expect(s.linkedDevices.single.id, 'B');
      expect(s.availableDevices.map((d) => d.id), isNot(contains('B')));
      expect(s.details('B')!.batteryLevel, 64);
      expect(s.rssi('B'), -61, reason: 'live RSSI replaces scan RSSI');
    });

    test('failed connection is reported on the device', () async {
      adapter.connectError = const BleException('The device did not respond');
      final s = create();
      await s.open();
      adapter.radio.add(BleRadioState.on);
      adapter.results.add([_device('B', 'Sensor', -60)]);
      await settle();

      await s.connect('B');
      expect(s.linkState('B'), BluetoothLinkState.failed);
      expect(s.linkError('B'), contains('respond'));
      expect(s.availableDevices.single.id, 'B');
    });

    test('an unexpected drop is detected and announced', () async {
      final s = await _connected(create, adapter);
      adapter.link('B').add(false);
      await settle();
      expect(s.linkState('B'), BluetoothLinkState.disconnected);
      expect(s.details('B'), isNull);
      expect(s.message, 'Sensor disconnected');
    });

    test('user disconnect is quiet', () async {
      final s = await _connected(create, adapter);
      await s.disconnect('B');
      expect(s.linkState('B'), BluetoothLinkState.disconnected);
      expect(adapter.disconnected, contains('B'));
      expect(s.message, isNull);
    });
  });

  test('paired Android devices are loaded read-only', () async {
    system.paired = [
      PairedDeviceInfo.fromMap(const {
        'address': '00:11',
        'name': 'Car Kit',
        'type': 'classic',
        'category': 'audio',
        'audioConnected': true,
        'callsConnected': false,
      }),
    ];
    final s = create();
    await s.open();
    adapter.radio.add(BleRadioState.on);
    await settle();
    final p = s.pairedDevices.single;
    expect(p.transport, BluetoothTransport.classic);
    expect(p.category, BluetoothDeviceCategory.audio);
    expect(p.isConnected, isTrue);
  });

  test('GAP appearance decodes to a device kind', () {
    expect(
        _device('X', 'HR', -50, appearance: 0x0340).kind, 'Heart-rate sensor');
    expect(_device('X', 'Y', -50).kind, isNull);
  });

  group('Bluetooth screen renders without overflow', () {
    Future<void> pump(
        WidgetTester tester, BluetoothService s, bool dark) async {
      tester.view.physicalSize = const Size(1280, 716);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: BluetoothScreen(bluetooth: s),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    final setups = <String, Future<void> Function()>{
      'permission required': () async =>
          permissions.status = BluetoothPermissionStatus.denied,
      'permission blocked': () async =>
          permissions.status = BluetoothPermissionStatus.permanentlyDenied,
      'unsupported': () async => adapter.supported = false,
      'off': () async => adapter.initialRadio = BleRadioState.off,
      'on, nothing found': () async {},
      'on, devices': () async {
        adapter.connectedDetails = true;
        system.paired = [
          PairedDeviceInfo.fromMap(const {
            'address': '00:11',
            'name': 'A very long car kit name that should ellipsize nicely',
            'type': 'dual',
            'category': 'phone',
            'audioConnected': true,
            'callsConnected': true,
          }),
        ];
      },
    };

    for (final entry in setups.entries) {
      for (final dark in [false, true]) {
        testWidgets('${entry.key} (${dark ? 'dark' : 'light'})',
            (tester) async {
          await entry.value();
          final s = create();
          await pump(tester, s, dark);
          await tester.runAsync(settle);
          if (entry.key == 'on, devices') {
            adapter.results.add([
              _device('B', 'Sensor', -61, appearance: 0x0340),
              for (var i = 0; i < 12; i++)
                _device('N$i', 'Nearby device number $i', -50 - i),
            ]);
            await tester.runAsync(() => s.connect('B'));
          }
          if (entry.key == 'on, nothing found') {
            adapter.scanning.add(false);
          }
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}

Future<BluetoothService> _connected(
  BluetoothService Function() create,
  _FakeAdapter adapter,
) async {
  final s = create();
  await s.open();
  adapter.radio.add(BleRadioState.on);
  adapter.results.add([_device('B', 'Sensor', -70)]);
  await Future<void>.delayed(Duration.zero);
  await s.connect('B');
  await Future<void>.delayed(Duration.zero);
  return s;
}

BleDeviceInfo _device(String id, String? name, int rssi, {int? appearance}) =>
    BleDeviceInfo(
      id: id,
      name: name,
      rssi: rssi,
      connectable: true,
      lastSeen: DateTime(2026),
      appearance: appearance,
    );

class _FakeAdapter implements BleAdapter {
  bool supported = true;
  BleRadioState initialRadio = BleRadioState.on;
  BleException? scanError;
  BleException? connectError;
  bool connectedDetails = true;
  int scans = 0;
  bool? lastRequireLocation;
  final List<String> disconnected = [];

  final radio = StreamController<BleRadioState>.broadcast();
  final scanning = StreamController<bool>.broadcast();
  final results = StreamController<List<BleDeviceInfo>>.broadcast();
  final Map<String, StreamController<bool>> _links = {};

  StreamController<bool> link(String id) =>
      _links.putIfAbsent(id, StreamController<bool>.broadcast);

  @override
  bool get isMock => false;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Stream<BleRadioState> radioState() async* {
    yield initialRadio;
    yield* radio.stream;
  }

  @override
  Future<void> turnOn() async => radio.add(BleRadioState.on);

  @override
  Stream<bool> isScanning() => scanning.stream;

  @override
  Stream<List<BleDeviceInfo>> scanResults() => results.stream;

  @override
  Future<void> startScan({
    required Duration timeout,
    required bool requireLocationServices,
  }) async {
    lastRequireLocation = requireLocationServices;
    if (scanError != null) throw scanError!;
    scans++;
    scanning.add(true);
  }

  @override
  Future<void> stopScan() async => scanning.add(false);

  @override
  Future<void> connect(String id, {required Duration timeout}) async {
    if (connectError != null) throw connectError!;
    link(id).add(true);
  }

  @override
  Future<void> disconnect(String id) async {
    disconnected.add(id);
    link(id).add(false);
  }

  @override
  Stream<bool> connectionState(String id) async* {
    yield false;
    yield* link(id).stream;
  }

  @override
  Future<BleDeviceDetails> readDetails(String id) async => connectedDetails
      ? const BleDeviceDetails(
          batteryLevel: 64,
          manufacturer: 'Acme',
          model: 'HR-2',
          services: ['1800', '1801', '180d', '180f', '180a'],
        )
      : const BleDeviceDetails();

  @override
  Future<int?> readRssi(String id) async => -61;
}

class _FakeSystem implements BluetoothSystem {
  int? sdk = 34;
  List<PairedDeviceInfo> paired = const [];

  @override
  Future<int?> sdkInt() async => sdk;

  @override
  Future<bool> openBluetoothSettings() async => true;

  @override
  Future<List<PairedDeviceInfo>> pairedDevices() async => paired;

  @override
  Stream<void> changes() => const Stream.empty();
}

class _FakePermissions implements BluetoothPermissions {
  BluetoothPermissionStatus status = BluetoothPermissionStatus.granted;
  bool grantOnRequest = false;
  int requests = 0;

  @override
  Future<BluetoothPermissionStatus> check(int? sdkInt) async => status;

  @override
  Future<BluetoothPermissionStatus> request(int? sdkInt) async {
    requests++;
    if (grantOnRequest) status = BluetoothPermissionStatus.granted;
    return status;
  }

  @override
  Future<bool> openAppSettings() async => true;
}
