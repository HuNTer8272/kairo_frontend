import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the light and dark [ThemeData] from [AppColors], so every
/// Material widget (switches, sliders, filled/text buttons, focused fields,
/// selected list tiles) picks up the warm-white accent automatically.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Neutral variant keeps greys free of any leftover hue; the accent
    // roles are then overridden explicitly below.
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      surface: isDark ? AppColors.darkSurface : null,
    );

    final scheme = isDark
        ? base.copyWith(
            // Dark: accent is the foreground; fills are faint accent tints.
            primary: AppColors.accent,
            onPrimary: AppColors.onAccent,
            primaryContainer:
                Color.alphaBlend(AppColors.accentSoft, base.surface),
            onPrimaryContainer: AppColors.accent,
            secondary: AppColors.accent,
            onSecondary: AppColors.onAccent,
            secondaryContainer:
                Color.alphaBlend(AppColors.accentSoft, base.surface),
            onSecondaryContainer: AppColors.accent,
            surfaceTint: Colors.transparent,
          )
        : base.copyWith(
            // Light: accent has no contrast as a foreground, so it becomes
            // the selected-surface fill and accentInk carries icons/text.
            primary: AppColors.accentInk,
            onPrimary: AppColors.accent,
            primaryContainer: AppColors.accent,
            onPrimaryContainer: AppColors.accentInk,
            secondary: AppColors.accentInk,
            onSecondary: AppColors.accent,
            secondaryContainer: AppColors.accent,
            onSecondaryContainer: AppColors.accentInk,
            surfaceTint: Colors.transparent,
          );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      fontFamily: 'Roboto',
      colorScheme: scheme,
    );
  }
}
