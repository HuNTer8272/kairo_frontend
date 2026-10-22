import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/apollo_state.dart';

/// Camera for [ApolloMapView]: what part of the HD map is on screen.
class ApolloMapController extends ChangeNotifier {
  Offset? _center;
  double _scale = 3.5; // pixels per metre
  bool _follow = true;

  static const double minScale = 0.25;
  static const double maxScale = 14;

  /// Map centre in world metres; null until the view has fitted the map.
  Offset? get center => _center;
  double get scale => _scale;

  /// Keep the vehicle centred while it drives.
  bool get follow => _follow;

  void zoomBy(double factor) {
    _scale = (_scale * factor).clamp(minScale, maxScale);
    notifyListeners();
  }

  void recenter() {
    _follow = true;
    if (_scale < 2.5) _scale = 3.5;
    notifyListeners();
  }

  void _pan(Offset worldDelta) {
    if (_center == null) return;
    _center = _center! + worldDelta;
    _follow = false;
    notifyListeners();
  }

  void _setScale(double scale) {
    _scale = scale.clamp(minScale, maxScale);
    notifyListeners();
  }

  void _fit(Rect bounds, Size size) {
    _center = bounds.center;
    final sx = size.width / math.max(bounds.width, 1);
    final sy = size.height / math.max(bounds.height, 1);
    _scale = (math.min(sx, sy) * 0.9).clamp(minScale, maxScale);
  }
}

/// Top-down render of Apollo's HD map with the live scene on top: the
/// route, planning's trajectory, perceived obstacles and the ego vehicle.
/// Tapping the map reports the world point (metres) via [onTapWorld].
class ApolloMapView extends StatefulWidget {
  const ApolloMapView({
    super.key,
    required this.map,
    required this.controller,
    this.state,
    this.pin,
    this.onTapWorld,
    this.dark = false,
  });

  final HdMap map;
  final ApolloMapController controller;
  final ApolloState? state;

  /// A dropped pin awaiting confirmation (world metres).
  final Offset? pin;
  final ValueChanged<Offset>? onTapWorld;
  final bool dark;

  @override
  State<ApolloMapView> createState() => _ApolloMapViewState();
}

class _ApolloMapViewState extends State<ApolloMapView> {
  _RoadLayer? _roads;
  double _scaleAtGestureStart = 1;

  _Palette get _palette => widget.dark ? _Palette.dark : _Palette.light;

  @override
  void didUpdateWidget(ApolloMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.map, widget.map)) {
      _roads?.dispose();
      _roads = null;
      widget.controller._center = null;
    } else if (oldWidget.dark != widget.dark) {
      _rasterize();
    }
  }

  @override
  void dispose() {
    _roads?.dispose();
    super.dispose();
  }

  _RoadLayer get _roadLayer {
    if (_roads == null) {
      _roads = _RoadLayer.build(widget.map);
      _rasterize();
    }
    return _roads!;
  }

  /// Renders the whole road network into an image once (off the paint
  /// path); until it's ready, or when zoomed in past its resolution, the
  /// painter draws only the on-screen tiles as vectors.
  Future<void> _rasterize() async {
    final roads = _roads;
    if (roads == null) return;
    await roads.rasterize(_palette);
    if (mounted && identical(roads, _roads)) setState(() {});
  }

  Offset _toWorld(Offset local, Size size, Offset center, double scale) {
    final d = local - size.center(Offset.zero);
    return Offset(center.dx + d.dx / scale, center.dy - d.dy / scale);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final controller = widget.controller;
      if (controller._center == null) {
        controller._fit(widget.map.bounds, size);
        final pose = widget.state?.vehicle.pose;
        if (pose != null) {
          controller._center = pose.offset;
          controller._scale = 3.5;
        }
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (_) => _scaleAtGestureStart = controller.scale,
        onScaleUpdate: (details) {
          if (details.pointerCount > 1) {
            controller._setScale(_scaleAtGestureStart * details.scale);
          }
          final s = controller.scale;
          controller._pan(Offset(
            -details.focalPointDelta.dx / s,
            details.focalPointDelta.dy / s,
          ));
        },
        onTapUp: widget.onTapWorld == null
            ? null
            : (details) {
                final center = _effectiveCenter(controller);
                widget.onTapWorld!(_toWorld(
                    details.localPosition, size, center, controller.scale));
              },
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => CustomPaint(
            size: size,
            painter: _ScenePainter(
              roads: _roadLayer,
              state: widget.state,
              pin: widget.pin,
              center: _effectiveCenter(controller),
              scale: controller.scale,
              palette: _palette,
            ),
          ),
        ),
      );
    });
  }

  Offset _effectiveCenter(ApolloMapController controller) {
    final pose = widget.state?.vehicle.pose;
    if (controller.follow && pose != null) {
      controller._center = pose.offset;
    }
    return controller._center ?? widget.map.bounds.center;
  }
}

