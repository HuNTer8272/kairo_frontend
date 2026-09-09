import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

class VehicleApp extends StatelessWidget {
  const VehicleApp({super.key});

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
          seedColor: const Color(0xFF246BFD),
          brightness: Brightness.light,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
