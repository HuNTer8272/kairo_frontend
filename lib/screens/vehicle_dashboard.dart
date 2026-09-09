import 'package:flutter/material.dart';

import '../data/dock_items.dart';
import '../data/settings_data.dart';
import '../widgets/bottom_dock.dart';
import '../widgets/settings_panel.dart';
import '../widgets/top_bar.dart';
import '../widgets/vehicle_panel.dart';
// import 'assistant_screen.dart';
import 'bluetooth_screen.dart';
import 'music_screen.dart';
import 'navigation_screen.dart';
import 'phone_screen.dart';

/// The persistent app shell: top bar + bottom dock never rebuild/animate
/// away, only the body content between them swaps based on which dock
/// icon is selected.
///
/// - Car icon (index 0): the vehicle view.
/// - Apps icon (last index): the vehicle view, slid over by the settings
///   sidebar — this is the sliding animation from the second screenshot,
///   and it is preserved exactly as it was before the refactor.
/// - Every other icon: its own full-page screen, each living in its own
///   file under screens/ (phone_screen.dart, music_screen.dart, ...).
class VehicleDashboard extends StatefulWidget {
  const VehicleDashboard({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<VehicleDashboard> createState() => _VehicleDashboardState();
}

class _VehicleDashboardState extends State<VehicleDashboard> {
  bool settingsOpen = false;
  bool navigationOpen = false;
  int selectedSetting = 0;
  int selectedDockItem = 0;
  final List<int> pageHistory = [0];
  int historyIndex = 0;

  int get _appsIndex => kDockItems.length - 1;

  void _onDockSelected(int index) {
    setState(() {
      selectedDockItem = index;
      navigationOpen = false;
      settingsOpen = index == _appsIndex;
      if (historyIndex < pageHistory.length - 1) {
        pageHistory.removeRange(historyIndex + 1, pageHistory.length);
      }
      pageHistory.add(index);
      historyIndex = pageHistory.length - 1;
    });
  }

  void _goBack() {
    setState(() {
      if (navigationOpen) {
        navigationOpen = false;
        return;
      }
      if (historyIndex == 0) return;
      historyIndex -= 1;
      selectedDockItem = pageHistory[historyIndex];
      settingsOpen = selectedDockItem == _appsIndex;
    });
  }

  void _goForward() {
    setState(() {
      if (historyIndex >= pageHistory.length - 1) return;
      historyIndex += 1;
      selectedDockItem = pageHistory[historyIndex];
      settingsOpen = selectedDockItem == _appsIndex;
    });
  }

  Widget _screenForIndex(int index) {
    switch (index) {
      case 1:
        return const PhoneScreen();
      // case 2:
      //   return const VoiceScreen();
      case 2:
        return const BluetoothScreen();
      case 3:
        return const MusicScreen();
      // case 5:
      //   return const AssistantScreen();
      // case 6:
      //   return const TheaterScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  /// The car view with the settings sidebar sliding over it — identical
  /// animation/timings to the original single-file implementation.
  Widget _buildVehicleAndSettings(double width) {
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeInOutCubic,
          left: 0,
          top: 0,
          bottom: 0,
          width: settingsOpen ? width * 0.38 : width,
          child: VehiclePanel(
            compact: settingsOpen,
            onOpenSettings: () => setState(() => settingsOpen = true),
            onNavigate: () => setState(() => navigationOpen = true),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeInOutCubic,
          left: settingsOpen ? width * 0.38 : width,
          top: 0,
          bottom: 0,
          width: width * 0.62,
          child: SettingsPanel(
            settings: kSettings,
            selectedIndex: selectedSetting,
            onSelect: (index) => setState(() => selectedSetting = index),
            onClose: () => setState(() => settingsOpen = false),
            isDarkMode: widget.isDarkMode,
            onThemeChanged: widget.onThemeChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(double width) {
    if (navigationOpen) {
      return NavigationScreen(onClose: () => setState(() => navigationOpen = false));
    }
    if (selectedDockItem == 0 || selectedDockItem == _appsIndex) {
      return _buildVehicleAndSettings(width);
    }
    return _screenForIndex(selectedDockItem);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final dockHeight = height * 0.105;
            final topBarHeight = height * 0.075;

            return Stack(
              children: [
                Positioned.fill(
                  bottom: dockHeight,
                  child: ClipRect(
                    child: _buildBody(width),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: topBarHeight,
                  child: TopBar(
                    compact: settingsOpen,
                    onProfileTap: () {},
                    isDarkMode: widget.isDarkMode,
                    onThemeChanged: widget.onThemeChanged,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: dockHeight,
                  child: BottomDock(
                    selectedIndex: selectedDockItem,
                    onSelected: _onDockSelected,
                    onBack: _goBack,
                    onForward: _goForward,
                    canGoBack: navigationOpen || historyIndex > 0,
                    canGoForward: historyIndex < pageHistory.length - 1,
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
