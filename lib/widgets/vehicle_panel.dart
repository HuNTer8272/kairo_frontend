import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/spotify/spotify_service.dart';
import '../theme/app_colors.dart';
import 'media/spotify_mini_player.dart';
import 'vehicle_model_view.dart';

/// The left-hand "car view" — vehicle render, status icons, and either the
/// full home cards (music/navigate) or the compact tyre-pressure card,
/// depending on whether the settings sidebar is open.
class VehiclePanel extends StatelessWidget {
  const VehiclePanel({
    super.key,
    required this.compact,
    required this.onOpenSettings,
    required this.onNavigate,
    required this.spotify,
    required this.onOpenMusic,
  });

  final bool compact;
  final VoidCallback onOpenSettings;
  final VoidCallback onNavigate;
  final SpotifyService spotify;
  final VoidCallback onOpenMusic;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final scheme = Theme.of(context).colorScheme;

        return Container(
          color: scheme.surface,
          child: Stack(
            children: [
              Positioned(
                left: compact ? 18 : 22,
                top: compact ? h * 0.14 : h * 0.13,
                child: _VerticalStatusBar(compact: compact),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeInOutCubic,
                left: compact ? w * 0.08 : w * 0.10,
                right: compact ? w * 0.05 : w * 0.05,
                top: compact ? h * 0.24 : h * 0.16,
                height: compact ? h * 0.43 : h * 0.62,
                child: Hero(
                  tag: 'vehicle',
                  child: VehicleModelView(compact: compact),
                ),
              ),
              if (!compact) ...[
                Positioned(
                  left: w * 0.33,
                  top: h * 0.37,
                  child: const _VehicleActionLabel(
                    title: 'Open',
                    subtitle: 'Frunk',
                    alignRight: false,
                  ),
                ),
                Positioned(
                  right: w * 0.23,
                  top: h * 0.33,
                  child: const _VehicleActionLabel(
                    title: 'Trunk',
                    subtitle: 'Open',
                    alignRight: true,
                  ),
                ),
                Positioned(
                  left: w * 0.50,
                  top: h * 0.20,
                  child: const Column(
                    children: [
                      Icon(Icons.lock_open_rounded, size: 25),
                      SizedBox(height: 4),
                      SizedBox(
                        height: 68,
                        child: VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Color(0xFFBFC2C5),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: w * 0.29,
                  right: w * 0.18,
                  bottom: h * 0.03,
                  child: _HomeCards(
                    onNavigate: onNavigate,
                    spotify: spotify,
                    onOpenMusic: onOpenMusic,
                  ),
                ),
              ] else ...[
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: const _TyrePressureCard(),
                ),
              ],
              Positioned(
                left: compact ? 18 : 20,
                bottom: compact ? h * 0.19 : h * 0.14,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onOpenSettings,
                    child: Ink(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(18),
                        // Accent outline while the settings panel is open.
                        border: Border.all(
                          color: compact
                              ? scheme.primary.withValues(alpha: 0.55)
                              : scheme.outlineVariant,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 16,
                            offset: Offset(0, 6),
                            color: Color(0x14000000),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.directions_car_filled_rounded,
                        color: compact ? scheme.primary : null,
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

class _VerticalStatusBar extends StatelessWidget {
  const _VerticalStatusBar({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(Icons.light_mode_rounded, color: scheme.primary),
        const SizedBox(height: 18),
        Icon(
          compact ? Icons.airline_seat_recline_normal : Icons.lightbulb_outline,
          color: const Color(0xFF929699),
        ),
        // const SizedBox(height: 18),
        // Icon(Icons.light_mode_rounded, color: scheme.primary),
        const SizedBox(height: 18),
        const Icon(Icons.airline_seat_recline_normal_rounded,
            color: AppColors.alert),
      ],
    );
  }
}

class _VehicleActionLabel extends StatelessWidget {
  const _VehicleActionLabel({
    required this.title,
    required this.subtitle,
    required this.alignRight,
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
        Container(
          width: 1,
          height: 60,
          color: const Color(0xFFBFC2C5),
        ),
        const SizedBox(width: 7),
        Text(
          '$title\n$subtitle',
          style: const TextStyle(
            fontSize: 12,
            height: 1.1,
            fontWeight: FontWeight.w600,
            color: Color(0xFF686A6D),
          ),
        ),
      ],
    );
  }
}

class _HomeCards extends StatelessWidget {
  const _HomeCards({
    required this.onNavigate,
    required this.spotify,
    required this.onOpenMusic,
  });

  final VoidCallback onNavigate;
  final SpotifyService spotify;
  final VoidCallback onOpenMusic;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: _GlassCard(
            child: SpotifyMiniPlayer(spotify: spotify, onOpen: onOpenMusic),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: _GlassCard(
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
                          onPressed: onNavigate,
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
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 118,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: const [
              BoxShadow(
                blurRadius: 20,
                offset: Offset(0, 10),
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

class _TyrePressureCard extends StatelessWidget {
  const _TyrePressureCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
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
              Text('42 psi', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Icon(Icons.directions_car_filled_rounded, size: 45),
              SizedBox(height: 8),
              Text('41 psi', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
