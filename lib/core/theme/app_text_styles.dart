import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography is the identity here.
///
/// SaveWise ships no font assets on purpose — bundling or fetching a webfont
/// would either bloat the APK or break the offline guarantee. So the *setting*
/// does the work instead of the typeface:
///
///   * Money is always tabular and tightly tracked, at a size that dwarfs its
///     label. Digits line up column-to-column across every card and table.
///   * Labels are small, uppercase and widely tracked — they read as engraved
///     captions on an instrument, not as body copy.
///   * Body text is the only place with comfortable, normal tracking.
///
/// The result is a consistent "instrument panel" voice you can recognise on
/// any screen without a single custom glyph.
abstract final class AppTextStyles {
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// The hero number on the dashboard, goal detail and calculator results.
  static const TextStyle moneyHero = TextStyle(
    fontSize: 40,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.6,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const TextStyle moneyLarge = TextStyle(
    fontSize: 28,
    height: 1.05,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const TextStyle moneyMedium = TextStyle(
    fontSize: 20,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const TextStyle moneySmall = TextStyle(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  /// The engraved caption. Always uppercase at the call site.
  static const TextStyle label = TextStyle(
    fontSize: 10.5,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: AppColors.textMuted,
  );

  static const TextStyle labelBright = TextStyle(
    fontSize: 10.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle screenTitle = TextStyle(
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle small = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const TextStyle numericSmall = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    fontFeatures: _tabular,
  );

  /// Running clock on the dashboard. Tabular so the seconds don't jitter.
  static const TextStyle clock = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    color: AppColors.textSecondary,
    fontFeatures: _tabular,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );
}