/// The HD map's roads, prepared for cheap repeated drawing:
/// - an image of the whole network (one drawImageRect per frame), used at
///   the zoom levels it has enough resolution for;
/// - lane paths bucketed into square tiles, so zoomed-in views stroke only
///   the tiles on screen instead of every lane in town.
class _RoadLayer {
  _RoadLayer._(this.tiles, this.bounds);

  static const double tileSize = 80; // metres
  static const double maxImagePixels = 4096;
  static const double maxImageScale = 3; // px per metre

  final Map<(int, int), _Tile> tiles;
  final Rect bounds;

  ui.Image? image;
  double imageScale = 0;
  _Palette? imagePalette;

  factory _RoadLayer.build(HdMap map) {
    final tiles = <(int, int), _Tile>{};
    var bounds = Rect.zero;
    var first = true;
    for (final lane in map.lanes) {
      if (lane.points.length < 2) continue;
      var box = Rect.fromPoints(lane.points.first, lane.points.first);
      for (final p in lane.points) {
        box = box.expandToInclude(Rect.fromPoints(p, p));
      }
      box = box.inflate(lane.width);
      bounds = first ? box : bounds.expandToInclude(box);
      first = false;
      final key = (
        (box.center.dx / tileSize).floor(),
        (box.center.dy / tileSize).floor(),
      );
      tiles.putIfAbsent(key, _Tile.new).add(lane, box);
    }
    return _RoadLayer._(tiles, bounds);
  }

  /// Strokes the tiles intersecting [viewport] (world metres) onto a
  /// canvas that is already in world coordinates.
  void drawVector(
      Canvas canvas, Rect viewport, double scale, _Palette palette) {
    final road = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = palette.road;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale
      ..color = palette.laneLine;
    final minRoad = 2 / scale;
    for (final tile in tiles.values) {
      if (!tile.bounds.overlaps(viewport)) continue;
      for (final entry in tile.roads.entries) {
        canvas.drawPath(
            entry.value, road..strokeWidth = math.max(entry.key, minRoad));
      }
      if (scale > 1.2) canvas.drawPath(tile.centerlines, line);
    }
  }

  Future<void> rasterize(_Palette palette) async {
    final k = math.min(
      maxImageScale,
      maxImagePixels / math.max(bounds.width, bounds.height),
    );
    final w = (bounds.width * k).ceil();
    final h = (bounds.height * k).ceil();
    if (w <= 0 || h <= 0) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Image pixel (0,0) is the map's north-west corner; world y points up.
    canvas.scale(k, -k);
    canvas.translate(-bounds.left, -bounds.bottom);
    drawVector(canvas, bounds, k, palette);
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(w, h);
    picture.dispose();
    image?.dispose();
    image = rendered;
    imageScale = k;
    imagePalette = palette;
  }

  void dispose() {
    image?.dispose();
    image = null;
  }
}

class _Tile {
  final Map<double, Path> roads = {};
  final Path centerlines = Path();
  Rect bounds = Rect.zero;
  bool _empty = true;

  void add(HdLane lane, Rect box) {
    bounds = _empty ? box : bounds.expandToInclude(box);
    _empty = false;
    // Group by width (0.5 m steps) so each tile strokes in a few calls.
    final width = (lane.width * 2).roundToDouble() / 2;
    final path = roads.putIfAbsent(width, Path.new);
    path.moveTo(lane.points.first.dx, lane.points.first.dy);
    centerlines.moveTo(lane.points.first.dx, lane.points.first.dy);
    for (final p in lane.points.skip(1)) {
      path.lineTo(p.dx, p.dy);
      centerlines.lineTo(p.dx, p.dy);
    }
  }
}

class _Palette {
  const _Palette({
    required this.background,
    required this.road,
    required this.laneLine,
    required this.route,
    required this.routeCasing,
    required this.trajectory,
    required this.ego,
    required this.vehicle,
    required this.pedestrian,
    required this.other,
  });

  final Color background;
  final Color road;
  final Color laneLine;
  final Color route;
  final Color routeCasing;
  final Color trajectory;
  final Color ego;
  final Color vehicle;
  final Color pedestrian;
  final Color other;

  static const light = _Palette(
    background: Color(0xFFEDEDEA),
    road: Color(0xFFFFFFFF),
    laneLine: Color(0xFFD6D6D1),
    route: Color(0xFF3B82F6),
    routeCasing: Color(0xFFFFFFFF),
    trajectory: Color(0xFF10B981),
    ego: Color(0xFF16171A),
    vehicle: Color(0xFF8A8F94),
    pedestrian: Color(0xFFE38B2C),
    other: Color(0xFFB0B4B8),
  );

