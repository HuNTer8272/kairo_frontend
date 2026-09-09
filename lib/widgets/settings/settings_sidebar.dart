import 'package:flutter/material.dart';
import '../../models/setting_item.dart';

class SettingsSidebar extends StatelessWidget {
  const SettingsSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<SettingItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 205,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 14, 10, 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = selectedIndex == index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: selected
                  ? const Color(0xFFE7E7E5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                leading: Icon(item.icon, size: 20),
                title: Text(item.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => onSelect(index),
              ),
            ),
          );
        },
      ),
    );
  }
}
