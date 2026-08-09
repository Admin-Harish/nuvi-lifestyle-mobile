import 'package:flutter/material.dart';

import 'nuvi_tokens.dart';

/// The app's [ThemeData], assembled from [NuviColors] and friends.
///
/// Phase 0 stub: enough for later screens to inherit the right defaults
/// without ever naming a literal colour. Phase 7B replaces the values,
/// not the structure.
abstract final class NuviTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: NuviColors.primary,
      onPrimary: NuviColors.onPrimary,
      secondary: NuviColors.ink700,
      onSecondary: NuviColors.white,
      error: NuviColors.danger,
      onError: NuviColors.white,
      surface: NuviColors.surface,
      onSurface: NuviColors.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: NuviTypography.fontFamily,
      scaffoldBackgroundColor: NuviColors.surface,
      dividerColor: NuviColors.border,
      textTheme: const TextTheme(
        displayLarge: NuviTypography.displayLarge,
        titleLarge: NuviTypography.titleLarge,
        bodyLarge: NuviTypography.bodyLarge,
        bodyMedium: NuviTypography.bodyMedium,
        labelLarge: NuviTypography.labelLarge,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NuviColors.surface,
        foregroundColor: NuviColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NuviColors.primary,
          foregroundColor: NuviColors.onPrimary,
          disabledBackgroundColor: NuviColors.disabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NuviRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NuviSpacing.xl,
            vertical: NuviSpacing.md,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NuviColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NuviRadius.md),
          borderSide: const BorderSide(color: NuviColors.border),
        ),
        contentPadding: const EdgeInsets.all(NuviSpacing.lg),
      ),
    );
  }

  /// Dark mode is a Phase 7B decision. Returning the light theme for now keeps
  /// the app visually consistent instead of inventing a palette that 7B would
  /// have to undo.
  static ThemeData get dark => light;
}
