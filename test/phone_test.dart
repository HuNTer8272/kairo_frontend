import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_tablet_ui/models/bluetooth_device_info.dart';
import 'package:vehicle_tablet_ui/screens/phone_screen.dart';
import 'package:vehicle_tablet_ui/services/bluetooth/ble_adapter.dart';
import 'package:vehicle_tablet_ui/services/bluetooth/bluetooth_permissions.dart';
import 'package:vehicle_tablet_ui/services/bluetooth/bluetooth_service.dart';
import 'package:vehicle_tablet_ui/services/bluetooth/bluetooth_system.dart';
import 'package:vehicle_tablet_ui/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAdapter adapter;
  late _FakeSystem system;
  BluetoothService? service;

  setUp(() {
    adapter = _FakeAdapter();
    system = _FakeSystem();
  });
  tearDown(() {
    service?.dispose();
    service = null;
  });

  Future<void> pump(WidgetTester tester, BluetoothService s, bool dark) async {
    tester.view.physicalSize = const Size(1280, 716);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: PhoneScreen(bluetooth: s, onOpenBluetooth: () {}),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  final setups = <String, void Function()>{
    'bluetooth off': () => adapter.initialRadio = BleRadioState.off,
    'no phone paired': () {},
    'phone paired, calls not connected': () {
      system.paired = [
        PairedDeviceInfo.fromMap(const {
          'address': '00:11',
          'name': 'Pixel 9',
          'type': 'dual',
          'category': 'phone',
          'audioConnected': false,
          'callsConnected': false,
        }),
      ];
    },
    'phone connected for calls': () {
      system.paired = [
        PairedDeviceInfo.fromMap(const {
          'address': '00:11',
          'name': 'A very long phone name that should ellipsize nicely',
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
      testWidgets('${entry.key} (${dark ? 'dark' : 'light'})', (tester) async {
        entry.value();
        final s = service = BluetoothService(
          adapter: adapter,
          system: system,
          permissions: const GrantedBluetoothPermissions(),
        );
        await pump(tester, s, dark);
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('dial pad entry updates the display and can be cleared',
      (tester) async {
    final s = service = BluetoothService(
      adapter: adapter,
      system: system,
      permissions: const GrantedBluetoothPermissions(),
    );
    await pump(tester, s, false);

    await tester.tap(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(find.text('555'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(find.text('55'), findsOneWidget);

    await tester.longPress(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(find.text('Enter a number'), findsOneWidget);
  });
}

class _FakeAdapter implements BleAdapter {
  bool supported = true;
  BleRadioState initialRadio = BleRadioState.on;
  final radio = StreamController<BleRadioState>.broadcast();
  final scanning = StreamController<bool>.broadcast();
  final results = StreamController<List<BleDeviceInfo>>.broadcast();

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
  }) async =>
      scanning.add(true);

  @override
  Future<void> stopScan() async => scanning.add(false);

  @override
  Future<void> connect(String id, {required Duration timeout}) async {}

  @override
  Future<void> disconnect(String id) async {}

  @override
  Stream<bool> connectionState(String id) => Stream.value(false);

  @override
  Future<BleDeviceDetails> readDetails(String id) async =>
      const BleDeviceDetails();

  @override
  Future<int?> readRssi(String id) async => null;
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