  static const dark = _Palette(
    background: Color(0xFF111416),
    road: Color(0xFF2A3033),
    laneLine: Color(0xFF3A4246),
    route: Color(0xFF4C8DF6),
    routeCasing: Color(0xFF111416),
    trajectory: Color(0xFF34D399),
    ego: Color(0xFFE1E1D6),
    vehicle: Color(0xFF7D868B),
    pedestrian: Color(0xFFF0A04B),
    other: Color(0xFF5C6569),
  );
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.roads,
    required this.state,
    required this.pin,
    required this.center,
    required this.scale,
    required this.palette,
  }) : roadImage = roads.image;

  final _RoadLayer roads;

  /// The road image at construction; the layer fills it in asynchronously,
  /// so it's captured to notice in shouldRepaint when it arrives.
  final ui.Image? roadImage;
  final ApolloState? state;
  final Offset? pin;
  final Offset center;
  final double scale;
  final _Palette palette;

  /// World-space width that renders as [px] screen pixels.
  double _px(double px) => px / scale;

  Offset _toScreen(Offset world, Size size) => Offset(
        size.width / 2 + (world.dx - center.dx) * scale,
        size.height / 2 - (world.dy - center.dy) * scale,
      );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);

    final image = roadImage;
    final useImage = image != null &&
        identical(roads.imagePalette, palette) &&
        scale <= roads.imageScale * 1.5;
    if (useImage) {
      final b = roads.bounds;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromPoints(
          _toScreen(Offset(b.left, b.bottom), size),
          _toScreen(Offset(b.right, b.top), size),
        ),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, -scale); // world y points up
    canvas.translate(-center.dx, -center.dy);

    if (!useImage) {
      final half = Offset(size.width, size.height) / (2 * scale);
      roads.drawVector(
        canvas,
        Rect.fromPoints(center - half, center + half),
        scale,
        palette,
      );
    }

    final scene = state?.scene;
    if (scene != null) {
      _polyline(canvas, scene.route, palette.routeCasing, _px(9));
      _polyline(canvas, scene.route, palette.route, _px(5.5));
      _polyline(canvas, scene.trajectory,
          palette.trajectory.withValues(alpha: 0.85), _px(7));
      for (final o in scene.obstacles) {
        _box(
          canvas,
          Offset(o.x, o.y),
          o.heading,
          math.max(o.length, 0.6),
          math.max(o.width, 0.6),
          switch (o.type) {
            'VEHICLE' => palette.vehicle,
            'PEDESTRIAN' || 'BICYCLE' => palette.pedestrian,
            _ => palette.other,
          },
        );
      }
    }

    final destination = state?.autopilot.destination;
    canvas.restore();

    // Markers are drawn in screen space so they keep a constant size.
    Offset toScreen(Offset w) => Offset(
          size.width / 2 + (w.dx - center.dx) * scale,
          size.height / 2 - (w.dy - center.dy) * scale,
        );

    if (destination != null) {
      _pinMarker(canvas, toScreen(destination.offset), const Color(0xFFE94B4B));
    }
    if (pin != null) {
      _pinMarker(canvas, toScreen(pin!), palette.ego);
    }
    final pose = state?.vehicle.pose;
    if (pose != null) {
      _egoMarker(canvas, toScreen(pose.offset), pose.heading);
    }
  }

  void _polyline(Canvas canvas, List<Offset> pts, Color color, double width) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  void _box(Canvas canvas, Offset c, double heading, double length,
      double width, Color color) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(heading);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: length, height: width),
        Radius.circular(math.min(width, length) * 0.25),
      ),
      Paint()..color = color,
    );
    canvas.restore();
  }

  void _egoMarker(Canvas canvas, Offset c, double heading) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    // World heading is CCW from east; screen y is flipped.
    canvas.rotate(-heading);
    final len = math.max(4.8 * scale, 26.0);
    final wid = math.max(2.1 * scale, 13.0);
    canvas.drawCircle(
      Offset.zero,
      len * 0.9,
      Paint()..color = palette.route.withValues(alpha: 0.14),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: len, height: wid),
      Radius.circular(wid * 0.38),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(body, Paint()..color = palette.ego);
    // Windscreen marks the front.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(len * 0.08, -wid * 0.36, len * 0.18, wid * 0.72),
        Radius.circular(wid * 0.12),
      ),
      Paint()..color = palette.background.withValues(alpha: 0.75),
    );
    canvas.restore();
  }

  void _pinMarker(Canvas canvas, Offset tip, Color color) {
    const r = 11.0;
    final head = tip - const Offset(0, 26);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
          head.dx - r * 1.1, head.dy + r * 0.6, head.dx - r, head.dy)
      ..arcToPoint(Offset(head.dx + r, head.dy),
          radius: const Radius.circular(r))
      ..quadraticBezierTo(head.dx + r * 1.1, head.dy + r * 0.6, tip.dx, tip.dy)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(head, r * 0.38, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      !identical(old.state, state) ||
      old.pin != pin ||
      old.center != center ||
      old.scale != scale ||
      !identical(old.roads, roads) ||
      !identical(old.roadImage, roadImage) ||
      old.palette != palette;
}
