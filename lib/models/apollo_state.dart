import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Typed view of the gateway's `/api/state` payload (pushed over `/ws`).
/// Apollo world coordinates are metres in the HD map frame: x east, y north.
class ApolloState {
  const ApolloState({
    required this.cyberConnected,
    required this.cyberError,
    required this.dreamviewConnected,
    required this.dreamviewError,
    required this.dreamviewPort,
    required this.channels,
    required this.vehicle,
    required this.autopilot,
    required this.dreamview,
    required this.scene,
    required this.places,
    this.drive = const DriveStatus(),
    this.body = const BodyState(),
    this.raw = const {},
  });

  final bool cyberConnected;
  final String? cyberError;
  final bool dreamviewConnected;
  final String? dreamviewError;
  final int dreamviewPort;

  /// Freshness of each Cyber channel the gateway listens to.
  final Map<String, bool> channels;
  final VehicleTelemetry vehicle;
  final AutopilotStatus autopilot;
  final DreamviewStatus dreamview;
  final SceneData scene;

  /// Saved destinations on the current HD map, keyed by id ('home', ...).
  final Map<String, ApolloPlace> places;

  /// Who drives: Apollo (auto) or the tablet's pedals (manual).
  final DriveStatus drive;

  /// Locks, closures, lights, signals and comfort controls.
  final BodyState body;

  /// The decoded state message as received. Feature code reads blocks
  /// that have no typed model here (e.g. raw['safety'], raw['hazards'],
  /// raw['traffic'] - see docs/validation_api.md in the Kairo repo).
  final Map<String, dynamic> raw;

  /// The same state with the route polyline filled in (the live stream
  /// leaves it out; it's fetched separately when [SceneData.routeRev]
  /// changes).
  ApolloState withRoute(List<Offset> route) => ApolloState(
        cyberConnected: cyberConnected,
        cyberError: cyberError,
        dreamviewConnected: dreamviewConnected,
        dreamviewError: dreamviewError,
        dreamviewPort: dreamviewPort,
        channels: channels,
        vehicle: vehicle,
        autopilot: autopilot,
        dreamview: dreamview,
        scene: scene.withRoute(route),
        places: places,
        drive: drive,
        body: body,
        raw: raw,
      );

  /// Same state with [body] replaced (optimistic UI updates).
  ApolloState withBody(BodyState body) => ApolloState(
        cyberConnected: cyberConnected,
        cyberError: cyberError,
        dreamviewConnected: dreamviewConnected,
        dreamviewError: dreamviewError,
        dreamviewPort: dreamviewPort,
        channels: channels,
        vehicle: vehicle,
        autopilot: autopilot,
        dreamview: dreamview,
        scene: scene,
        places: places,
        drive: drive,
        body: body,
        raw: raw,
      );

  factory ApolloState.fromJson(Map<String, dynamic> json) {
    final gateway = _map(json['gateway']);
    return ApolloState(
      cyberConnected: gateway['cyber_connected'] == true,
      cyberError: gateway['cyber_error'] as String?,
      dreamviewConnected: gateway['dreamview_connected'] == true,
      dreamviewError: gateway['dreamview_error'] as String?,
      dreamviewPort: (gateway['dreamview_port'] as num?)?.toInt() ?? 8888,
      channels: _map(gateway['channels']).map((k, v) => MapEntry(k, v == true)),
      vehicle: VehicleTelemetry.fromJson(_map(json['vehicle'])),
      autopilot: AutopilotStatus.fromJson(_map(json['autopilot'])),
      dreamview: DreamviewStatus.fromJson(_map(json['dreamview'])),
      scene: SceneData.fromJson(_map(json['scene'])),
      places: _map(json['places']).map(
        (id, v) => MapEntry(id, ApolloPlace.fromJson(_map(v), id: id)),
      ),
      drive: DriveStatus.fromJson(_map(json['drive'])),
      body: BodyState(_map(json['body'])),
      raw: json,
    );
  }
}

class DriveStatus {
  const DriveStatus({this.manual = false, this.gear, this.deadman = false});

  /// The tablet drives (KAIRO virtual vehicle) instead of Apollo.
  final bool manual;

  /// 'P', 'R', 'N' or 'D'.
  final String? gear;

  /// Manual inputs stopped arriving and the car is braking on its own.
  final bool deadman;

  factory DriveStatus.fromJson(Map<String, dynamic> json) => DriveStatus(
        manual: json['mode'] == 'MANUAL',
        gear: json['gear'] as String?,
        deadman: json['deadman'] == true,
      );

  @override
  bool operator ==(Object other) =>
      other is DriveStatus &&
      other.manual == manual &&
      other.gear == gear &&
      other.deadman == deadman;

  @override
  int get hashCode => Object.hash(manual, gear, deadman);
}

/// The body controller's state, as sent by the gateway (see
/// kairo_gateway/vehicle_body.py for the field list and rules).
class BodyState {
  const BodyState([this.values = const {}]);

  final Map<String, dynamic> values;

  bool flag(String key) => values[key] == true;

