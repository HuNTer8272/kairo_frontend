import 'package:flutter/material.dart';

/// Single source of truth for the app's colour tokens.
///
/// [accent] is a warm white (#E1E1D6). It is too light to use as text on
/// light surfaces, so it is paired with:
/// - [onAccent]: text/icons drawn on a solid accent fill.
/// - [accentInk]: the accent's foreground stand-in on light surfaces.
/// - [accentSoft] / [accentBorder]: translucent tints for selected
///   surfaces and outlines on dark backgrounds.
///
/// Widgets should normally read these through `Theme.of(context).colorScheme`
/// (see `app_theme.dart`). Use the raw tokens only where a surface's
/// colour does not follow the theme, like the always-black bottom dock.
abstract final class AppColors {
  // Accent
  static const Color accent = Color(0xFFE1E1D6);
  static const Color onAccent = Color(0xFF16171A);
  static const Color accentInk = Color(0xFF3A3A33);
  static const Color accentSoft = Color(0x1FE1E1D6); // accent @ 12%
  static const Color accentBorder = Color(0x8CE1E1D6); // accent @ 55%

  // Backgrounds (unchanged from the original theme)
  static const Color lightBackground = Color(0xFFF4F4F2);
  static const Color darkBackground = Color(0xFF111416);
  static const Color darkSurface = Color(0xFF1A1F21);

  // Bottom dock (always dark, independent of theme mode)
  static const Color dockBackground = Color(0xFF111111);
  static const Color dockIcon = Color(0xB3FFFFFF); // white70
  static const Color dockIconDisabled = Color(0x3DFFFFFF); // white24
  static const Color dockSelectedFill = Color(0x1AE1E1D6); // accent @ 10%

  // Semantic status colours (not accents)
  static const Color alert = Color(0xFFCE293A);
}
