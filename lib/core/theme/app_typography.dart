import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// One typeface (Lexend) used across the whole app, differentiated by
/// weight and size rather than mixing families — Lexend was designed for
/// reading proficiency, which fits an app students read carefully under
/// time pressure.
class AppTypography {
  AppTypography._();

  static TextStyle _lexend({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.lexend(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // ---- Display / headings ----
  static TextStyle get display => _lexend(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.2,
        letterSpacing: -0.4,
      );

  static TextStyle get heading1 => _lexend(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.25,
        letterSpacing: -0.2,
      );

  static TextStyle get heading2 => _lexend(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get heading3 => _lexend(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.35,
      );

  // ---- Body ----
  static TextStyle get body => _lexend(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.45,
      );

  static TextStyle get bodyMedium => _lexend(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.45,
      );

  static TextStyle get bodySecondary => _lexend(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // ---- Small text ----
  static TextStyle get label => _lexend(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0.1,
      );

  static TextStyle get caption => _lexend(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
        height: 1.3,
      );

  // ---- Interactive ----
  static TextStyle get button => _lexend(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  /// For scores like "18 / 20" — tabular figures keep digits aligned
  /// when several appear stacked in a results list.
  static TextStyle get score => GoogleFonts.lexend(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
