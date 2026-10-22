import 'package:flutter/material.dart';

import '../models/apollo_state.dart';
import '../services/apollo/apollo_service.dart';
import 'apollo/apollo_selector.dart';
import 'apollo/autopilot_format.dart';

/// The status row pinned to the top of the screen: gear selector, battery,
/// autopilot status, profile, clock, cabin temperature, airbag chip.
///
/// With Apollo live, the gear letters are the car's real gear and can be
/// tapped to shift (shifting out of D while Apollo drives is a take-over),
/// and the temperature is the climate setpoint (tap to adjust).
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.compact,
    required this.onProfileTap,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.apollo,
    required this.onAutopilotTap,
  });

  final bool compact;
  final VoidCallback onProfileTap;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final ApolloService apollo;
  final VoidCallback onAutopilotTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        children: [
          _GearSelector(apollo: apollo),
          const SizedBox(width: 24),
          const Icon(Icons.battery_5_bar_rounded, size: 23),
          const SizedBox(width: 6),
          ApolloSelector<int?>(
            apollo: apollo,
            selector: (a) => a.isLive ? a.state!.vehicle.batteryPct : null,
            builder: (context, pct) => Text('${pct ?? 80}%',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 18),
          _AutopilotChip(apollo: apollo, onTap: onAutopilotTap),
          const Spacer(),
          IconButton(
            tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
            onPressed: () => onThemeChanged(!isDarkMode),
            icon: Icon(isDarkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
          ),
          IconButton(
            onPressed: onProfileTap,
            icon: const Icon(Icons.person_rounded),
          ),
          const Text(
            'Guest',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5E6063),
            ),
          ),
          const SizedBox(width: 18),
          const Icon(Icons.radio_button_checked_rounded, size: 22),
          const Spacer(),
          const Text(
            '12:00 pm',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 20),
          _ClimateButton(apollo: apollo),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3B3D),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PASSENGER\nAIRBAG ON',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// P R N D with the engaged gear emphasised; tap to shift.
class _GearSelector extends StatelessWidget {
  const _GearSelector({required this.apollo});

  final ApolloService apollo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ApolloSelector<(String?, bool)>(
      apollo: apollo,
      selector: (a) => (
        a.isLive ? (a.state!.drive.gear ?? a.state!.vehicle.gear) : null,
        a.canDrive,
      ),
      builder: (context, v) => Row(
        children: [
          for (final g in const ['P', 'R', 'N', 'D'])
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: !v.$2 || g == v.$1
                  ? null
                  : () => apolloAction(context, apollo.setGear(g)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                child: Text(
                  g,
                  style: TextStyle(
                    fontWeight: g == v.$1 ? FontWeight.w900 : FontWeight.w700,
                    fontSize: g == v.$1 ? 15 : 12,
                    color:
                        g == v.$1 ? scheme.onSurface : const Color(0xFF8A8D90),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact autopilot indicator; tap for Settings > Autopilot.
class _AutopilotChip extends StatelessWidget {
  const _AutopilotChip({required this.apollo, required this.onTap});

  final ApolloService apollo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ApolloSelector<(String, AutopilotPhase?, bool)>(
      apollo: apollo,
      selector: (a) =>
          (AutopilotFormat.title(a), a.state?.autopilot.phase, a.isLive),
      builder: (context, v) {
        final color =
            AutopilotFormat.color(apollo, Theme.of(context).colorScheme);
        return Tooltip(
          message: v.$1,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    v.$2 == AutopilotPhase.manual
                        ? Icons.sports_esports_outlined
                        : Icons.assistant_navigation,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  StatusDot(
                    size: 6,
                    color: v.$3 ? AutopilotFormat.driving : color,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Cabin temperature; tap for climate on/off and the setpoint.
class _ClimateButton extends StatelessWidget {
  const _ClimateButton({required this.apollo});

  final ApolloService apollo;

  @override
  Widget build(BuildContext context) {
    return ApolloSelector<(bool, double, bool)>(
      apollo: apollo,
      selector: (a) {
        final body = a.state?.body;
        final live = a.isLive && (body?.isKnown ?? false);
        return (live, body?.cabinTempC ?? 22, body?.climateOn ?? true);
      },
      builder: (context, v) {
        final label = v.$3 ? '${_fmt(v.$2)}°C' : 'Off';
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: v.$1 ? () => _showClimate(context) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  static String _fmt(double t) =>
      t == t.roundToDouble() ? t.toStringAsFixed(0) : t.toStringAsFixed(1);

  void _showClimate(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ApolloSelector<(double, bool)>(
        apollo: apollo,
        selector: (a) => (
          a.state?.body.cabinTempC ?? 22,
          a.state?.body.climateOn ?? true,
        ),
        builder: (context, v) => Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
          child: Row(
            children: [
              const Icon(Icons.thermostat_rounded),
              const SizedBox(width: 10),
              const Text('Climate',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: v.$2,
                onChanged: (on) =>
                    apolloAction(context, apollo.setBody({'climate_on': on})),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: v.$1 > 15
                    ? () => apolloAction(
                        context, apollo.setBody({'cabin_temp_c': v.$1 - 0.5}))
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  '${_fmt(v.$1)}°C',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton.filledTonal(
                onPressed: v.$1 < 28
                    ? () => apolloAction(
                        context, apollo.setBody({'cabin_temp_c': v.$1 + 0.5}))
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
