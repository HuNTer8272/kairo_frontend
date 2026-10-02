import 'package:flutter/material.dart';

import '../data/dock_items.dart';
import '../theme/app_colors.dart';

/// The black dock pinned to the bottom of the screen. Purely presentational —
/// [VehicleDashboard] decides what happens when an icon is tapped.
class BottomDock extends StatelessWidget {
  const BottomDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onBack,
    required this.onForward,
    required this.canGoBack,
    required this.canGoForward,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final bool canGoBack;
  final bool canGoForward;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.dockBackground,
      child: Row(
        children: [
          const SizedBox(width: 22),
          IconButton(
            tooltip: 'Back',
            onPressed: canGoBack ? onBack : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.dockIcon,
            disabledColor: AppColors.dockIconDisabled,
          ),
          const SizedBox(width: 5),
          const Text(
            '22°',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          ...List.generate(kDockItems.length, (index) {
            final selected = selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: IconButton(
                onPressed: () => onSelected(index),
                style: IconButton.styleFrom(
                  backgroundColor: selected ? AppColors.dockSelectedFill : null,
                ),
                icon: Icon(
                  kDockItems[index].icon,
                  color: selected ? AppColors.accent : AppColors.dockIcon,
                  size: 25,
                ),
              ),
            );
          }),
          const Spacer(),
          // const Text(
          //   '22°',
          //   style: TextStyle(
          //     color: Colors.white,
          //     fontSize: 26,
          //     fontWeight: FontWeight.w400,
          //   ),
          // ),
          const SizedBox(width: 5),
          IconButton(
            tooltip: 'Forward',
            onPressed: canGoForward ? onForward : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.dockIcon,
            disabledColor: AppColors.dockIconDisabled,
          ),
          const SizedBox(width: 30),
          const Icon(Icons.volume_up_rounded, color: AppColors.dockIcon),
          const SizedBox(width: 28),
        ],
      ),
    );
  }
}
