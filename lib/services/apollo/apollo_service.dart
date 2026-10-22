import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/apollo_state.dart';
import 'apollo_config.dart';

enum GatewayConnection { disconnected, connecting, connected }

/// Nearest lane-centre point to a tap on the map.
class LaneSnap {
  const LaneSnap(this.point, this.heading, this.distance);

  final Offset point;

  /// Direction the lane runs there (radians, CCW from east).
  final double heading;

  /// How far the tap was from the lane, in metres.
  final double distance;

  /// Close enough for the gateway to accept as a destination.
  bool get onRoad => distance <= 8;
}

/// The tablet's link to Apollo, through the KAIRO gateway.
///
/// Live state streams in over the gateway's `/ws` (about 5 updates/second);
/// commands go out as REST calls. Every command returns an error message, or
/// null on success, and also records it in [lastError] for the UI.
///
/// Owned by the dashboard shell so the connection survives page changes.
class ApolloService extends ChangeNotifier {
  ApolloService({
    http.Client? client,
    @visibleForTesting SharedPreferences? prefs,
  })  : _http = client ?? http.Client(),
        _prefs = prefs;

  static const _urlKey = 'kairo_gateway_url';
  static const _cruiseKey = 'kairo_cruise_kph';

  final http.Client _http;
  SharedPreferences? _prefs;

  String _gatewayUrl = ApolloConfig.defaultGatewayUrl;
  double _cruiseKph = ApolloConfig.defaultCruiseKph;
  GatewayConnection _connection = GatewayConnection.disconnected;
  ApolloState? _state;
  HdMap? _hdMap;
  bool _loadingMap = false;
  String? _mapError;
  String? _connectionError;
  String? _lastError;
  final Set<String> _pending = {};

  /// Route polyline for [_routeRev]. The live stream only carries the
  /// revision; the points are fetched once per route from /api/route.
  List<Offset> _route = const [];
  int? _routeRev;
  bool _fetchingRoute = false;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _reconnectTimer;
  Duration _backoff = const Duration(seconds: 1);
  bool _disposed = false;

  String get gatewayUrl => _gatewayUrl;
  double get cruiseKph => _cruiseKph;
  GatewayConnection get connection => _connection;
  ApolloState? get state => _state;
  HdMap? get hdMap => _hdMap;
  bool get loadingMap => _loadingMap;
  String? get mapError => _mapError;
  String? get connectionError => _connectionError;
  String? get lastError => _lastError;

  /// True while a command named [name] (e.g. 'go', 'stop') is in flight.
  bool isPending(String name) => _pending.contains(name);

  /// Gateway reachable and Apollo's Cyber RT answering.
  bool get isLive =>
      _connection == GatewayConnection.connected &&
      (_state?.cyberConnected ?? false);

  /// Live, with a vehicle pose: destinations can be sent.
  bool get canDrive =>
      isLive &&
      _state!.autopilot.phase != AutopilotPhase.unavailable &&
      _state!.autopilot.phase != AutopilotPhase.offline;

