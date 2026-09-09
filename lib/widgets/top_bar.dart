import 'package:flutter/material.dart';

/// The status row pinned to the top of the screen: gear indicator,
/// battery, lock/profile icons, clock, temperature, airbag chip.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.compact,
    required this.onProfileTap,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool compact;
  final VoidCallback onProfileTap;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Row(
          children: [
            const Text(
              'P R N D',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 2.4,
                color: Color(0xFF676A6D),
              ),
            ),
            const SizedBox(width: 24),
            const Icon(Icons.battery_5_bar_rounded, size: 23),
            const SizedBox(width: 6),
            const Text('80%', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
              onPressed: () => onThemeChanged(!isDarkMode),
              icon: Icon(isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
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
            const SizedBox(width: 28),
            const Text(
              '22°C',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
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
      ),
    );
  }
}
