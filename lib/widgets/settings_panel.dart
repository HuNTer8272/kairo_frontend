import 'package:flutter/material.dart';

import '../models/setting_item.dart';
import 'common/control_tile.dart';
import 'common/segmented_row.dart';

/// The right-hand settings sidebar: search bar, category list, and the
/// detail content for whichever category is selected.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.selectedIndex,
    required this.onSelect,
    required this.onClose,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final List<SettingItem> settings;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 72),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search Settings',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 205,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 14, 10, 16),
                    itemCount: settings.length,
                    itemBuilder: (context, index) {
                      final item = settings[index];
                      final selected = selectedIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                            color: selected
                              ? scheme.secondaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                            leading: Icon(item.icon, size: 20),
                            title: Text(
                              item.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onTap: () => onSelect(index),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _ControlContent(
                      key: ValueKey(selectedIndex),
                      title: settings[selectedIndex].label,
                      isDarkMode: isDarkMode,
                      onThemeChanged: onThemeChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail body shown to the right of the settings category list
/// (headlight mode, the control-tile grid, brightness slider).
class _ControlContent extends StatefulWidget {
  const _ControlContent({
    super.key,
    required this.title,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final String title;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<_ControlContent> createState() => _ControlContentState();
}

class _ControlContentState extends State<_ControlContent> {
  bool headlights = true;
  bool mirrorsFolded = false;
  bool recording = true;
  double brightness = 0.72;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          if (widget.title == 'Display') ...[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark mode'),
              subtitle: const Text('Use a darker cockpit palette'),
              value: widget.isDarkMode,
              onChanged: widget.onThemeChanged,
            ),
            const SizedBox(height: 10),
          ],
          SegmentedRow(
            labels: const ['Off', 'Parking', 'On', 'Auto'],
            selected: headlights ? 3 : 0,
            onTap: (index) {
              setState(() => headlights = index != 0);
            },
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.18,
            children: [
              ControlTile(
                icon: Icons.flip_rounded,
                label: 'Fold Mirrors',
                active: mirrorsFolded,
                onTap: () => setState(() => mirrorsFolded = !mirrorsFolded),
              ),
              const ControlTile(
                icon: Icons.lock_outline_rounded,
                label: 'Child Lock',
              ),
              const ControlTile(
                icon: Icons.window_rounded,
                label: 'Window Lock',
              ),
              const ControlTile(
                icon: Icons.back_hand_outlined,
                label: 'Glovebox',
              ),
              const ControlTile(
                icon: Icons.flip_camera_android_rounded,
                label: 'Mirrors',
              ),
              ControlTile(
                icon: Icons.videocam_outlined,
                label: 'Recording',
                active: recording,
                onTap: () => setState(() => recording = !recording),
              ),
              const ControlTile(
                icon: Icons.local_car_wash_outlined,
                label: 'Car Wash',
              ),
              const ControlTile(
                icon: Icons.sports_motorsports_rounded,
                label: 'Steering',
              ),
              const ControlTile(
                icon: Icons.adjust_rounded,
                label: 'Sentry',
                active: true,
              ),
              const ControlTile(
                icon: Icons.headset_mic_outlined,
                label: 'Neutral Tow',
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Icon(Icons.brightness_low_rounded),
              Expanded(
                child: Slider(
                  value: brightness,
                  onChanged: (value) => setState(() => brightness = value),
                ),
              ),
              FilledButton(
                onPressed: () {},
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Text('Auto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
