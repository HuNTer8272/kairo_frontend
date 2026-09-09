import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Opens when the phone icon in the bottom dock is tapped.
class PhoneScreen extends StatelessWidget {
  const PhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      icon: Icons.phone_rounded,
      title: 'Phone',
      subtitle: 'No device connected',
    );
  }
}
