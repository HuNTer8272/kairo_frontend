import 'package:flutter/material.dart';

import 'screens/vehicle_dashboard.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F4F2),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF087E8B),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF111416),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF55D6BE),
          brightness: Brightness.dark,
          surface: const Color(0xFF1A1F21),
        ),
      ),
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
