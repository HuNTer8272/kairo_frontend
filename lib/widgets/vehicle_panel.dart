import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/apollo/apollo_service.dart';
import '../services/spotify/spotify_service.dart';
import 'apollo/autopilot_card.dart';
import 'apollo/body_controls.dart';
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
    required this.onOpenNavigation,
    required this.onNavigateHome,
    required this.onNavigateWork,
    required this.spotify,
    required this.onOpenMusic,
    required this.apollo,
    required this.onOpenAutopilotSettings,
  });

  final bool compact;
  final VoidCallback onOpenSettings;

  /// Opens the full navigation screen (search bar tap, map icon, etc).
  final VoidCallback onOpenNavigation;

  /// Quick actions from the dashboard's Navigate card: launch straight to
  /// the saved Home/Work address, or open the navigation screen to set one
  /// if it isn't saved yet.
  final VoidCallback onNavigateHome;
  final VoidCallback onNavigateWork;
  final SpotifyService spotify;
  final VoidCallback onOpenMusic;
  final ApolloService apollo;
  final VoidCallback onOpenAutopilotSettings;

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
                child: BodyStatusIcons(apollo: apollo, compact: compact),
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
                  child: ClosureLabel(
                    apollo: apollo,
                    field: 'frunk_open',
                    name: 'Frunk',
                    alignRight: false,
                  ),
                ),
                Positioned(
                  right: w * 0.23,
                  top: h * 0.33,
                  child: ClosureLabel(
                    apollo: apollo,
                    field: 'trunk_open',
                    name: 'Trunk',
                    alignRight: true,
                  ),
                ),
                Positioned(
                  left: w * 0.50 - 20,
                  top: h * 0.18,
                  child: LockToggle(apollo: apollo),
                ),
                Positioned(
                  right: 24,
                  top: h * 0.12,
                  child: AutopilotCard(
                    apollo: apollo,
                    onOpenNavigation: onOpenNavigation,
                    onOpenSettings: onOpenAutopilotSettings,
                  ),
                ),
                Positioned(
                  left: w * 0.29,
                  right: w * 0.18,
                  bottom: h * 0.03,
                  child: _HomeCards(
                    onOpenNavigation: onOpenNavigation,
                    onNavigateHome: onNavigateHome,
                    onNavigateWork: onNavigateWork,
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

class _HomeCards extends StatelessWidget {
  const _HomeCards({
    required this.onOpenNavigation,
    required this.onNavigateHome,
    required this.onNavigateWork,
    required this.spotify,
    required this.onOpenMusic,
  });

  final VoidCallback onOpenNavigation;
  final VoidCallback onNavigateHome;
  final VoidCallback onNavigateWork;
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
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.search_rounded),
                  title: const Text('Navigate'),
                  onTap: onOpenNavigation,
                ),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onNavigateHome,
                          icon: const Icon(Icons.home_rounded),
                          label: const Text('Home'),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onNavigateWork,
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
