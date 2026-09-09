import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Opens when the theater/movie icon in the bottom dock is tapped.
class TheaterScreen extends StatelessWidget {
  const TheaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.movie_rounded,
      title: 'Theater',
      subtitle: 'Available while parked',
    );
  }
}
