import 'package:flutter/material.dart';
import '../models/nav_item.dart';
import '../widgets/home/vehicle_home_view.dart';
import '../widgets/navigation/bottom_dock.dart';
import '../widgets/top_status_bar.dart';
import 'phone_screen.dart';
import 'audio_screen.dart';
import 'bluetooth_screen.dart';
import 'media_screen.dart';
import 'assistant_screen.dart';
import 'video_screen.dart';
import 'settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool settingsOpen = false;
  int selectedDockItem = 0;

  static const navItems = [
    NavItem(icon: Icons.directions_car_filled_rounded, label: 'Vehicle'),
    NavItem(icon: Icons.phone_rounded, label: 'Phone'),
    NavItem(icon: Icons.graphic_eq_rounded, label: 'Audio'),
    NavItem(icon: Icons.bluetooth_rounded, label: 'Bluetooth'),
    NavItem(icon: Icons.music_note_rounded, label: 'Media'),
    NavItem(icon: Icons.auto_awesome_rounded, label: 'Assistant'),
    NavItem(icon: Icons.movie_rounded, label: 'Video'),
    NavItem(icon: Icons.apps_rounded, label: 'Apps'),
  ];

  void _onNavTap(int index) {
    if (index == 0) {
      setState(() {
        selectedDockItem = 0;
        settingsOpen = false;
      });
      return;
    }

    setState(() => selectedDockItem = index);

    final Widget page = switch (index) {
      1 => const PhoneScreen(),
      2 => const AudioScreen(),
      3 => const BluetoothScreen(),
      4 => const MediaScreen(),
      5 => const AssistantScreen(),
      6 => const VideoScreen(),
      7 => const SettingsScreen(embedded: false, onClose: null),
      _ => const PhoneScreen(),
    };

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, __) => page,
        transitionsBuilder: (_, animation, __, child) {
          final slide = Tween<Offset>(
            begin: const Offset(.08, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dockHeight = constraints.maxHeight * .105;
            final topBarHeight = constraints.maxHeight * .075;

            return Stack(
              children: [
                Positioned.fill(
                  bottom: dockHeight,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: VehicleHomeView(
                            settingsOpen: settingsOpen,
                            onOpenSettings: () =>
                                setState(() => settingsOpen = true),
                          ),
                        ),
                        if (settingsOpen)
                          Positioned(
                            left: constraints.maxWidth * .38,
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: SettingsScreen(
                              embedded: true,
                              onClose: () =>
                                  setState(() => settingsOpen = false),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0, right: 0, top: 0, height: topBarHeight,
                  child: const TopStatusBar(),
                ),
                Positioned(
                  left: 0, right: 0, bottom: 0, height: dockHeight,
                  child: BottomDock(
                    items: navItems,
                    selectedIndex: selectedDockItem,
                    onSelected: _onNavTap,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
