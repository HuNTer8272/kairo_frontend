import 'package:flutter/material.dart';

import '../../models/apollo_state.dart';
import '../../services/apollo/apollo_service.dart';
import '../common/control_tile.dart';
import '../common/segmented_row.dart';
import 'apollo_selector.dart';
import 'autopilot_format.dart';

/// Settings > Controls / Lights / Locks, bound to the vehicle's body
/// controller through the gateway. Same layout as the rest of the settings
/// pages: the light-mode row, then a grid of toggle tiles.
class VehicleControlsSettings extends StatefulWidget {
  const VehicleControlsSettings({
    super.key,
    required this.apollo,
    required this.category,
  });

  final ApolloService apollo;

  /// 'Controls', 'Lights' or 'Locks'.
  final String category;

  static const categories = {'Controls', 'Lights', 'Locks'};

  @override
  State<VehicleControlsSettings> createState() =>
      _VehicleControlsSettingsState();
}

class _VehicleControlsSettingsState extends State<VehicleControlsSettings> {
  static const _lightModes = ['OFF', 'PARKING', 'ON', 'AUTO'];
  double _brightness = 0.72; // screen brightness stays a tablet setting

  ApolloService get apollo => widget.apollo;

  void _set(BuildContext context, Map<String, dynamic> patch) {
    if (!apollo.isLive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vehicle offline — connect in Settings > Autopilot'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    apolloAction(context, apollo.setBody(patch));
  }

  @override
  Widget build(BuildContext context) {
    return ApolloSelector<(bool, BodyState)>(
      apollo: apollo,
      selector: (a) => (a.isLive, a.state?.body ?? const BodyState()),
      builder: (context, v) {
        final body = v.$2;
        final tiles = _tiles(context, body);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.category,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              if (!v.$1) ...[
                const SizedBox(height: 6),
                Text(
                  'Vehicle offline — showing the last known state.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (widget.category != 'Locks') ...[
                SegmentedRow(
                  labels: const ['Off', 'Parking', 'On', 'Auto'],
                  selected: _lightModes.indexOf(body.lights),
                  onTap: (i) => _set(context, {'lights': _lightModes[i]}),
                ),
                const SizedBox(height: 18),
              ],
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.18,
                children: tiles,
              ),
              if (widget.category == 'Controls') ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Icon(Icons.brightness_low_rounded),
                    Expanded(
                      child: Slider(
                        value: _brightness,
                        onChanged: (value) =>
                            setState(() => _brightness = value),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _tiles(BuildContext context, BodyState b) {
    Widget toggle(IconData icon, String label, String field) => ControlTile(
          icon: icon,
          label: label,
          active: b.flag(field),
          onTap: () => _set(context, {field: !b.flag(field)}),
        );

    final horn = ControlTile(
      icon: Icons.campaign_outlined,
      label: 'Horn',
      active: b.horn,
      onTap: () => apollo.isLive
          ? apolloAction(context, apollo.honk())
          : _set(context, const {}),
    );
    final hazards = toggle(Icons.warning_amber_rounded, 'Hazards', 'hazards');

    return switch (widget.category) {
      'Lights' => [
          toggle(Icons.highlight_rounded, 'High Beam', 'high_beam'),
          hazards,
          ControlTile(
            icon: Icons.turn_left_rounded,
            label: 'Left Signal',
            active: b.turnSignal == 'LEFT',
            onTap: () => _set(context,
                {'turn_signal': b.turnSignal == 'LEFT' ? 'NONE' : 'LEFT'}),
          ),
          ControlTile(
            icon: Icons.turn_right_rounded,
            label: 'Right Signal',
            active: b.turnSignal == 'RIGHT',
            onTap: () => _set(context,
                {'turn_signal': b.turnSignal == 'RIGHT' ? 'NONE' : 'RIGHT'}),
          ),
          horn,
        ],
      'Locks' => [
          ControlTile(
            icon: b.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
            label: b.locked ? 'Locked' : 'Unlocked',
            active: b.locked,
            onTap: () => _set(context, {'locked': !b.locked}),
          ),
          toggle(Icons.directions_car_outlined, 'Frunk', 'frunk_open'),
          toggle(Icons.luggage_outlined, 'Trunk', 'trunk_open'),
          toggle(Icons.ev_station_outlined, 'Charge Port', 'charge_port_open'),
          toggle(Icons.child_care_rounded, 'Child Lock', 'child_lock'),
          toggle(Icons.window_rounded, 'Window Lock', 'window_lock'),
          toggle(Icons.back_hand_outlined, 'Glovebox', 'glovebox_open'),
        ],
      _ => [
          toggle(Icons.flip_rounded, 'Fold Mirrors', 'mirrors_folded'),
          toggle(Icons.lock_outline_rounded, 'Child Lock', 'child_lock'),
          toggle(Icons.window_rounded, 'Window Lock', 'window_lock'),
          toggle(Icons.back_hand_outlined, 'Glovebox', 'glovebox_open'),
          toggle(Icons.videocam_outlined, 'Recording', 'dashcam'),
          toggle(Icons.local_car_wash_outlined, 'Car Wash', 'car_wash'),
          toggle(Icons.adjust_rounded, 'Sentry', 'sentry'),
          toggle(Icons.headset_mic_outlined, 'Neutral Tow', 'neutral_tow'),
          hazards,
          horn,
        ],
    };
  }
}
