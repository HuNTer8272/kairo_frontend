import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A steering wheel turned with a rotary drag (grab the rim and turn it,
/// like a real one). Springs back to centre when released.
///
/// [value] is the steering command: -1 (full right) .. 1 (full left), which
/// maps to [maxRotation] radians of wheel rotation either way.
class SteeringWheel extends StatefulWidget {
  const SteeringWheel({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 132,
    this.maxRotation = 150 * math.pi / 180,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double size;
  final double maxRotation;

  @override
  State<SteeringWheel> createState() => _SteeringWheelState();
}

class _SteeringWheelState extends State<SteeringWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _return;
  double _returnFrom = 0;

  bool _dragging = false;
  double _grabAngle = 0; // touch angle when the drag started
  double _grabRotation = 0; // wheel rotation when the drag started
  double _rotation = 0; // clockwise positive (= right turn)

  Offset get _center => Offset(widget.size / 2, widget.size / 2);

  @override
  void initState() {
    super.initState();
    // Created here, not lazily: a lazy controller would first be built in
    // dispose() (if the wheel was never released), which isn't allowed.
    _return = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..addListener(_onReturnTick);
    _rotation = -widget.value * widget.maxRotation;
  }

  @override
  void didUpdateWidget(SteeringWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow external input (keyboard) when the finger isn't on the wheel.
    if (!_dragging && !_return.isAnimating) {
      _rotation = -widget.value * widget.maxRotation;
    }
  }

  @override
  void dispose() {
    _return.dispose();
    super.dispose();
  }

  double _touchAngle(Offset local) {
    final d = local - _center;
    return math.atan2(d.dy, d.dx);
  }

  void _emit() => widget.onChanged(
        (-_rotation / widget.maxRotation).clamp(-1.0, 1.0),
      );

  void _onPanStart(DragStartDetails details) {
    _return.stop();
    _dragging = true;
    _grabAngle = _touchAngle(details.localPosition);
    _grabRotation = _rotation;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    var delta = _touchAngle(details.localPosition) - _grabAngle;
    // Unwrap across the ±pi seam so turning past 6 o'clock is continuous.
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    while (delta < -math.pi) {
      delta += 2 * math.pi;
    }
    final next =
        (_grabRotation + delta).clamp(-widget.maxRotation, widget.maxRotation);
    // Re-anchor at the stops so pulling back starts turning immediately.
    if (next != _grabRotation + delta) {
      _grabRotation = next;
      _grabAngle = _touchAngle(details.localPosition);
    }
    setState(() => _rotation = next);
    _emit();
  }

  void _release() {
    _dragging = false;
    _returnFrom = _rotation;
    _return.forward(from: 0);
  }

  void _onReturnTick() {
    final t = Curves.easeOutCubic.transform(_return.value);
    setState(() => _rotation = _returnFrom * (1 - t));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final degrees = (_rotation * 180 / math.pi).round();
    final readout = degrees == 0
        ? 'Centre'
        : '${degrees.abs()}° ${degrees > 0 ? 'R' : 'L'}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => _release(),
          onPanCancel: _release,
          child: SizedBox.square(
            dimension: widget.size,
            child: CustomPaint(
              painter: _WheelPainter(
                rotation: _rotation,
                maxRotation: widget.maxRotation,
                rim: scheme.onSurface,
                spoke: scheme.onSurface.withValues(alpha: 0.82),
                hub: scheme.primaryContainer,
                hubInk: scheme.onPrimaryContainer,
                track: scheme.surfaceContainerHighest,
                accent: const Color(0xFF2F9E6A),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          readout,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.rotation,
    required this.maxRotation,
    required this.rim,
    required this.spoke,
    required this.hub,
    required this.hubInk,
    required this.track,
    required this.accent,
  });

  final double rotation;
  final double maxRotation;
  final Color rim;
  final Color spoke;
  final Color hub;
  final Color hubInk;
  final Color track;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final trackR = outer - 3;
    final rimR = outer - 14;
    const rimWidth = 12.0;

    // Lock indicator: a thin track with the applied lock filled in.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final trackRect = Rect.fromCircle(center: c, radius: trackR);
    const top = -math.pi / 2;
    canvas.drawArc(trackRect, top - maxRotation, 2 * maxRotation, false,
        trackPaint..color = track);
    if (rotation.abs() > 0.01) {
      canvas.drawArc(
          trackRect, top, rotation, false, trackPaint..color = accent);
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);

    // Soft shadow under the rim only, so the wheel stays open between
    // the spokes.
    canvas.drawCircle(
      const Offset(0, 3),
      rimR,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimWidth
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Spokes: left, right and bottom, joining the rim to the hub.
    final spokePaint = Paint()
      ..color = spoke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final hubR = rimR * 0.34;
    for (final angle in const [math.pi, 0.0]) {
      canvas.drawLine(
        Offset(math.cos(angle) * hubR, 2),
        Offset(math.cos(angle) * (rimR - 2), 6),
        spokePaint..strokeWidth = 9,
      );
    }
    canvas.drawLine(
      Offset(0, hubR),
      Offset(0, rimR - 2),
      spokePaint..strokeWidth = 8,
    );

    // Rim, with thicker grips at ten-to-two.
    final rimPaint = Paint()
      ..color = rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = rimWidth;
    canvas.drawCircle(Offset.zero, rimR, rimPaint);
    // Hand grips at ten-to-two: textured bands on the rim.
    final gripRect = Rect.fromCircle(center: Offset.zero, radius: rimR);
    final gripPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = rimWidth - 5
      ..strokeCap = StrokeCap.round;
    for (final start in const [-math.pi * 0.92, -math.pi * 0.30]) {
      canvas.drawArc(gripRect, start, math.pi * 0.22, false, gripPaint);
    }

    // Twelve o'clock marker shows how far the wheel is turned.
    canvas.drawLine(
      Offset(0, -rimR - rimWidth / 2 + 2),
      Offset(0, -rimR + rimWidth / 2 - 2),
      Paint()
        ..color = accent
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Hub.
    canvas.drawCircle(Offset.zero, hubR, Paint()..color = hub);
    canvas.drawCircle(
      Offset.zero,
      hubR,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Emblem: a small chevron pointing forward.
    final emblem = Path()
      ..moveTo(-hubR * 0.42, hubR * 0.18)
      ..lineTo(0, -hubR * 0.30)
      ..lineTo(hubR * 0.42, hubR * 0.18);
    canvas.drawPath(
      emblem,
      Paint()
        ..color = hubInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.rotation != rotation ||
      old.rim != rim ||
      old.accent != accent ||
      old.hub != hub;
}
