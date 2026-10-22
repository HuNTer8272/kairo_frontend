import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/apollo/apollo_service.dart';
import '../../theme/app_colors.dart';
import 'apollo_selector.dart';
import 'autopilot_format.dart';
import 'steering_wheel.dart';

/// On-screen pedals, wheel and gear selector for driving the car by hand.
///
/// Inputs stream to the gateway 20 times a second for as long as this is
/// on screen; if they stop (app closed, Wi-Fi drop) the car brakes itself.
/// Keyboard works too (emulator / desktop): W/S or arrows for throttle and
/// brake, A/D or arrows to steer, Space to brake.
class ManualDriveControls extends StatefulWidget {
  const ManualDriveControls({super.key, required this.apollo});

  final ApolloService apollo;

  @override
  State<ManualDriveControls> createState() => _ManualDriveControlsState();
}

class _ManualDriveControlsState extends State<ManualDriveControls> {
  static const _sendPeriod = Duration(milliseconds: 50);
  static const _keySteerRate = 2.5; // full lock in 0.4 s

  final _focus = FocusNode(debugLabel: 'manual-drive');
  Timer? _ticker;

  double _throttle = 0;
  double _brake = 0;
  double _steer = 0; // + = left

  // Keyboard state.
  final Set<LogicalKeyboardKey> _keys = {};
  static final _handledKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.space,
  };

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(_sendPeriod, (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _focus.dispose();
    // Release everything so the car doesn't keep the last throttle.
    widget.apollo.sendDrive();
    super.dispose();
  }

  void _tick() {
    if (_keys.isNotEmpty) _applyKeys();
    widget.apollo.sendDrive(
      throttle: _throttle,
      brake: _brake,
      steer: _steer,
    );
  }

  void _applyKeys() {
    bool down(LogicalKeyboardKey a, [LogicalKeyboardKey? b]) =>
        _keys.contains(a) || (b != null && _keys.contains(b));
    final dt = _sendPeriod.inMilliseconds / 1000;
    final left = down(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft);
    final right = down(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight);
    setState(() {
      _throttle =
          down(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp) ? 1 : 0;
      _brake = down(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown) ||
              down(LogicalKeyboardKey.space)
          ? 1
          : 0;
      final target = left == right ? 0.0 : (left ? 1.0 : -1.0);
      final step = _keySteerRate * dt;
      _steer += (target - _steer).clamp(-step, step);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_handledKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _keys.add(event.logicalKey);
    } else if (event is KeyUpEvent) {
      _keys.remove(event.logicalKey);
      if (_keys.isEmpty) {
        setState(() {
          _throttle = 0;
          _brake = 0;
          _steer = 0;
        });
      }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: dark
              ? const Color(0xE814181A)
              : Colors.white.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(blurRadius: 18, color: Color(0x22000000))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _GearSelector(apollo: widget.apollo),
            const SizedBox(width: 14),
            SteeringWheel(
              value: _steer,
              onChanged: (v) => setState(() => _steer = v),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 118,
              child: ApolloSelector<(int, bool)>(
                apollo: widget.apollo,
                selector: (a) => (
                  a.state?.vehicle.speedKph.round() ?? 0,
                  a.state?.drive.deadman ?? false,
                ),
                builder: (context, v) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${v.$1}',
                            style: const TextStyle(
                                fontSize: 40,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1)),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('km/h',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.sports_esports_outlined,
                          size: 15,
                          color:
                              v.$2 ? AppColors.alert : scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          v.$2 ? 'No input — braking' : 'Manual driving',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: v.$2
                                ? AppColors.alert
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('Turn the wheel · hold the pedals',
                        style: TextStyle(
                            fontSize: 10, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            _Pedal(
              label: 'Brake',
              width: 84,
              height: 96,
              color: AppColors.alert,
              value: _brake,
              onChanged: (v) => setState(() => _brake = v),
            ),
            const SizedBox(width: 10),
            _Pedal(
              label: 'Go',
              width: 56,
              height: 120,
              color: AutopilotFormat.driving,
              value: _throttle,
              onChanged: (v) => setState(() => _throttle = v),
            ),
          ],
        ),
      ),
    );
  }
}

class _GearSelector extends StatelessWidget {
  const _GearSelector({required this.apollo});

  final ApolloService apollo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ApolloSelector<(String?, bool)>(
      apollo: apollo,
      selector: (a) => (a.state?.drive.gear, a.isPending('gear')),
      builder: (context, v) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final g in const ['P', 'R', 'N', 'D'])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SizedBox(
                width: 40,
                height: 28,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: g == v.$1
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    foregroundColor:
                        g == v.$1 ? scheme.onPrimary : scheme.onSurface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  // The engaged gear stays enabled (styled, no-op) so it doesn't
                  // render greyed out like a disabled button.
                  onPressed: v.$2
                      ? null
                      : () {
                          if (g != v.$1) {
                            apolloAction(context, apollo.setGear(g));
                          }
                        },
                  child: Text(g,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Press and hold; pressing higher on the pedal pushes it further.
class _Pedal extends StatelessWidget {
  const _Pedal({
    required this.label,
    required this.width,
    required this.height,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double width;
  final double height;
  final Color color;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    double amount(Offset local) =>
        (0.35 + 0.65 * (1 - local.dy / height)).clamp(0.2, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (d) => onChanged(amount(d.localPosition)),
      onPanUpdate: (d) => onChanged(amount(d.localPosition)),
      onPanEnd: (_) => onChanged(0),
      onPanCancel: () => onChanged(0),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12 + 0.6 * value),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
        ),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: value > 0.4 ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
