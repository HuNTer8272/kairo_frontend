import 'package:flutter/material.dart';

import '../../models/apollo_state.dart';
import '../../services/apollo/apollo_service.dart';
import '../../theme/app_colors.dart';
import 'apollo_selector.dart';
import 'autopilot_format.dart';

/// Body controls around the car on the home screen (lock, frunk, trunk) and
/// its status icons. They show the body controller's real state and send
/// changes to the gateway; without a connection they keep the original
/// static look and explain why a tap does nothing.

void _offline(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Vehicle offline — connect in Settings > Autopilot'),
    duration: Duration(seconds: 2),
  ));
}

/// Selects [field] from the body state, or null while offline.
bool? _bodyFlag(ApolloService a, bool Function(BodyState) field) {
  final body = a.state?.body;
  if (!a.isLive || body == null || !body.isKnown) return null;
  return field(body);
}

class LockToggle extends StatelessWidget {
  const LockToggle({super.key, required this.apollo});

  final ApolloService apollo;

  @override
  Widget build(BuildContext context) {
    return ApolloSelector<bool?>(
      apollo: apollo,
      selector: (a) => _bodyFlag(a, (b) => b.locked),
      builder: (context, locked) => Column(
        children: [
          IconButton(
            tooltip: locked == null
                ? 'Lock'
                : locked
                    ? 'Unlock'
                    : 'Lock',
            onPressed: locked == null
                ? () => _offline(context)
                : () => apolloAction(
                      context,
                      apollo.setBody({'locked': !locked}),
                      success: locked ? 'Unlocked' : 'Locked',
                    ),
            icon: Icon(
              locked ?? false ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 25,
            ),
          ),
          const SizedBox(
            height: 60,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: Color(0xFFBFC2C5),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Open Frunk" / "Trunk Open" style label with a leader line; tap toggles.
class ClosureLabel extends StatelessWidget {
  const ClosureLabel({
    super.key,
    required this.apollo,
    required this.field,
    required this.name,
    required this.alignRight,
  });

  final ApolloService apollo;

  /// Body field, e.g. 'frunk_open'.
  final String field;
  final String name;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return ApolloSelector<bool?>(
      apollo: apollo,
      selector: (a) => _bodyFlag(a, (b) => b.flag(field)),
      builder: (context, open) {
        final scheme = Theme.of(context).colorScheme;
        final action = open ?? false ? 'Close' : 'Open';
        final color = open ?? false ? scheme.primary : const Color(0xFF686A6D);
        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: open == null
              ? () => _offline(context)
              : () => apolloAction(
                    context,
                    apollo.setBody({field: !open}),
                    success: '$name ${open ? 'closed' : 'opened'}',
                  ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 1, height: 60, color: const Color(0xFFBFC2C5)),
                const SizedBox(width: 7),
                Text(
                  alignRight ? '$name\n$action' : '$action\n$name',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The icon column at the car view's left edge: headlights, hazards and
/// a quick horn.
class BodyStatusIcons extends StatelessWidget {
  const BodyStatusIcons(
      {super.key, required this.apollo, required this.compact});

  final ApolloService apollo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ApolloSelector<(bool, String, bool)>(
      apollo: apollo,
      selector: (a) {
        final body = a.state?.body;
        final live = a.isLive && (body?.isKnown ?? false);
        return (live, body?.lights ?? 'AUTO', body?.hazards ?? false);
      },
      builder: (context, v) {
        final scheme = Theme.of(context).colorScheme;
        final lightsOn = v.$2 == 'ON' || v.$2 == 'AUTO';
        return Column(
          children: [
            _IconTap(
              icon: Icons.light_mode_rounded,
              color: lightsOn ? scheme.primary : const Color(0xFF929699),
              tooltip:
                  'Headlights: ${AutopilotFormat.pretty(v.$2.toLowerCase())}',
              onTap: !v.$1
                  ? () => _offline(context)
                  : () => apolloAction(context,
                      apollo.setBody({'lights': lightsOn ? 'OFF' : 'ON'})),
            ),
            const SizedBox(height: 10),
            _IconTap(
              icon: compact
                  ? Icons.airline_seat_recline_normal
                  : Icons.warning_amber_rounded,
              color: v.$3 ? AutopilotFormat.warning : const Color(0xFF929699),
              tooltip: v.$3 ? 'Hazards on' : 'Hazards',
              onTap: !v.$1
                  ? () => _offline(context)
                  : () =>
                      apolloAction(context, apollo.setBody({'hazards': !v.$3})),
            ),
            const SizedBox(height: 10),
            _IconTap(
              icon: Icons.campaign_outlined,
              color: AppColors.alert,
              tooltip: 'Horn',
              onTap: !v.$1
                  ? () => _offline(context)
                  : () => apolloAction(context, apollo.honk()),
            ),
          ],
        );
      },
    );
  }
}

class _IconTap extends StatelessWidget {
  const _IconTap({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, color: color),
    );
  }
}