  bool get locked => flag('locked');
  bool get frunkOpen => flag('frunk_open');
  bool get trunkOpen => flag('trunk_open');
  bool get chargePortOpen => flag('charge_port_open');
  bool get gloveboxOpen => flag('glovebox_open');

  /// OFF, PARKING, ON or AUTO.
  String get lights => values['lights'] as String? ?? 'AUTO';
  bool get highBeam => flag('high_beam');
  bool get hazards => flag('hazards');

  /// NONE, LEFT or RIGHT.
  String get turnSignal => values['turn_signal'] as String? ?? 'NONE';
  bool get horn => flag('horn');
  bool get mirrorsFolded => flag('mirrors_folded');
  bool get childLock => flag('child_lock');
  bool get windowLock => flag('window_lock');
  bool get sentry => flag('sentry');
  bool get dashcam => flag('dashcam');
  bool get carWash => flag('car_wash');
  bool get neutralTow => flag('neutral_tow');
  bool get climateOn => flag('climate_on');
  double get cabinTempC => (values['cabin_temp_c'] as num?)?.toDouble() ?? 22;

  bool get isKnown => values.isNotEmpty;

  BodyState merged(Map<String, dynamic> patch) =>
      BodyState({...values, ...patch});

  @override
  bool operator ==(Object other) =>
      other is BodyState && mapEquals(other.values, values);

  @override
  int get hashCode => Object.hashAll(values.entries.map((e) => e.value));
}

class VehicleTelemetry {
  const VehicleTelemetry({
    required this.speedKph,
    this.gear,
    this.batteryPct,
    this.drivingMode,
    this.throttlePct,
    this.brakePct,
    this.steeringPct,
    this.pose,
  });

  final double speedKph;

  /// 'P', 'R', 'N' or 'D'; null when the chassis doesn't report it.
  final String? gear;
  final int? batteryPct;
  final String? drivingMode;
  final double? throttlePct;
  final double? brakePct;
  final double? steeringPct;
  final ApolloPose? pose;

  bool get autoDriveMode => drivingMode == 'COMPLETE_AUTO_DRIVE';

  factory VehicleTelemetry.fromJson(Map<String, dynamic> json) {
    final pose = json['pose'];
    return VehicleTelemetry(
      speedKph: _double(json['speed_kph']) ?? 0,
      gear: json['gear'] as String?,
      batteryPct: (json['battery_pct'] as num?)?.toInt(),
      drivingMode: json['driving_mode'] as String?,
      throttlePct: _double(json['throttle_pct']),
      brakePct: _double(json['brake_pct']),
      steeringPct: _double(json['steering_pct']),
      pose: pose is Map ? ApolloPose.fromJson(_map(pose)) : null,
    );
  }
}

class ApolloPose {
  const ApolloPose(this.x, this.y, this.heading);

  final double x;
  final double y;

  /// Radians, counter-clockwise from east.
  final double heading;

  Offset get offset => Offset(x, y);

  factory ApolloPose.fromJson(Map<String, dynamic> json) => ApolloPose(
        _double(json['x']) ?? 0,
        _double(json['y']) ?? 0,
        _double(json['heading']) ?? 0,
      );
}

enum AutopilotPhase {
  /// Gateway can't reach the Apollo container.
  offline,

  /// Apollo is up but there is no vehicle pose (no sim control / bridge).
  unavailable,
  ready,
  driving,
  stopping,
  stopped,
  estop,
  arrived,
  error,

  /// The driver is driving with the tablet's pedals.
  manual;

  static AutopilotPhase parse(String? value) => switch (value) {
        'OFFLINE' => offline,
        'UNAVAILABLE' => unavailable,
        'READY' => ready,
        'DRIVING' => driving,
        'STOPPING' => stopping,
        'STOPPED' => stopped,
        'ESTOP' => estop,
        'ARRIVED' => arrived,
        'ERROR' => error,
        'MANUAL' => manual,
        _ => offline,
      };
}

class AutopilotStatus {
  const AutopilotStatus({
    required this.phase,
    required this.engaged,
    this.message,
    this.destination,
    this.remainingM,
    this.etaS,
    this.routeDistanceM,
    this.targetSpeedKph,
    this.decision,
  });

  final AutopilotPhase phase;
  final bool engaged;
  final String? message;
  final ApolloPlace? destination;
  final double? remainingM;
  final double? etaS;
  final double? routeDistanceM;
  final double? targetSpeedKph;

  /// Planning's main decision: cruise, stop, estop, mission_complete, ...
  final String? decision;

  bool get hasRoute => destination != null;

  factory AutopilotStatus.fromJson(Map<String, dynamic> json) {
    final dest = json['destination'];
    return AutopilotStatus(
      phase: AutopilotPhase.parse(json['state'] as String?),
      engaged: json['engaged'] == true,
      message: json['message'] as String?,
      destination: dest is Map ? ApolloPlace.fromJson(_map(dest)) : null,
      remainingM: _double(json['remaining_m']),
      etaS: _double(json['eta_s']),
      routeDistanceM: _double(json['route_distance_m']),
      targetSpeedKph: _double(json['target_speed_kph']),
      decision: json['decision'] as String?,
    );
  }
}

