import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../models/bluetooth_device_info.dart';
import '../../models/bluetooth_state.dart';
import 'ble_adapter.dart';
import 'bluetooth_config.dart';
import 'bluetooth_permissions.dart';
import 'bluetooth_system.dart';
import 'flutter_blue_plus_adapter.dart';
import 'mock_ble_adapter.dart';

/// The single object Bluetooth widgets talk to.
///
/// Owns permissions, the radio state, BLE scanning and BLE connections
/// (through [BleAdapter]), plus a read-only list of devices paired with
/// Android (through [BluetoothSystem]). Lives with the app shell so BLE
/// connections survive leaving the Bluetooth screen.
class BluetoothService extends ChangeNotifier {
  BluetoothService({
    BleAdapter? adapter,
    BluetoothSystem? system,
    BluetoothPermissions? permissions,
  })  : _adapter = adapter ??
            (BluetoothConfig.mockMode
                ? MockBleAdapter()
                : FlutterBluePlusAdapter()),
        _system = system ??
            (BluetoothConfig.mockMode
                ? MockBluetoothSystem()
                : AndroidBluetoothSystem()),
        _permissions = permissions ??
            (BluetoothConfig.mockMode
                ? const GrantedBluetoothPermissions()
                : const PlatformBluetoothPermissions());

  final BleAdapter _adapter;
  final BluetoothSystem _system;
  final BluetoothPermissions _permissions;

  BluetoothAvailability _availability = BluetoothAvailability.checking;
  int? _sdkInt;
  bool _activated = false;
  bool _visible = false;
  bool _disposed = false;

  bool _scanning = false;
  bool _hasScanned = false;
  List<BleDeviceInfo> _scanResults = const [];
  final Map<String, BleDeviceInfo> _known = {};

  final Map<String, BluetoothLinkState> _links = {};
  final Map<String, String> _linkErrors = {};
  final Map<String, StreamSubscription<bool>> _linkSubs = {};
  final Map<String, BleDeviceDetails> _details = {};
  final Set<String> _loadingDetails = {};
  final Map<String, int> _liveRssi = {};

  List<PairedDeviceInfo> _paired = const [];
  String? _pairedError;

  String? _message;
  bool _locationServicesOff = false;

  StreamSubscription<BleRadioState>? _radioSub;
  StreamSubscription<bool>? _scanningSub;
  StreamSubscription<List<BleDeviceInfo>>? _resultsSub;
  StreamSubscription<void>? _systemSub;
  AppLifecycleListener? _lifecycle;

  // State ------------------------------------------------------------------

  BluetoothAvailability get availability => _availability;
  bool get isOn => _availability == BluetoothAvailability.on;
  bool get isMock => _adapter.isMock;
  bool get isScanning => _scanning;

  /// True once a scan has run to completion (or been stopped).
  bool get hasScanned => _hasScanned;

  /// Latest user-facing notice, if any.
  String? get message => _message;

  /// The last scan failed because Location services are off (Android ≤ 11).
  bool get locationServicesOff => _locationServicesOff;

  /// BLE devices this app is connected or connecting to.
  List<BleDeviceInfo> get linkedDevices => [
        for (final entry in _links.entries)
          if (entry.value != BluetoothLinkState.disconnected &&
              entry.value != BluetoothLinkState.failed)
            _known[entry.key] ?? _placeholder(entry.key),
      ];

  /// Scan results not already linked, named devices first, then strongest.
  List<BleDeviceInfo> get availableDevices {
    final linked = {for (final d in linkedDevices) d.id};
    return [
      for (final d in _scanResults)
        if (!linked.contains(d.id)) d,
    ]..sort((a, b) {
        if (a.hasName != b.hasName) return a.hasName ? -1 : 1;
        return b.rssi.compareTo(a.rssi);
      });
  }

  BluetoothLinkState linkState(String id) =>
      _links[id] ?? BluetoothLinkState.disconnected;

  String? linkError(String id) => _linkErrors[id];

  BleDeviceDetails? details(String id) => _details[id];

  bool isLoadingDetails(String id) => _loadingDetails.contains(id);

  /// Live RSSI while connected, otherwise the last advertisement's RSSI.
  int? rssi(String id) => _liveRssi[id] ?? _known[id]?.rssi;

  /// Devices paired with Android (mostly Bluetooth Classic).
  List<PairedDeviceInfo> get pairedDevices => _paired;
  String? get pairedError => _pairedError;

  // Lifecycle --------------------------------------------------------------

  /// Called when the Bluetooth screen is shown. Checks (but does not
  /// request) permissions, then follows the radio and scans once.
  Future<void> open() async {
    _visible = true;
    if (!_activated) {
      _activated = true;
      _lifecycle = AppLifecycleListener(
        onResume: _onResume,
        onHide: () => stopScan(),
      );
      await _activate();
      return;
    }
    if (isOn) {
      _loadPaired();
      if (!_hasScanned && !_scanning) startScan();
    }
  }

