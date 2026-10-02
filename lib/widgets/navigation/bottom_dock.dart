import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/nav_item.dart';

class BottomDock extends StatelessWidget {
  const BottomDock({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111111),
      child: Row(
        children: [
          const SizedBox(width: 22),
          const Icon(Icons.chevron_left_rounded, color: Colors.white54),
          const SizedBox(width: 5),
          const Text('22°',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w400,
              )),
          const Spacer(),
          ...List.generate(items.length, (index) {
            final selected = index == selectedIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Tooltip(
                message: items[index].label,
                child: IconButton(
                  onPressed: () => onSelected(index),
                  icon: Icon(
                    items[index].icon,
                    color: selected ? AppColors.accent : Colors.white70,
                    size: 25,
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          const Text('22°',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w400,
              )),
          const SizedBox(width: 5),
          const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          const SizedBox(width: 30),
          const Icon(Icons.volume_up_rounded, color: Colors.white70),
          const SizedBox(width: 28),
        ],
      ),
    );
  }
}
