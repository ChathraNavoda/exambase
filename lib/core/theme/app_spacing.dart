/// Spacing, radius, and elevation scale. Existing xs–xxl values are
/// untouched (they're already used in ~90 places across the app) — this
/// only adds the tokens the refreshed theme needs.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;

  /// Fully rounded — status chips, pill buttons.
  static const double radiusPill = 999;

  static const double borderWidth = 1;
  static const double borderWidthFocus = 2;

  static const double elevationNone = 0;
  static const double elevationSm = 1;
  static const double elevationMd = 3;
  static const double elevationLg = 8;
}
