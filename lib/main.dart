import 'package:flutter/material.dart';

import 'screens/vehicle_dashboard.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const VehicleTabletApp());
}

/// Root widget. Only responsible for MaterialApp/theme setup —
/// the actual UI lives in [VehicleDashboard] and its imported pieces.
class VehicleTabletApp extends StatefulWidget {
  const VehicleTabletApp({super.key});

  @override
  State<VehicleTabletApp> createState() => _VehicleTabletAppState();
}

class _VehicleTabletAppState extends State<VehicleTabletApp> {
  ThemeMode themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vehicle Tablet UI',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: VehicleDashboard(
        isDarkMode: themeMode == ThemeMode.dark,
        onThemeChanged: (isDark) {
          setState(() {
            themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
          });
        },
      ),
    );
  }
}