  /// Called when the Bluetooth screen goes away. BLE connections stay up;
  /// scanning stops to save power.
  void close() {
    _visible = false;
    stopScan();
  }

  Future<void> _activate() async {
    try {
      _sdkInt = await _system.sdkInt();
    } catch (_) {
      // Unknown SDK: permissions fall back to the plugin's own prompts.
    }
    bool supported;
    try {
      supported = await _adapter.isSupported();
    } catch (_) {
      supported = false;
    }
    if (!supported) return _setAvailability(BluetoothAvailability.unsupported);
    await _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await _permissions.check(_sdkInt);
    _applyPermission(status);
  }

  void _applyPermission(BluetoothPermissionStatus status) {
    switch (status) {
      case BluetoothPermissionStatus.granted:
        _listenToRadio();
      case BluetoothPermissionStatus.denied:
        _setAvailability(BluetoothAvailability.permissionRequired);
      case BluetoothPermissionStatus.permanentlyDenied:
        _setAvailability(BluetoothAvailability.permissionBlocked);
    }
  }

  void _listenToRadio() {
    if (_radioSub != null) return;
    _scanningSub = _adapter.isScanning().listen(_onScanning);
    _resultsSub = _adapter.scanResults().listen(_onScanResults);
    _systemSub = _system.changes().listen((_) => _loadPaired());
    _radioSub = _adapter.radioState().listen(
          _onRadio,
          onError: (Object _) =>
              _setAvailability(BluetoothAvailability.unsupported),
        );
  }

  void _onRadio(BleRadioState state) {
    final wasOn = isOn;
    switch (state) {
      case BleRadioState.unknown:
        _setAvailability(BluetoothAvailability.checking);
      case BleRadioState.unavailable:
        _setAvailability(BluetoothAvailability.unsupported);
      case BleRadioState.unauthorized:
        _setAvailability(BluetoothAvailability.permissionRequired);
      case BleRadioState.turningOn:
        _setAvailability(BluetoothAvailability.turningOn);
      case BleRadioState.turningOff:
        _setAvailability(BluetoothAvailability.turningOff);
      case BleRadioState.off:
        _clearRadioState();
        _setAvailability(BluetoothAvailability.off);
      case BleRadioState.on:
        _setAvailability(BluetoothAvailability.on);
        if (!wasOn) {
          _loadPaired();
          if (_visible) startScan();
        }
    }
  }

  void _clearRadioState() {
    for (final sub in _linkSubs.values) {
      sub.cancel();
    }
    _linkSubs.clear();
    _links.clear();
    _linkErrors.clear();
    _details.clear();
    _liveRssi.clear();
    _scanResults = const [];
    _hasScanned = false;
    _scanning = false;
    _paired = const [];
    _pairedError = null;
  }

  Future<void> _onResume() async {
    if (_availability == BluetoothAvailability.permissionRequired ||
        _availability == BluetoothAvailability.permissionBlocked) {
      // The user may have granted access in system settings.
      await _checkPermissions();
    } else if (isOn) {
      _loadPaired();
    }
  }

  // Actions ----------------------------------------------------------------

  Future<void> requestPermission() async {
    final status = await _permissions.request(_sdkInt);
    _applyPermission(status);
  }

  Future<void> openAppSettings() async {
    if (!await _permissions.openAppSettings()) {
      _setMessage('Could not open app settings');
    }
  }

  Future<void> openSystemBluetoothSettings() async {
    bool opened;
    try {
      opened = await _system.openBluetoothSettings();
    } catch (_) {
      opened = false;
    }
    if (!opened) _setMessage('Could not open Android Bluetooth settings');
  }

  Future<void> turnOn() async {
    try {
      await _adapter.turnOn();
    } on BleException catch (e) {
      _setMessage(e.message);
    }
  }

  Future<void> startScan() async {
    if (!isOn || _scanning) return;
    _message = null;
    _locationServicesOff = false;
    try {
      await _adapter.startScan(
        timeout: BluetoothConfig.scanTimeout,
        requireLocationServices: _sdkInt != null && _sdkInt! <= 30,
      );
    } on BleException catch (e) {
      _locationServicesOff = e.locationServicesOff;
      _hasScanned = true;
      _setMessage(e.message);
    }
  }

  Future<void> stopScan() async {
    if (!_scanning) return;
    try {
      await _adapter.stopScan();
    } on BleException catch (e) {
      _setMessage(e.message);
    }
  }

  /// Re-scans, re-reads connected devices and reloads paired devices.
  Future<void> refresh() async {
    if (!isOn) return;
    _loadPaired();
    for (final id in _connectedIds) {
      _refreshRssi(id);
    }
    if (_scanning) await stopScan();
    await startScan();
  }

