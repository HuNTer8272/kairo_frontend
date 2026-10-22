import 'package:flutter/material.dart';

import '../../models/apollo_state.dart';
import '../../services/apollo/apollo_service.dart';
import '../../theme/app_colors.dart';

/// Shared wording/colours for autopilot status across the dashboard,
/// navigation and settings, so every surface describes Apollo the same way.
abstract final class AutopilotFormat {
  static const Color driving = Color(0xFF2F9E6A);
  static const Color warning = Color(0xFFD08A1C);

  static String title(ApolloService apollo) {
    if (apollo.connection != GatewayConnection.connected) {
      return apollo.connection == GatewayConnection.connecting
          ? 'Connecting…'
          : 'Gateway offline';
    }
    final state = apollo.state;
    if (state == null) return 'Connecting…';
    final ap = state.autopilot;
    return switch (ap.phase) {
      AutopilotPhase.offline => 'Apollo offline',
      AutopilotPhase.unavailable => 'No vehicle position',
      AutopilotPhase.ready => 'Autopilot ready',
      AutopilotPhase.driving => 'Autopilot engaged',
      AutopilotPhase.stopping => 'Stopping…',
      AutopilotPhase.stopped => 'Autopilot paused',
      AutopilotPhase.estop => 'Emergency stop',
      AutopilotPhase.arrived => 'Arrived',
      AutopilotPhase.error => 'Autopilot error',
      AutopilotPhase.manual => 'Manual driving',
    };
  }

  static Color color(ApolloService apollo, ColorScheme scheme) {
    if (!apollo.isLive) return scheme.onSurfaceVariant;
    return switch (apollo.state!.autopilot.phase) {
      AutopilotPhase.driving || AutopilotPhase.arrived => driving,
      AutopilotPhase.stopping || AutopilotPhase.stopped => warning,
      AutopilotPhase.estop || AutopilotPhase.error => AppColors.alert,
      AutopilotPhase.ready => scheme.onSurface,
      AutopilotPhase.manual => scheme.primary,
      _ => scheme.onSurfaceVariant,
    };
  }

  static String distance(double? metres) {
    if (metres == null) return '—';
    if (metres >= 1000) return '${(metres / 1000).toStringAsFixed(1)} km';
    return '${metres.round()} m';
  }

  static String eta(double? seconds) {
    if (seconds == null) return '—';
    if (seconds < 60) return '<1 min';
    return '${(seconds / 60).round()} min';
  }

  /// Turns Apollo identifiers like "carla_town05" / "Sim_Control" into
  /// readable labels.
  static String pretty(String? value) {
    if (value == null || value.isEmpty) return '—';
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

/// Small coloured dot + label, e.g. connection or module health.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Awaits an [ApolloService] command and shows its error (or [success])
/// in a snackbar. Returns true when the command succeeded.
Future<bool> apolloAction(BuildContext context, Future<String?> command,
    {String? success}) async {
  final error = await command;
  if (!context.mounted) return error == null;
  final messenger = ScaffoldMessenger.of(context);
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
    return false;
  }
  if (success != null) {
    messenger.showSnackBar(SnackBar(
      content: Text(success),
      duration: const Duration(seconds: 2),
    ));
  }
  return true;
}
