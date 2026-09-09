import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Opens when the voice/equalizer icon in the bottom dock is tapped.
class VoiceScreen extends StatelessWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.graphic_eq_rounded,
      title: 'Voice',
      subtitle: 'Tap the mic to speak a command',
    );
  }
}
