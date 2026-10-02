import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

import '../../models/bluetooth_device_info.dart';
import 'ble_adapter.dart';

/// [BleAdapter] backed by flutter_blue_plus (real BLE hardware).
class FlutterBluePlusAdapter implements BleAdapter {
  /// flutter_blue_plus 2.x requires declaring the license a connection is
  /// made under. `nonprofit` covers personal, educational and nonprofit
  /// use; for-profit organisations must buy a commercial license and switch
  /// this to `fbp.License.commercial`.
  static const fbp.License license = fbp.License.nonprofit;

  static const String _batteryService = '180f';
  static const String _batteryLevel = '2a19';
  static const String _deviceInfoService = '180a';
  static const String _manufacturerName = '2a29';
  static const String _modelNumber = '2a24';

  @override
  bool get isMock => false;

  @override
  Future<bool> isSupported() => fbp.FlutterBluePlus.isSupported;

  @override
  Stream<BleRadioState> radioState() =>
      fbp.FlutterBluePlus.adapterState.map((s) => switch (s) {
            fbp.BluetoothAdapterState.unknown => BleRadioState.unknown,
            fbp.BluetoothAdapterState.unavailable => BleRadioState.unavailable,
            fbp.BluetoothAdapterState.unauthorized =>
              BleRadioState.unauthorized,
            fbp.BluetoothAdapterState.turningOn => BleRadioState.turningOn,
            fbp.BluetoothAdapterState.on => BleRadioState.on,
            fbp.BluetoothAdapterState.turningOff => BleRadioState.turningOff,
            fbp.BluetoothAdapterState.off => BleRadioState.off,
          });

  @override
  Future<void> turnOn() => _guard(fbp.FlutterBluePlus.turnOn);

  @override
  Stream<bool> isScanning() => fbp.FlutterBluePlus.isScanning;

  @override
  Stream<List<BleDeviceInfo>> scanResults() =>
      fbp.FlutterBluePlus.scanResults.map((results) => [
            for (final r in results)
              BleDeviceInfo(
                id: r.device.remoteId.str,
                name: r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : (r.device.platformName.isNotEmpty
                        ? r.device.platformName
                        : null),
                rssi: r.rssi,
                connectable: r.advertisementData.connectable,
                lastSeen: r.timeStamp,
                appearance: r.advertisementData.appearance,
                serviceUuids: [
                  for (final uuid in r.advertisementData.serviceUuids) uuid.str,
                ],
              ),
          ]);

  @override
  Future<void> startScan({
    required Duration timeout,
    required bool requireLocationServices,
  }) {
    return _guard(() => fbp.FlutterBluePlus.startScan(
          timeout: timeout,
          // BLUETOOTH_SCAN is declared neverForLocation, so on Android 12+
          // neither the location permission nor Location services are needed.
          androidUsesFineLocation: false,
          androidCheckLocationServices: requireLocationServices,
        ));
  }

  @override
  Future<void> stopScan() => _guard(fbp.FlutterBluePlus.stopScan);

  @override
  Future<void> connect(String id, {required Duration timeout}) {
    return _guard(() => fbp.BluetoothDevice.fromId(id).connect(
          license: license,
          timeout: timeout,
        ));
  }

  @override
  Future<void> disconnect(String id) =>
      _guard(() => fbp.BluetoothDevice.fromId(id).disconnect());

  @override
  Stream<bool> connectionState(String id) =>
      fbp.BluetoothDevice.fromId(id).connectionState.map(
            (s) => s == fbp.BluetoothConnectionState.connected,
          );

  @override
  Future<BleDeviceDetails> readDetails(String id) async {
    final services =
        await _guard(() => fbp.BluetoothDevice.fromId(id).discoverServices());

    int? battery;
    String? manufacturer;
    String? model;
    for (final service in services) {
      final serviceId = service.serviceUuid.str.toLowerCase();
      if (serviceId != _batteryService && serviceId != _deviceInfoService) {
        continue;
      }
      for (final c in service.characteristics) {
        if (!c.properties.read) continue;
        final charId = c.characteristicUuid.str.toLowerCase();
        try {
          if (serviceId == _batteryService && charId == _batteryLevel) {
            final value = await c.read();
            if (value.isNotEmpty && value.first <= 100) battery = value.first;
          } else if (charId == _manufacturerName) {
            manufacturer = _decode(await c.read());
          } else if (charId == _modelNumber) {
            model = _decode(await c.read());
          }
        } catch (_) {
          // Some devices require bonding/encryption to read; leave it empty.
        }
      }
    }

    return BleDeviceDetails(
      batteryLevel: battery,
      manufacturer: manufacturer,
      model: model,
      services: [for (final s in services) s.serviceUuid.str.toLowerCase()],
    );
  }

  @override
  Future<int?> readRssi(String id) async {
    try {
      return await fbp.BluetoothDevice.fromId(id).readRssi();
    } catch (_) {
      return null;
    }
  }

  static String? _decode(List<int> bytes) {
    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll('\u0000', '')
        .trim();
    return text.isEmpty ? null : text;
  }

  /// Converts plugin errors into [BleException] with a readable message.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on fbp.FlutterBluePlusException catch (e) {
      final description = e.description ?? '';
      if (description.contains('Location services')) {
        throw const BleException(
          'Turn on Location services to scan. Android 11 and older require '
          'it for Bluetooth scanning.',
          locationServicesOff: true,
        );
      }
      if (e.code == fbp.FbpErrorCode.timeout.index) {
        throw const BleException('The device did not respond in time');
      }
      if (e.code == fbp.FbpErrorCode.userRejected.index) {
        throw const BleException('Bluetooth was not turned on');
      }
      if (e.code == fbp.FbpErrorCode.connectionCanceled.index) {
        throw const BleException('Connection cancelled');
      }
      throw BleException(
        description.isEmpty ? 'Bluetooth error (${e.function})' : description,
      );
    } on PlatformException catch (e) {
      throw BleException(e.message ?? 'Bluetooth error (${e.code})');
    }
  }
}
