import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Opens when the music icon in the bottom dock is tapped.
class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.music_note_rounded,
      title: 'Music',
      subtitle: 'Nothing playing',
    );
  }
}
