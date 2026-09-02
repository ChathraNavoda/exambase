import 'package:flutter/material.dart';

/// ExamBase brand palette.
///
/// Base colors are the four given brand values (deep blue + two darker
/// shades + neutral) plus white and the three semantic states. Everything
/// else (surface tints, borders, disabled states) is derived from these six
/// so the palette stays coherent instead of accumulating one-off hex values
/// as new screens get built.
class AppColors {
  AppColors._();

  // ---- Brand ----
  /// Primary brand blue. CTAs, links, active states, focus rings.
  static const Color primary = Color(0xFF01579B);

  /// One step darker. Pressed states, headings that want brand weight.
  static const Color primaryDark = Color(0xFF02365E);

  /// Darkest brand shade. Reserved for text that should read as "brand
  /// navy" rather than plain black (see [textPrimary]).
  static const Color primaryDarkest = Color(0xFF011D33);

  /// Backward-compatible alias — existing screens reference this name.
  static const Color primaryBlue = primary;

  // ---- Neutral ----
  static const Color neutral = Color(0xFF8B969E);

  // ---- Semantic ----
  static const Color success = Color(0xFF239E27);
  static const Color warning = Color(0xFFF0B032);
  static const Color error = Color(0xFFB31722);

  // ---- Surfaces ----
  static const Color background = Colors.white;
  static const Color surface = Colors.white;

  /// A very subtle off-white, used sparingly for input fills and quiet
  /// section backgrounds so they read as distinct from cards without
  /// darkening the overall canvas away from white.
  static const Color surfaceAlt = Color(0xFFF6F8F9);

  // ---- Text ----
  /// Primary text uses the darkest brand shade instead of pure black —
  /// a small, consistent way the brand shows up in body copy.
  static const Color textPrimary = primaryDarkest;
  static const Color textSecondary = neutral;
  static const Color textTertiary = Color(0xFFB7BFC5);
  static const Color onPrimary = Colors.white;

  // ---- Borders / dividers ----
  static const Color border = Color(0xFFE1E5E8);
  static const Color divider = Color(0xFFEDEFF1);

  // ---- Semantic surface tints (pale backgrounds for chips/badges/banners) ----
  static const Color primarySurface = Color(0xFFE8F1F8);
  static const Color successSurface = Color(0xFFE7F7E8);
  static const Color warningSurface = Color(0xFFFDF3E3);
  static const Color errorSurface = Color(0xFFF9E7E8);
  static const Color neutralSurface = Color(0xFFEFF1F2);

  // Backward-compatible alias for older call sites.
  static const Color darkSlate = primaryDarkest;
}
