import 'package:flutter/material.dart';
import '../../models/setting_item.dart';
import '../../widgets/settings/settings_sidebar.dart';
import '../../widgets/settings/settings_content.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.embedded,
    required this.onClose,
  });

  final bool embedded;
  final VoidCallback? onClose;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int selectedIndex = 0;

  static const settings = [
    SettingItem(Icons.tune_rounded, 'Controls'),
    SettingItem(Icons.speed_rounded, 'Dynamics'),
    SettingItem(Icons.bolt_rounded, 'Charging'),
    SettingItem(Icons.route_rounded, 'Autopilot'),
    SettingItem(Icons.lock_outline_rounded, 'Locks'),
    SettingItem(Icons.light_mode_outlined, 'Lights'),
    SettingItem(Icons.airline_seat_recline_normal_rounded, 'Seats'),
    SettingItem(Icons.monitor_outlined, 'Display'),
    SettingItem(Icons.schedule_rounded, 'Schedule'),
    SettingItem(Icons.health_and_safety_outlined, 'Safety'),
    SettingItem(Icons.build_outlined, 'Service'),
    SettingItem(Icons.system_update_alt_rounded, 'Software'),
  ];

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: const Color(0xFFF7F7F6),
      child: Column(
        children: [
          if (widget.embedded) const SizedBox(height: 72),
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
                      fillColor: const Color(0xFFF0F0EF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: widget.onClose ??
                      () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                SettingsSidebar(
                  items: settings,
                  selectedIndex: selectedIndex,
                  onSelect: (index) =>
                      setState(() => selectedIndex = index),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: SettingsContent(
                      key: ValueKey(selectedIndex),
                      title: settings[selectedIndex].label,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F6),
      body: SafeArea(child: content),
    );
  }
}
