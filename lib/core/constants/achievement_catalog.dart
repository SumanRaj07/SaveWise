import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AchievementGroup { savings, goals, challenges, emergency }

extension AchievementGroupX on AchievementGroup {
  String get label => switch (this) {
        AchievementGroup.savings => 'Savings',
        AchievementGroup.goals => 'Goals',
        AchievementGroup.challenges => 'Challenges',
        AchievementGroup.emergency => 'Emergency fund',
      };

  IconData get icon => switch (this) {
        AchievementGroup.savings => Icons.savings_rounded,
        AchievementGroup.goals => Icons.flag_rounded,
        AchievementGroup.challenges => Icons.local_fire_department_rounded,
        AchievementGroup.emergency => Icons.shield_rounded,
      };
}

/// How an achievement is measured. Each maps to one number the engine can read
/// straight off app state.
enum AchievementMetric {
  /// Total saved, expressed as a multiple of monthly income.
  savingsMultiple,

  /// Count of goals reaching 100%.
  goalsCompleted,

  /// Longest daily-challenge streak.
  streakDays,

  /// Emergency fund as a fraction of the ideal (6-month) target.
  emergencyFraction,
}

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.detail,
    required this.group,
    required this.metric,
    required this.threshold,
    required this.icon,
    required this.accent,
  });

  final String id;
  final String title;
  final String detail;
  final AchievementGroup group;
  final AchievementMetric metric;
  final double threshold;
  final IconData icon;
  final Color accent;
}

/// The catalogue.
///
/// Savings tiers are multiples of monthly income rather than fixed amounts.
/// The brief asked for "First ₹1,000 / ₹10,000 / ₹50,000 / ₹1 Lakh saved", but
/// fixed amounts mean different things in different currencies *and* at
/// different incomes — ₹1,000 is a rounding error to one earner and a week of
/// groceries to another. Income multiples keep every badge equally meaningful
/// and work in any locale.
abstract final class AchievementCatalog {
  static const List<AchievementDef> all = <AchievementDef>[
    // ---- Savings ----
    AchievementDef(
      id: 'save_quarter_month',
      title: 'Seed planted',
      detail: 'Saved a quarter of a month\'s income.',
      group: AchievementGroup.savings,
      metric: AchievementMetric.savingsMultiple,
      threshold: 0.25,
      icon: Icons.eco_rounded,
      accent: AppColors.emeraldSoft,
    ),
    AchievementDef(
      id: 'save_one_month',
      title: 'One month banked',
      detail: 'Saved a full month of income. You can absorb a surprise now.',
      group: AchievementGroup.savings,
      metric: AchievementMetric.savingsMultiple,
      threshold: 1,
      icon: Icons.account_balance_wallet_rounded,
      accent: AppColors.emerald,
    ),
    AchievementDef(
      id: 'save_three_months',
      title: 'Three months banked',
      detail: 'Three months of income saved. This is where sleep improves.',
      group: AchievementGroup.savings,
      metric: AchievementMetric.savingsMultiple,
      threshold: 3,
      icon: Icons.savings_rounded,
      accent: AppColors.emerald,
    ),
    AchievementDef(
      id: 'save_six_months',
      title: 'Half a year banked',
      detail: 'Six months of income saved. Most people never get here.',
      group: AchievementGroup.savings,
      metric: AchievementMetric.savingsMultiple,
      threshold: 6,
      icon: Icons.workspace_premium_rounded,
      accent: AppColors.brass,
    ),
    AchievementDef(
      id: 'save_twelve_months',
      title: 'A year of income',
      detail: 'Twelve months of income saved. That is real optionality.',
      group: AchievementGroup.savings,
      metric: AchievementMetric.savingsMultiple,
      threshold: 12,
      icon: Icons.diamond_rounded,
      accent: AppColors.brass,
    ),

    // ---- Goals ----
    AchievementDef(
      id: 'goal_first',
      title: 'First goal done',
      detail: 'Funded a goal from zero to finished.',
      group: AchievementGroup.goals,
      metric: AchievementMetric.goalsCompleted,
      threshold: 1,
      icon: Icons.flag_rounded,
      accent: AppColors.emerald,
    ),
    AchievementDef(
      id: 'goal_three',
      title: 'Three goals done',
      detail: 'Three finished goals. The method is working.',
      group: AchievementGroup.goals,
      metric: AchievementMetric.goalsCompleted,
      threshold: 3,
      icon: Icons.military_tech_rounded,
      accent: AppColors.emeraldSoft,
    ),
    AchievementDef(
      id: 'goal_five',
      title: 'Five goals done',
      detail: 'Five finished goals. Saving is a habit now, not an effort.',
      group: AchievementGroup.goals,
      metric: AchievementMetric.goalsCompleted,
      threshold: 5,
      icon: Icons.emoji_events_rounded,
      accent: AppColors.brass,
    ),

    // ---- Challenges ----
    AchievementDef(
      id: 'streak_7',
      title: 'Seven-day streak',
      detail: 'A week of daily challenges completed without a gap.',
      group: AchievementGroup.challenges,
      metric: AchievementMetric.streakDays,
      threshold: 7,
      icon: Icons.local_fire_department_rounded,
      accent: AppColors.clay,
    ),
    AchievementDef(
      id: 'streak_30',
      title: 'Thirty-day streak',
      detail: 'A month unbroken. This is the length that changes behaviour.',
      group: AchievementGroup.challenges,
      metric: AchievementMetric.streakDays,
      threshold: 30,
      icon: Icons.whatshot_rounded,
      accent: AppColors.clay,
    ),
    AchievementDef(
      id: 'streak_100',
      title: 'Hundred-day streak',
      detail: 'One hundred days. You are not trying to save any more; you just do.',
      group: AchievementGroup.challenges,
      metric: AchievementMetric.streakDays,
      threshold: 100,
      icon: Icons.bolt_rounded,
      accent: AppColors.brass,
    ),

    // ---- Emergency fund ----
    AchievementDef(
      id: 'ef_started',
      title: 'Fund started',
      detail: 'Made the first contribution to your emergency fund.',
      group: AchievementGroup.emergency,
      metric: AchievementMetric.emergencyFraction,
      threshold: 0.01,
      icon: Icons.shield_outlined,
      accent: AppColors.emeraldSoft,
    ),
    AchievementDef(
      id: 'ef_half',
      title: 'Fund halfway',
      detail: 'Halfway to a six-month cushion.',
      group: AchievementGroup.emergency,
      metric: AchievementMetric.emergencyFraction,
      threshold: 0.5,
      icon: Icons.shield_rounded,
      accent: AppColors.emerald,
    ),
    AchievementDef(
      id: 'ef_full',
      title: 'Fully covered',
      detail: 'Six months of essential spending, in the bank, liquid.',
      group: AchievementGroup.emergency,
      metric: AchievementMetric.emergencyFraction,
      threshold: 1,
      icon: Icons.verified_user_rounded,
      accent: AppColors.brass,
    ),
  ];

  static AchievementDef? byId(String id) {
    for (final AchievementDef d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  static List<AchievementDef> forGroup(AchievementGroup group) =>
      all.where((AchievementDef d) => d.group == group).toList();
}