  /// Dreamview Plus' web UI, on the same host as the gateway.
  Uri get dreamviewUri {
    final base = Uri.parse(_gatewayUrl);
    return Uri(
      scheme: 'http',
      host: base.host,
      port: _state?.dreamviewPort ?? 8888,
    );
  }

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _gatewayUrl = _prefs!.getString(_urlKey) ?? _gatewayUrl;
    _cruiseKph = _prefs!.getDouble(_cruiseKey) ?? _cruiseKph;
    _connect();
  }

  Future<void> setGatewayUrl(String url) async {
    var cleaned = url.trim();
    if (cleaned.isEmpty) return;
    if (!cleaned.contains('://')) cleaned = 'http://$cleaned';
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    _gatewayUrl = cleaned;
    await _prefs?.setString(_urlKey, cleaned);
    _hdMap = null;
    _state = null;
    reconnect();
  }

  Future<void> setCruiseKph(double kph) async {
    _cruiseKph =
        kph.clamp(ApolloConfig.minCruiseKph, ApolloConfig.maxCruiseKph);
    notifyListeners();
    await _prefs?.setDouble(_cruiseKey, _cruiseKph);
  }

  // ---------------------------------------------------------------------------
  // Live connection
  // ---------------------------------------------------------------------------

  void reconnect() {
    _backoff = const Duration(seconds: 1);
    _closeSocket();
    _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _connection = GatewayConnection.connecting;
    notifyListeners();

    final wsUri = Uri.parse(_gatewayUrl).replace(
      scheme: _gatewayUrl.startsWith('https') ? 'wss' : 'ws',
      path: '/ws',
    );
    try {
      final socket = await WebSocket.connect(wsUri.toString())
          .timeout(const Duration(seconds: 5));
      if (_disposed) {
        socket.close();
        return;
      }
      _socket = socket;
      _connectionError = null;
      _backoff = const Duration(seconds: 1);
      _socketSub = socket.listen(
        _onMessage,
        onDone: () => _onDisconnected('Gateway closed the connection'),
        onError: (Object e) => _onDisconnected('$e'),
        cancelOnError: true,
      );
    } catch (e) {
      _onDisconnected('Cannot reach the gateway at $_gatewayUrl');
    }
  }

  void _onMessage(dynamic data) {
    if (data is! String) return;
    try {
      _setState(ApolloState.fromJson(jsonDecode(data) as Map<String, dynamic>));
    } catch (e) {
      debugPrint('ApolloService: bad state payload: $e');
      return;
    }
    _connection = GatewayConnection.connected;
    final map = _state!.dreamview.map;
    if (_state!.cyberConnected &&
        !_loadingMap &&
        (_hdMap == null || _hdMap!.hmiMap != map) &&
        _mapError == null) {
      loadMap();
    }
    notifyListeners();
  }

  /// Adopts a new state, carrying the cached route polyline over (or
  /// fetching it when the route changed).
  void _setState(ApolloState next) {
    final rev = next.scene.routeRev;
    if (next.scene.route.isNotEmpty) {
      _route = next.scene.route;
      _routeRev = rev;
    } else if (rev == null) {
      _route = const [];
      _routeRev = null;
    } else if (rev == _routeRev) {
      next = next.withRoute(_route);
    } else {
      _fetchRoute(rev);
    }
    _state = next;
  }

  Future<void> _fetchRoute(int rev) async {
    if (_fetchingRoute) return;
    _fetchingRoute = true;
    try {
      final response = await _http
          .get(Uri.parse('$_gatewayUrl/api/route'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _routeRev = (json['rev'] as num?)?.toInt();
      _route = [
        for (final p in (json['route'] as List? ?? const []))
          Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];
      if (_state != null && _state!.scene.routeRev == _routeRev) {
        _state = _state!.withRoute(_route);
        if (!_disposed) notifyListeners();
      }
    } catch (e) {
      debugPrint('ApolloService: route fetch failed: $e');
    } finally {
      _fetchingRoute = false;
    }
  }

  void _onDisconnected(String reason) {
    _closeSocket();
    if (_disposed) return;
    _connection = GatewayConnection.disconnected;
    _connectionError = reason;
    notifyListeners();
    _reconnectTimer = Timer(_backoff, _connect);
    _backoff = Duration(
      seconds: (_backoff.inSeconds * 2).clamp(1, 10),
    );
  }

  void _closeSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.close();
    _socket = null;
  }

  /// Fetches the lane geometry of the map Dreamview currently has loaded.
  Future<void> loadMap() async {
    _loadingMap = true;
    _mapError = null;
    notifyListeners();
    try {
      final response = await _http
          .get(Uri.parse('$_gatewayUrl/api/map'))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw Exception(_detail(response));
      }
      _hdMap = HdMap.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      _mapError = 'Could not load the HD map: $e';
      // Retry later instead of hammering the gateway on every state push.
      Timer(const Duration(seconds: 10), () {
        _mapError = null;
      });
    } finally {
      _loadingMap = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  /// Route to [x],[y] on the HD map and drive there.
  Future<String?> go(double x, double y, {String? name, double? heading}) =>
      _post('go', '/api/autopilot/go', {
        'x': x,
        'y': y,
        if (name != null) 'name': name,
        if (heading != null) 'heading': heading,
        'target_speed_kph': _cruiseKph,
      });

  Future<String?> goToPlace(ApolloPlace place) =>
      go(place.x, place.y, name: place.label, heading: place.heading);

  Future<String?> stop() => _post('stop', '/api/autopilot/stop');
  Future<String?> pullOver() => _post('pull_over', '/api/autopilot/pull_over');
  Future<String?> resume() => _post('resume', '/api/autopilot/resume');
  Future<String?> cancelRoute() => _post('cancel', '/api/autopilot/cancel');
  Future<String?> changeLane({required bool left}) => _post(
        'lane_change',
        '/api/autopilot/lane_change/${left ? 'left' : 'right'}',
      );

  Future<String?> setSimControl(bool enabled) => _post(
        'sim_control',
        '/api/dreamview/sim_control',
        {'enabled': enabled},
      );

  Future<String?> changeMap(String name) async {
    final error = await _post('map', '/api/dreamview/map', {'name': name});
    if (error == null) _hdMap = null;
    return error;
  }

  Future<String?> changeMode(String name) =>
      _post('mode', '/api/dreamview/mode', {'name': name});

  Future<String?> setModule(String name, {required bool running}) => _post(
        'module:$name',
        '/api/dreamview/modules/${Uri.encodeComponent(name)}',
        {'running': running},
      );

  Future<String?> setupAllModules() => _post('setup', '/api/dreamview/setup');
  Future<String?> resetAllModules() =>
      _post('reset_mode', '/api/dreamview/reset_mode');

  /// Teleports the simulated car (Sim Control only). With no point, Dreamview
  /// picks the map's default start point.
  Future<String?> setStartPoint({double? x, double? y, double? heading}) =>
      _post('start_point', '/api/dreamview/start_point', {
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (heading != null) 'heading': heading,
      });

  Future<String?> savePlace(String id, String label, double x, double y,
          {double? heading}) =>
      _send('save_place', 'PUT', '/api/places/${Uri.encodeComponent(id)}', {
        'label': label,
        'x': x,
        'y': y,
        if (heading != null) 'heading': heading,
      });

  Future<String?> deletePlace(String id) =>
      _send('delete_place', 'DELETE', '/api/places/${Uri.encodeComponent(id)}');

  // ---- manual driving --------------------------------------------------------

  /// Hand the car to the tablet's pedals (true) or back to Apollo (false).
  Future<String?> setManual(bool enabled) =>
      _post('manual', '/api/drive/manual', {'enabled': enabled});

  /// P, R, N or D. Shifting out of D while Apollo drives takes over.
  Future<String?> setGear(String gear) =>
      _post('gear', '/api/drive/gear', {'gear': gear});

  /// Pedals and wheel, each 0..1 (steer -1..1, + = left). Call ~20 times a
  /// second while driving; if inputs stop, the car brakes by itself.
  void sendDrive({double throttle = 0, double brake = 0, double steer = 0}) {
    final socket = _socket;
    if (socket == null || !(_state?.drive.manual ?? false)) return;
    socket.add('{"type":"drive","throttle":${throttle.toStringAsFixed(3)},'
        '"brake":${brake.toStringAsFixed(3)},"steer":${steer.toStringAsFixed(3)}}');
  }

  // ---- body controls ---------------------------------------------------------

  /// Updates body controls (locks, lights, ...). Applied to the UI at once;
  /// the gateway's answer (or refusal) follows.
  Future<String?> setBody(Map<String, dynamic> patch) async {
    final before = _state;
    if (before != null) {
      _state = before.withBody(before.body.merged(patch));
      notifyListeners();
    }
    final error = await _post('body', '/api/body', patch);
    if (error != null && before != null && _state != null) {
      // Refused (e.g. frunk while moving): undo the optimistic change.
      _state = _state!.withBody(before.body);
      notifyListeners();
    }
    return error;
  }

  Future<String?> honk() => _post('horn', '/api/body/horn');

  /// The lane point a tap at [x],[y] would drive to; null when nothing is
  /// nearby or the gateway can't be reached.
  Future<LaneSnap?> snap(double x, double y) async {
    try {
      final response = await _http
          .get(Uri.parse('$_gatewayUrl/api/snap?x=$x&y=$y'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is! Map || json['x'] == null) return null;
      return LaneSnap(
        Offset((json['x'] as num).toDouble(), (json['y'] as num).toDouble()),
        (json['heading'] as num).toDouble(),
        (json['distance'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Puts the service in the connected state without a socket, for tests.
  @visibleForTesting
  void debugSetLive(ApolloState state, {HdMap? map}) {
    _connection = GatewayConnection.connected;
    _state = state;
    _hdMap = map ?? _hdMap;
    notifyListeners();
  }

  /// Feeds one raw /ws message to the service, for tests.
  @visibleForTesting
  void debugReceive(String message) => _onMessage(message);

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  Future<String?> _post(String name, String path,
          [Map<String, dynamic>? body]) =>
      _send(name, 'POST', path, body);

  Future<String?> _send(String name, String method, String path,
      [Map<String, dynamic>? body]) async {
    _pending.add(name);
    _lastError = null;
    notifyListeners();
    try {
      final request = http.Request(method, Uri.parse('$_gatewayUrl$path'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body ?? const {});
      final response = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 20)),
      );
      if (response.statusCode >= 400) {
        return _lastError = _detail(response);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['state'] is Map) {
        _setState(ApolloState.fromJson(
          (decoded['state'] as Map).cast<String, dynamic>(),
        ));
      }
      return null;
    } on TimeoutException {
      return _lastError = 'The gateway did not answer in time';
    } catch (e) {
      return _lastError = 'Cannot reach the gateway: $e';
    } finally {
      _pending.remove(name);
      if (!_disposed) notifyListeners();
    }
  }

  static String _detail(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'];
        return detail is String ? detail : jsonEncode(detail);
      }
    } catch (_) {}
    return 'Gateway error ${response.statusCode}';
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _closeSocket();
    _http.close();
    super.dispose();
  }
}