class DreamviewStatus {
  const DreamviewStatus({
    this.mode,
    this.modes = const [],
    this.map,
    this.maps = const [],
    this.vehicle,
    this.operation,
    this.operations = const [],
    this.simControl = false,
    this.modules = const {},
    this.components = const {},
  });

  final String? mode;
  final List<String> modes;
  final String? map;
  final List<String> maps;
  final String? vehicle;
  final String? operation;
  final List<String> operations;
  final bool simControl;

  /// Dreamview module name -> running.
  final Map<String, bool> modules;

  /// Monitored component name -> status (OK, WARN, ERROR, FATAL, UNKNOWN).
  final Map<String, String> components;

  bool get canSimControl => operations.contains('Sim_Control');

  factory DreamviewStatus.fromJson(Map<String, dynamic> json) =>
      DreamviewStatus(
        mode: json['mode'] as String?,
        modes: _strings(json['modes']),
        map: json['map'] as String?,
        maps: _strings(json['maps']),
        vehicle: json['vehicle'] as String?,
        operation: json['operation'] as String?,
        operations: _strings(json['operations']),
        simControl: json['sim_control'] == true,
        modules: _map(json['modules']).map((k, v) => MapEntry(k, v == true)),
        components: _map(json['components']).map(
          (k, v) => MapEntry(k, (_map(v)['status'] as String?) ?? 'UNKNOWN'),
        ),
      );
}

class SceneData {
  const SceneData({
    this.trajectory = const [],
    this.route = const [],
    this.routeRev,
    this.obstacles = const [],
  });

  /// Planning's current trajectory (next few seconds).
  final List<Offset> trajectory;

  /// Full lane-level route to the destination.
  final List<Offset> route;

  /// Identifies the current route; null when there is none.
  final int? routeRev;
  final List<ApolloObstacle> obstacles;

  SceneData withRoute(List<Offset> route) => SceneData(
        trajectory: trajectory,
        route: route,
        routeRev: routeRev,
        obstacles: obstacles,
      );

  factory SceneData.fromJson(Map<String, dynamic> json) => SceneData(
        trajectory: _points(json['trajectory']),
        route: _points(json['route']),
        routeRev: (json['route_rev'] as num?)?.toInt(),
        obstacles: [
          for (final o in (json['obstacles'] as List? ?? const []))
            ApolloObstacle.fromJson(_map(o)),
        ],
      );
}

class ApolloObstacle {
  const ApolloObstacle({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.heading,
    required this.length,
    required this.width,
  });

  final int id;
  final String type;
  final double x;
  final double y;
  final double heading;
  final double length;
  final double width;

  factory ApolloObstacle.fromJson(Map<String, dynamic> json) => ApolloObstacle(
        id: (json['id'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? 'UNKNOWN',
        x: _double(json['x']) ?? 0,
        y: _double(json['y']) ?? 0,
        heading: _double(json['heading']) ?? 0,
        length: _double(json['length']) ?? 4,
        width: _double(json['width']) ?? 2,
      );
}

/// A named point on the HD map (saved place or active destination).
class ApolloPlace {
  const ApolloPlace({
    this.id,
    required this.label,
    required this.x,
    required this.y,
    this.heading,
  });

  final String? id;
  final String label;
  final double x;
  final double y;
  final double? heading;

  Offset get offset => Offset(x, y);

  factory ApolloPlace.fromJson(Map<String, dynamic> json, {String? id}) =>
      ApolloPlace(
        id: id,
        label: (json['label'] ?? json['name'] ?? 'Destination') as String,
        x: _double(json['x']) ?? 0,
        y: _double(json['y']) ?? 0,
        heading: _double(json['heading']),
      );
}

/// Lane centerlines of the loaded HD map, from `/api/map`.
class HdMap {
  HdMap({
    required this.name,
    required this.hmiMap,
    required this.bounds,
    required this.lanes,
  });

  /// Map directory name, e.g. carla_town05.
  final String name;

  /// Dreamview's display name for the same map, e.g. "Carla Town05".
  final String? hmiMap;
  final Rect bounds;
  final List<HdLane> lanes;

  factory HdMap.fromJson(Map<String, dynamic> json) {
    final b = _map(json['bounds']);
    return HdMap(
      name: json['name'] as String? ?? '',
      hmiMap: json['hmi_map'] as String?,
      bounds: Rect.fromLTRB(
        _double(b['min_x']) ?? 0,
        _double(b['min_y']) ?? 0,
        _double(b['max_x']) ?? 0,
        _double(b['max_y']) ?? 0,
      ),
      lanes: [
        for (final l in (json['lanes'] as List? ?? const []))
          HdLane(
            width: _double(_map(l)['w']) ?? 3.5,
            points: _points(_map(l)['pts']),
          ),
      ],
    );
  }
}

class HdLane {
  const HdLane({required this.width, required this.points});

  final double width;
  final List<Offset> points;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

double? _double(Object? value) => value is num ? value.toDouble() : null;

List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

List<Offset> _points(Object? value) {
  if (value is! List) return const [];
  return [
    for (final p in value)
      if (p is List && p.length >= 2)
        Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
  ];
}
