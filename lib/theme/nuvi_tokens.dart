import 'package:flutter/material.dart';

/// Design tokens — **Phase 0 stubs**.
///
/// The full black-and-white system is defined in Phase 7B. These placeholders
/// exist now so screens built before then inherit the token names rather than
/// scattering literal colours and paddings that later have to be hunted down.
///
/// Rules that will not change in 7B:
/// * The palette is monochrome. No hue, no accent colour.
/// * Nothing addresses a colour directly; screens read a token.
/// * Spacing is a 4pt scale.
///
/// Exact values, elevation, motion and dark-mode mapping are 7B's to decide.
abstract final class NuviColors {
  // Monochrome ramp. Names are stable; values are provisional.
  static const Color black = Color(0xFF000000);
  static const Color ink900 = Color(0xFF111111);
  static const Color ink700 = Color(0xFF333333);
  static const Color ink500 = Color(0xFF666666);
  static const Color ink300 = Color(0xFF999999);
  static const Color ink200 = Color(0xFFCCCCCC);
  static const Color ink100 = Color(0xFFE5E5E5);
  static const Color ink50 = Color(0xFFF5F5F5);
  static const Color white = Color(0xFFFFFFFF);

  // Semantic roles — screens use these, never the ramp directly.
  static const Color surface = white;
  static const Color surfaceMuted = ink50;
  static const Color onSurface = ink900;
  static const Color onSurfaceMuted = ink500;
  static const Color border = ink200;
  static const Color primary = black;
  static const Color onPrimary = white;
  static const Color disabled = ink300;

  // Even state colours stay monochrome; meaning is carried by icon and copy,
  // not by hue. Revisit in 7B alongside the accessibility review.
  static const Color danger = ink900;
  static const Color success = ink900;
}

/// 4pt spacing scale.
abstract final class NuviSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class NuviRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 16;
  static const double pill = 999;
}

/// Type scale. The family is chosen in 7B; `null` means "platform default"
/// until then.
abstract final class NuviTypography {
  static const String? fontFamily = null;

  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: NuviColors.onSurface,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: NuviColors.onSurface,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: NuviColors.onSurface,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: NuviColors.onSurfaceMuted,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );
}