  Future<void> connect(String id) async {
    final state = linkState(id);
    if (state == BluetoothLinkState.connecting ||
        state == BluetoothLinkState.connected) {
      return;
    }
    _links[id] = BluetoothLinkState.connecting;
    _linkErrors.remove(id);
    _notify();

    // Android connects far more reliably when no scan is running.
    await stopScan();
    _watch(id);
    try {
      await _adapter.connect(id, timeout: BluetoothConfig.connectTimeout);
      if (linkState(id) == BluetoothLinkState.connecting) {
        _links[id] = BluetoothLinkState.connected;
        _notify();
      }
      _loadDetails(id);
    } on BleException catch (e) {
      _unwatch(id);
      if (linkState(id) == BluetoothLinkState.disconnecting) {
        _links[id] = BluetoothLinkState.disconnected;
      } else {
        _links[id] = BluetoothLinkState.failed;
        _linkErrors[id] = e.message;
      }
      _notify();
    }
  }

  /// Disconnects, or cancels a connection attempt in progress.
  Future<void> disconnect(String id) async {
    final state = linkState(id);
    if (state != BluetoothLinkState.connected &&
        state != BluetoothLinkState.connecting) {
      return;
    }
    _links[id] = BluetoothLinkState.disconnecting;
    _notify();
    try {
      await _adapter.disconnect(id);
    } on BleException catch (e) {
      _setMessage(e.message);
    }
    _unwatch(id);
    _links[id] = BluetoothLinkState.disconnected;
    _details.remove(id);
    _liveRssi.remove(id);
    _notify();
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    _notify();
  }

  // Internals --------------------------------------------------------------

  Iterable<String> get _connectedIds => _links.entries
      .where((e) => e.value == BluetoothLinkState.connected)
      .map((e) => e.key);

  void _onScanning(bool scanning) {
    if (_scanning && !scanning) _hasScanned = true;
    _scanning = scanning;
    _notify();
  }

  void _onScanResults(List<BleDeviceInfo> results) {
    _scanResults = results;
    for (final d in results) {
      _known[d.id] = d;
    }
    _notify();
  }

  /// Follows the real link state so drops (device out of range, powered
  /// off) show up immediately.
  void _watch(String id) {
    _linkSubs[id] ??= _adapter.connectionState(id).listen((connected) {
      final state = linkState(id);
      if (connected && state == BluetoothLinkState.connecting) {
        _links[id] = BluetoothLinkState.connected;
        _loadDetails(id);
        _notify();
      } else if (!connected && state == BluetoothLinkState.connected) {
        _unwatch(id);
        _links[id] = BluetoothLinkState.disconnected;
        _details.remove(id);
        _liveRssi.remove(id);
        _setMessage('${_known[id]?.displayName ?? id} disconnected');
      }
    });
  }

  void _unwatch(String id) => _linkSubs.remove(id)?.cancel();

  Future<void> _loadDetails(String id) async {
    if (_details.containsKey(id) || !_loadingDetails.add(id)) return;
    _notify();
    try {
      final details = await _adapter.readDetails(id);
      if (linkState(id) == BluetoothLinkState.connected) _details[id] = details;
    } on BleException {
      // Shown as "no device information" in the card.
    } finally {
      _loadingDetails.remove(id);
      _notify();
    }
    await _refreshRssi(id);
  }

  Future<void> _refreshRssi(String id) async {
    final value = await _adapter.readRssi(id);
    if (value == null || linkState(id) != BluetoothLinkState.connected) return;
    _liveRssi[id] = value;
    _notify();
  }

  Future<void> _loadPaired() async {
    if (!isOn) return;
    try {
      _paired = await _system.pairedDevices();
      _pairedError = null;
    } on BluetoothSystemException catch (e) {
      _paired = const [];
      _pairedError = e.message;
    } catch (_) {
      _paired = const [];
      _pairedError = 'Could not read paired devices';
    }
    _notify();
  }

  BleDeviceInfo _placeholder(String id) => BleDeviceInfo(
        id: id,
        name: null,
        rssi: 0,
        connectable: true,
        lastSeen: DateTime.now(),
      );

  void _setAvailability(BluetoothAvailability value) {
    if (_availability == value) return;
    _availability = value;
    _notify();
  }

  void _setMessage(String value) {
    _message = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final id in _connectedIds.toList()) {
      _adapter.disconnect(id).ignore();
    }
    if (_scanning) _adapter.stopScan().ignore();
    for (final sub in _linkSubs.values) {
      sub.cancel();
    }
    _radioSub?.cancel();
    _scanningSub?.cancel();
    _resultsSub?.cancel();
    _systemSub?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }
}
