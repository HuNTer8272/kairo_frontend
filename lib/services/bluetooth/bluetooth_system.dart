import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../models/bluetooth_device_info.dart';

/// Android system Bluetooth, outside what flutter_blue_plus covers: the
/// OS version, the system Bluetooth settings screen, and a read-only view
/// of devices paired with Android (Classic phones, headphones, car kits).
abstract interface class BluetoothSystem {
  /// Android API level; null on other platforms.
  Future<int?> sdkInt();

  Future<bool> openBluetoothSettings();

  /// Devices paired in Android settings, with their A2DP/HFP state.
  /// Throws [BluetoothSystemException] without BLUETOOTH_CONNECT.
  Future<List<PairedDeviceInfo>> pairedDevices();

  /// Fires when a paired device connects, disconnects or (un)pairs.
  Stream<void> changes();
}

class BluetoothSystemException implements Exception {
  const BluetoothSystemException(this.message);
  final String message;
}

/// Talks to BluetoothSystemChannel.kt in the Android app.
class AndroidBluetoothSystem implements BluetoothSystem {
  static const _methods = MethodChannel('kairo/bluetooth_system');
  static const _events = EventChannel('kairo/bluetooth_system/changes');

  bool get _isAndroid => Platform.isAndroid;

  @override
  Future<int?> sdkInt() async {
    if (!_isAndroid) return null;
    return _methods.invokeMethod<int>('sdkInt');
  }

  @override
  Future<bool> openBluetoothSettings() async {
    if (!_isAndroid) return false;
    return await _methods.invokeMethod<bool>('openBluetoothSettings') ?? false;
  }

  @override
  Future<List<PairedDeviceInfo>> pairedDevices() async {
    if (!_isAndroid) return const [];
    try {
      final list = await _methods.invokeListMethod<Map<Object?, Object?>>(
        'pairedDevices',
      );
      return [
        for (final map in list ?? const []) PairedDeviceInfo.fromMap(map)
      ];
    } on PlatformException catch (e) {
      throw BluetoothSystemException(e.message ?? e.code);
    }
  }

  @override
  Stream<void> changes() {
    if (!_isAndroid) return const Stream.empty();
    return _events.receiveBroadcastStream().map((_) {});
  }
}

/// Used with the mock adapter: no system devices, nothing to open.
class MockBluetoothSystem implements BluetoothSystem {
  @override
  Future<int?> sdkInt() async => null;

  @override
  Future<bool> openBluetoothSettings() async => false;

  @override
  Future<List<PairedDeviceInfo>> pairedDevices() async => const [];

  @override
  Stream<void> changes() => const Stream.empty();
}
