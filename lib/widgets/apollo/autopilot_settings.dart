import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/apollo_state.dart';
import '../../services/apollo/apollo_config.dart';
import '../../services/apollo/apollo_service.dart';
import '../../theme/app_colors.dart';
import '../common/control_tile.dart';
import 'apollo_selector.dart';
import 'autopilot_format.dart';

/// Settings > Autopilot: everything the Dreamview Plus HMI does, from the
/// tablet - connection, drive commands, Sim Control, HD map, Apollo
/// modules - plus live chassis telemetry.
class AutopilotSettings extends StatelessWidget {
  const AutopilotSettings({super.key, required this.apollo});

  final ApolloService apollo;

  /// Everything the page shows except live telemetry, as one comparable
  /// value: the page rebuilds when one of these changes, not on every
  /// state update while the car moves.
  static String _signature(ApolloService a) {
    final s = a.state;
    final ap = s?.autopilot;
    final dv = s?.dreamview;
    return [
      a.connection,
      a.connectionError,
      a.gatewayUrl,
      a.isLive,
      a.cruiseKph,
      for (final n in const [
        'sim_control',
        'start_point',
        'map',
        'mode',
        'setup',
        'reset_mode',
      ])
        a.isPending(n),
      for (final m in dv?.modules.keys ?? const <String>[])
        a.isPending('module:$m'),
      s?.cyberConnected,
      s?.cyberError,
      s?.dreamviewConnected,
      s?.dreamviewError,
      s?.channels.entries.where((e) => e.value).map((e) => e.key).join('+'),
      ap?.phase,
      ap?.message,
      ap?.destination?.label,
      ((ap?.remainingM ?? 0) / 10).round(),
      dv?.mode,
      dv?.modes.join('+'),
      dv?.map,
      dv?.maps.join('+'),
      dv?.vehicle,
      dv?.operation,
      dv?.simControl,
      dv?.modules.entries.map((e) => '${e.key}=${e.value}').join('+'),
    ].join('|');
  }

