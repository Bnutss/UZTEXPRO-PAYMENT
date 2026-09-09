import 'package:flutter/material.dart';

/// Single source of truth for the app's brand accent colors.
///
/// Every screen used to redeclare its own local `_gradientStart`/`_gradientEnd`
/// (or `_g1`/`_g2`) constants independently — this centralizes them so the
/// brand color only needs to change in one place.
class AppColors {
  AppColors._();

  static const Color brandOrange = Color(0xFFFF8C00);
  static const Color brandRed = Color(0xFFCC1500);

  /// The one gray used app-wide as the backdrop behind white cards/lists —
  /// iOS's systemGray5. Every screen must reference this constant instead of
  /// its own hardcoded gray hex, or screens drift out of sync with each
  /// other (as happened before this existed).
  static const Color groupedBackground = Color(0xFFE5E5EA);
}
