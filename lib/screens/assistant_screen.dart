import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Opens when the assistant icon in the bottom dock is tapped.
class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.auto_awesome_rounded,
      title: 'Assistant',
      subtitle: 'Ask me anything about your car',
    );
  }
}
