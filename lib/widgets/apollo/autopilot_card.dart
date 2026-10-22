import 'package:flutter/material.dart';

import '../../models/apollo_state.dart';
import '../../services/apollo/apollo_service.dart';
import '../../theme/app_colors.dart';
import 'apollo_selector.dart';
import 'autopilot_format.dart';

/// Home-screen readout in the spirit of a Tesla's driver display: live
/// speed, autopilot status, trip progress, and the one or two actions that
/// make sense right now (stop while driving, resume/cancel when paused,
/// pick a destination when idle).
class AutopilotCard extends StatelessWidget {
  const AutopilotCard({
    super.key,
    required this.apollo,
    required this.onOpenNavigation,
    required this.onOpenSettings,
  });

  final ApolloService apollo;
  final VoidCallback onOpenNavigation;

  /// Opens Settings > Autopilot (connection, sim control, modules).
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    // Only what's shown: rebuilds when the rounded speed or the wording
    // changes, not on every 10 Hz state update.
    return ApolloSelector<
        (int?, String, String, AutopilotPhase?, bool, String)>(
      apollo: apollo,
      selector: (a) => (
        a.isLive ? a.state!.vehicle.speedKph.round() : null,
        AutopilotFormat.title(a),
        _subtitle(a.state?.autopilot),
        a.state?.autopilot.phase,
        a.isLive,
        [
          for (final n in _commands)
            if (a.isPending(n)) n
        ].join(','),
      ),
      builder: (context, v) {
        final scheme = Theme.of(context).colorScheme;
        final speed = v.$1;
        final statusColor = AutopilotFormat.color(apollo, scheme);

        return Container(
          width: 250,
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: const [
              BoxShadow(
                blurRadius: 20,
                offset: Offset(0, 10),
                color: Color(0x10000000),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    speed?.toString() ?? '--',
                    style: const TextStyle(
                      fontSize: 46,
                      height: 0.95,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'km/h',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Autopilot settings',
                    visualDensity: VisualDensity.compact,
                    onPressed: onOpenSettings,
                    icon: Icon(Icons.tune_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.assistant_navigation,
                      size: 18, color: statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      v.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                v.$3,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _Actions(
                apollo: apollo,
                onOpenNavigation: onOpenNavigation,
                onOpenSettings: onOpenSettings,
              ),
            ],
          ),
        );
      },
    );
  }

  static const _commands = [
    'stop',
    'pull_over',
    'resume',
    'cancel',
    'manual',
  ];

  String _subtitle(AutopilotStatus? ap) {
    if (apollo.connection != GatewayConnection.connected) {
      return apollo.connectionError ?? 'Looking for the KAIRO gateway';
    }
    if (ap == null) return '';
    final dest = ap.destination;
    switch (ap.phase) {
      case AutopilotPhase.offline:
      case AutopilotPhase.unavailable:
      case AutopilotPhase.error:
        return ap.message ?? 'Check Settings > Autopilot';
      case AutopilotPhase.ready:
        return 'Pick a destination on the map';
      case AutopilotPhase.manual:
        return 'You are driving from the tablet';
      case AutopilotPhase.arrived:
        return dest?.label ?? 'Destination reached';
      default:
        final parts = [
          if (dest != null) dest.label,
          AutopilotFormat.distance(ap.remainingM),
          AutopilotFormat.eta(ap.etaS),
        ];
        final trip = parts.join(' · ');
        return ap.message == null ? trip : '$trip\n${ap.message}';
    }
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.apollo,
    required this.onOpenNavigation,
    required this.onOpenSettings,
  });

  final ApolloService apollo;
  final VoidCallback onOpenNavigation;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final phase = apollo.state?.autopilot.phase;

    Future<void> run(Future<String?> Function() action) async {
      apolloAction(context, action());
    }

    if (!apollo.isLive || phase == AutopilotPhase.unavailable) {
      return _ActionButton(
        label: 'Set up',
        icon: Icons.settings_rounded,
        onPressed: onOpenSettings,
      );
    }

    return switch (phase) {
      AutopilotPhase.driving ||
      AutopilotPhase.estop ||
      AutopilotPhase.stopping =>
        Row(children: [
          Expanded(
            child: _ActionButton(
              label: 'Stop',
              icon: Icons.pan_tool_rounded,
              danger: true,
              busy: apollo.isPending('stop'),
              onPressed: () => run(apollo.stop),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              label: 'Pull over',
              icon: Icons.local_parking_rounded,
              busy: apollo.isPending('pull_over'),
              onPressed: () => run(apollo.pullOver),
            ),
          ),
        ]),
      AutopilotPhase.stopped || AutopilotPhase.error => Row(children: [
          Expanded(
            child: _ActionButton(
              label: 'Resume',
              icon: Icons.play_arrow_rounded,
              filled: true,
              busy: apollo.isPending('resume'),
              onPressed: () => run(apollo.resume),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              label: 'End trip',
              icon: Icons.close_rounded,
              busy: apollo.isPending('cancel'),
              onPressed: () => run(apollo.cancelRoute),
            ),
          ),
        ]),
      AutopilotPhase.manual => Row(children: [
          Expanded(
            child: _ActionButton(
              label: 'Controls',
              icon: Icons.sports_esports_outlined,
              filled: true,
              onPressed: onOpenNavigation,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              label: 'Hand back',
              icon: Icons.assistant_navigation,
              busy: apollo.isPending('manual'),
              onPressed: () => run(() => apollo.setManual(false)),
            ),
          ),
        ]),
      _ => Row(children: [
          Expanded(
            flex: 3,
            child: _ActionButton(
              label: 'Destination',
              icon: Icons.near_me_rounded,
              filled: true,
              onPressed: onOpenNavigation,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _ActionButton(
              label: 'Drive',
              icon: Icons.sports_esports_outlined,
              busy: apollo.isPending('manual'),
              onPressed: () async {
                if (await apolloAction(context, apollo.setManual(true))) {
                  onOpenNavigation();
                }
              },
            ),
          ),
        ]),
    };
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.danger = false,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;
  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = danger
        ? AppColors.alert
        : filled
            ? scheme.primary
            : scheme.surface;
    final foreground = danger
        ? Colors.white
        : filled
            ? scheme.onPrimary
            : scheme.onSurface;
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: filled || danger
                ? BorderSide.none
                : BorderSide(color: scheme.outlineVariant),
          ),
        ),
        onPressed: busy ? null : onPressed,
        icon: busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: foreground),
              )
            : Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