  @override
  Widget build(BuildContext context) {
    return ApolloSelector<String>(
      apollo: apollo,
      selector: _signature,
      builder: (context, _) {
        final state = apollo.state;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Autopilot',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              _ConnectionSection(apollo: apollo),
              if (apollo.isLive && state != null) ...[
                const SizedBox(height: 22),
                _DriveSection(apollo: apollo, state: state),
                const SizedBox(height: 22),
                _SimulationSection(apollo: apollo, state: state),
                const SizedBox(height: 22),
                _MapSection(apollo: apollo, state: state),
                const SizedBox(height: 22),
                _ModulesSection(apollo: apollo, state: state),
                const SizedBox(height: 22),
                ApolloSelector<String>(
                  apollo: apollo,
                  // Telemetry at the precision it's displayed with.
                  selector: (a) {
                    final v = a.state?.vehicle;
                    return [
                      v?.speedKph.toStringAsFixed(1),
                      v?.gear,
                      v?.drivingMode,
                      v?.pose?.x.toStringAsFixed(1),
                      v?.pose?.y.toStringAsFixed(1),
                      v?.throttlePct?.round(),
                      v?.brakePct?.round(),
                      v?.steeringPct?.round(),
                      a.state?.autopilot.decision,
                      a.state?.scene.obstacles.length,
                    ].join('|');
                  },
                  builder: (context, _) =>
                      _TelemetrySection(state: apollo.state!),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A Material (not a decorated Container) so list tiles and switches
    // inside it can paint their ink.
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ConnectionSection extends StatefulWidget {
  const _ConnectionSection({required this.apollo});

  final ApolloService apollo;

  @override
  State<_ConnectionSection> createState() => _ConnectionSectionState();
}

class _ConnectionSectionState extends State<_ConnectionSection> {
  late final TextEditingController _url =
      TextEditingController(text: widget.apollo.gatewayUrl);

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apollo = widget.apollo;
    final state = apollo.state;
    final scheme = Theme.of(context).colorScheme;
    final connected = apollo.connection == GatewayConnection.connected;

    Widget row(String label, bool ok, String detail) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            StatusDot(color: ok ? AutopilotFormat.driving : AppColors.alert),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'Connection',
          trailing: TextButton.icon(
            onPressed: () async {
              final uri = apollo.dreamviewUri;
              final opened =
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Cannot open $uri')));
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open Dreamview'),
          ),
        ),
        _Card(
          child: Column(
            children: [
              row(
                'KAIRO gateway',
                connected,
                connected
                    ? apollo.gatewayUrl
                    : apollo.connectionError ?? 'Connecting…',
              ),
              row(
                'Apollo Cyber RT',
                state?.cyberConnected ?? false,
                state == null
                    ? '—'
                    : state.cyberConnected
                        ? 'Live (${state.channels.entries.where((e) => e.value).map((e) => e.key).join(', ')})'
                        : state.cyberError ?? 'Not reachable',
              ),
              row(
                'Dreamview Plus',
                state?.dreamviewConnected ?? false,
                state == null
                    ? '—'
                    : state.dreamviewConnected
                        ? [
                            state.dreamview.mode,
                            state.dreamview.vehicle,
                          ]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .join(' · ')
                        : state.dreamviewError ?? 'Not reachable',
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Gateway URL',
                      hintText: 'http://192.168.0.10:8090',
                      filled: true,
                      fillColor: scheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: apollo.setGatewayUrl,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => apollo.setGatewayUrl(_url.text),
                  child: const Text('Connect'),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriveSection extends StatelessWidget {
  const _DriveSection({required this.apollo, required this.state});

  final ApolloService apollo;
  final ApolloState state;

  @override
  Widget build(BuildContext context) {
    final ap = state.autopilot;
    final scheme = Theme.of(context).colorScheme;

    Future<void> run(Future<String?> Function() action, [String? ok]) async {
      apolloAction(context, action(), success: ok);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Drive'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.assistant_navigation,
                    color: AutopilotFormat.color(apollo, scheme)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AutopilotFormat.title(apollo),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AutopilotFormat.color(apollo, scheme),
                    ),
                  ),
                ),
                if (ap.destination != null)
                  Text(
                    '${ap.destination!.label} · ${AutopilotFormat.distance(ap.remainingM)}',
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
              ]),
              if (ap.message != null) ...[
                const SizedBox(height: 4),
                Text(ap.message!,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.speed_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('Cruise speed'),
                Expanded(
                  child: Slider(
                    min: ApolloConfig.minCruiseKph,
                    max: ApolloConfig.maxCruiseKph,
                    divisions: ((ApolloConfig.maxCruiseKph -
                                ApolloConfig.minCruiseKph) /
                            5)
                        .round(),
                    value: apollo.cruiseKph,
                    label: '${apollo.cruiseKph.round()} km/h',
                    onChanged: apollo.setCruiseKph,
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text('${apollo.cruiseKph.round()} km/h',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
              Text(
                'Applies to the next destination you send.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.18,
          children: [
            ControlTile(
              icon: Icons.pan_tool_rounded,
              label: 'Stop',
              active: ap.phase == AutopilotPhase.stopping ||
                  ap.phase == AutopilotPhase.stopped,
              onTap: () => run(apollo.stop),
            ),
            ControlTile(
              icon: Icons.local_parking_rounded,
              label: 'Pull Over',
              onTap: () => run(apollo.pullOver),
            ),
            ControlTile(
              icon: Icons.play_arrow_rounded,
              label: 'Resume',
              onTap: () => run(apollo.resume),
            ),
            ControlTile(
              icon: Icons.wrong_location_outlined,
              label: 'End Trip',
              onTap: () => run(apollo.cancelRoute),
            ),
            ControlTile(
              icon: Icons.turn_slight_left_rounded,
              label: 'Lane Left',
              onTap: () => run(() => apollo.changeLane(left: true)),
            ),
            ControlTile(
              icon: Icons.turn_slight_right_rounded,
              label: 'Lane Right',
              onTap: () => run(() => apollo.changeLane(left: false)),
            ),
          ],
        ),
      ],
    );
  }
}

class _SimulationSection extends StatelessWidget {
  const _SimulationSection({required this.apollo, required this.state});

  final ApolloService apollo;
  final ApolloState state;

  @override
  Widget build(BuildContext context) {
    final dv = state.dreamview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Simulation'),
        _Card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sim Control'),
                subtitle: const Text(
                  'Dreamview simulates the car following Apollo\'s plan. '
                  'Turn off when driving with the CARLA bridge.',
                ),
                value: dv.simControl,
                onChanged: !dv.canSimControl || apollo.isPending('sim_control')
                    ? null
                    : (on) async => apolloAction(
                          context,
                          apollo.setSimControl(on),
                        ),
              ),
              const Divider(height: 18),
              Row(children: [
                const Expanded(
                  child: Text(
                    'Return the car to the map\'s start point',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: dv.simControl && !apollo.isPending('start_point')
                      ? () async => apolloAction(
                            context,
                            apollo.setStartPoint(),
                            success: 'Car reset to start point',
                          )
                      : null,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset car'),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({required this.apollo, required this.state});

  final ApolloService apollo;
  final ApolloState state;

  @override
  Widget build(BuildContext context) {
    final dv = state.dreamview;
    final busy = apollo.isPending('map');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'HD Map',
          trailing: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final map in dv.maps)
              ChoiceChip(
                label: Text(map),
                selected: map == dv.map,
                onSelected: busy
                    ? null
                    : (_) async => map == dv.map
                        ? null
                        : apolloAction(
                            context,
                            apollo.changeMap(map),
                            success: 'Switched to $map',
                          ),
              ),
          ],
        ),
        if (dv.modes.length > 1) ...[
          const SizedBox(height: 14),
          const _SectionTitle('Dreamview mode'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in dv.modes)
                ChoiceChip(
                  label: Text(mode),
                  selected: mode == dv.mode,
                  onSelected: apollo.isPending('mode')
                      ? null
                      : (_) async => mode == dv.mode
                          ? null
                          : apolloAction(
                              context,
                              apollo.changeMode(mode),
                            ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ModulesSection extends StatelessWidget {
  const _ModulesSection({required this.apollo, required this.state});

  final ApolloService apollo;
  final ApolloState state;

  static const _icons = <String, IconData>{
    'Planning': Icons.route_rounded,
    'Control': Icons.sports_motorsports_rounded,
    'Prediction': Icons.insights_rounded,
    'Perception': Icons.visibility_rounded,
    'Localization': Icons.my_location_rounded,
    'Canbus': Icons.cable_rounded,
    'GPS': Icons.satellite_alt_rounded,
    'Transform': Icons.transform_rounded,
    'TrafficLight': Icons.traffic_rounded,
    'Guardian': Icons.shield_outlined,
    'TaskManager': Icons.checklist_rounded,
    'Lane': Icons.view_week_outlined,
    'IndoorLocalization': Icons.home_work_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final modules = state.dreamview.modules;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'Apollo modules',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(
              onPressed: apollo.isPending('setup')
                  ? null
                  : () async => apolloAction(
                        context,
                        apollo.setupAllModules(),
                        success: 'Starting all modules',
                      ),
              child: const Text('Start all'),
            ),
            TextButton(
              onPressed: apollo.isPending('reset_mode')
                  ? null
                  : () async => apolloAction(
                        context,
                        apollo.resetAllModules(),
                        success: 'Stopping all modules',
                      ),
              child: const Text('Stop all'),
            ),
          ]),
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.18,
          children: [
            for (final entry in modules.entries)
              ControlTile(
                icon: _icons[entry.key] ?? Icons.memory_rounded,
                label: entry.key,
                active: entry.value,
                onTap: apollo.isPending('module:${entry.key}')
                    ? null
                    : () async => apolloAction(
                          context,
                          apollo.setModule(entry.key, running: !entry.value),
                        ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TelemetrySection extends StatelessWidget {
  const _TelemetrySection({required this.state});

  final ApolloState state;

  @override
  Widget build(BuildContext context) {
    final v = state.vehicle;
    final scheme = Theme.of(context).colorScheme;

    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
        );

    Widget bar(String label, double? pct, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(
                width: 70,
                child: Text(label, style: const TextStyle(fontSize: 12))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: pct == null ? 0 : (pct.abs() / 100).clamp(0.0, 1.0),
                  color: color,
                  backgroundColor: scheme.surface,
                ),
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                pct == null ? '—' : '${pct.toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Live telemetry'),
        _Card(
          child: Column(
            children: [
              Row(children: [
                stat('Speed', '${v.speedKph.toStringAsFixed(1)} km/h'),
                stat('Gear', v.gear ?? '—'),
                stat('Mode', AutopilotFormat.pretty(v.drivingMode)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                stat(
                    'Position',
                    v.pose == null
                        ? '—'
                        : '${v.pose!.x.toStringAsFixed(1)}, ${v.pose!.y.toStringAsFixed(1)}'),
                stat('Planner',
                    AutopilotFormat.pretty(state.autopilot.decision)),
                stat('Obstacles', '${state.scene.obstacles.length}'),
              ]),
              const SizedBox(height: 12),
              bar('Throttle', v.throttlePct, AutopilotFormat.driving),
              bar('Brake', v.brakePct, AppColors.alert),
              bar('Steering', v.steeringPct, scheme.primary),
            ],
          ),
        ),
      ],
    );
  }
}
