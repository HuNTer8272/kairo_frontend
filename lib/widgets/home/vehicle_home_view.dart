import 'dart:ui';
import 'package:flutter/material.dart';

import '../vehicle_model_view.dart';

class VehicleHomeView extends StatelessWidget {
  const VehicleHomeView({
    super.key,
    required this.settingsOpen,
    required this.onOpenSettings,
  });

  final bool settingsOpen;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Container(
          color: const Color(0xFFF4F4F2),
          child: Stack(
            children: [
              Positioned(
                left: 18,
                top: settingsOpen ? h * .14 : h * .13,
                child: const VehicleStatusRail(),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeInOutCubic,
                left: settingsOpen ? w * .06 : w * .20,
                right: settingsOpen ? w * .05 : w * .13,
                top: settingsOpen ? h * .23 : h * .25,
                height: settingsOpen ? h * .45 : h * .49,
                child: const VehicleModelView(),
              ),
              if (!settingsOpen) ...[
                Positioned(
                  left: w * .33, top: h * .37,
                  child: const VehicleActionLabel(
                    title: 'Open', subtitle: 'Frunk',
                  ),
                ),
                Positioned(
                  right: w * .23, top: h * .33,
                  child: const VehicleActionLabel(
                    title: 'Trunk', subtitle: 'Open', alignRight: true,
                  ),
                ),
                Positioned(
                  left: w * .50, top: h * .20,
                  child: const Column(
                    children: [
                      Icon(Icons.lock_open_rounded, size: 25),
                      SizedBox(height: 4),
                      SizedBox(
                        height: 68,
                        child: VerticalDivider(
                          width: 1, thickness: 1,
                          color: Color(0xFFBFC2C5),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: w * .29, right: w * .18, bottom: h * .03,
                  child: const HomeCards(),
                ),
              ] else
                const Positioned(
                  left: 18, right: 18, bottom: 18,
                  child: TyrePressureCard(),
                ),
              Positioned(
                left: 18,
                bottom: settingsOpen ? h * .19 : h * .14,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onOpenSettings,
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .82),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE1E1E1)),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 16, offset: Offset(0, 6),
                            color: Color(0x14000000),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_car_filled_rounded,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class VehicleStatusRail extends StatelessWidget {
  const VehicleStatusRail({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.light_mode_rounded, color: Color(0xFF40B987)),
        SizedBox(height: 18),
        Icon(Icons.lightbulb_outline, color: Color(0xFF929699)),
        SizedBox(height: 18),
        Icon(Icons.light_mode_rounded, color: Color(0xFF40B987)),
        SizedBox(height: 18),
        Icon(Icons.airline_seat_recline_normal_rounded,
            color: Color(0xFFCE293A)),
      ],
    );
  }
}

class VehicleActionLabel extends StatelessWidget {
  const VehicleActionLabel({
    super.key,
    required this.title,
    required this.subtitle,
    this.alignRight = false,
  });

  final String title;
  final String subtitle;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 1, height: 60, color: const Color(0xFFBFC2C5)),
        const SizedBox(width: 7),
        Text(
          '$title\n$subtitle',
          style: const TextStyle(
            fontSize: 12, height: 1.1, fontWeight: FontWeight.w600,
            color: Color(0xFF686A6D),
          ),
        ),
      ],
    );
  }
}

class HomeCards extends StatelessWidget {
  const HomeCards({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(flex: 6, child: MusicCard()),
        SizedBox(width: 12),
        Expanded(flex: 4, child: NavigateCard()),
      ],
    );
  }
}

class MusicCard extends StatelessWidget {
  const MusicCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const ListTile(
            dense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            leading: CircleAvatar(
              backgroundColor: Color(0xFF2E2B32),
              child: Icon(Icons.music_note_rounded, color: Colors.white),
            ),
            title: Text('Vampire',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Olivia Rodrigo'),
          ),
          const Divider(height: 1),
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(Icons.skip_previous_rounded, size: 20),
                Icon(Icons.play_arrow_rounded, size: 22),
                Icon(Icons.skip_next_rounded, size: 20),
                Icon(Icons.tune_rounded, size: 20),
                Icon(Icons.search_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NavigateCard extends StatelessWidget {
  const NavigateCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const ListTile(
            dense: true,
            leading: Icon(Icons.search_rounded),
            title: Text('Navigate'),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Home'),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.work_rounded),
                    label: const Text('Work'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 118,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD9D9D9)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 20, offset: Offset(0, 10),
                color: Color(0x10000000),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class TyrePressureCard extends StatelessWidget {
  const TyrePressureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E1E1)),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'Tyre Pressure\n\nRecommended\nFront: 42 psi\nRear: 42 psi',
              style: TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
          Column(
            children: [
              Text('42 psi',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Icon(Icons.directions_car_filled_rounded, size: 45),
              SizedBox(height: 8),
              Text('41 psi',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

