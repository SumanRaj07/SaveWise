import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

enum EmergencyReadiness { critical, low, moderate, safe, excellent }

extension EmergencyReadinessX on EmergencyReadiness {
  String get label => switch (this) {
        EmergencyReadiness.critical => 'Critical',
        EmergencyReadiness.low => 'Low',
        EmergencyReadiness.moderate => 'Moderate',
        EmergencyReadiness.safe => 'Safe',
        EmergencyReadiness.excellent => 'Excellent',
      };

  String get blurb => switch (this) {
        EmergencyReadiness.critical =>
          'One unexpected bill would go on credit. This is the most urgent '
              'thing in your finances.',
        EmergencyReadiness.low =>
          'You could absorb a small shock but not a lost month of income.',
        EmergencyReadiness.moderate =>
          'A month or two of cover. Keep going — three months is the floor.',
        EmergencyReadiness.safe =>
          'Three months of essentials covered. You can handle most surprises '
              'without borrowing.',
        EmergencyReadiness.excellent =>
          'Six months covered. You have the freedom to say no to bad options.',
      };

  Color get color => switch (this) {
        EmergencyReadiness.critical => AppColors.clay,
        EmergencyReadiness.low => AppColors.clay,
        EmergencyReadiness.moderate => AppColors.brass,
        EmergencyReadiness.safe => AppColors.emerald,
        EmergencyReadiness.excellent => AppColors.emerald,
      };

  IconData get icon => switch (this) {
        EmergencyReadiness.critical => Icons.warning_amber_rounded,
        EmergencyReadiness.low => Icons.shield_outlined,
        EmergencyReadiness.moderate => Icons.shield_rounded,
        EmergencyReadiness.safe => Icons.verified_user_rounded,
        EmergencyReadiness.excellent => Icons.workspace_premium_rounded,
      };
}

class EmergencyPlan {
  const EmergencyPlan({
    required this.balance,
    required this.essentialsMonthly,
    required this.minTarget,
    required this.idealTarget,
    required this.suggestedMonthly,
  });

  final double balance;
  final double essentialsMonthly;

  /// Three months of essentials — the floor.
  final double minTarget;

  /// Six months — the goal.
  final double idealTarget;

  /// A contribution that finishes the job in a reasonable time.
  final double suggestedMonthly;

  /// How many months of essential spending the fund covers.
  double get coverageMonths =>
      essentialsMonthly <= 0 ? 0 : balance / essentialsMonthly;

  double get progressToMin =>
      minTarget <= 0 ? 0 : (balance / minTarget).clamp(0.0, 1.0).toDouble();

  double get progressToIdeal =>
      idealTarget <= 0 ? 0 : (balance / idealTarget).clamp(0.0, 1.0).toDouble();

  int get percentOfIdeal => (progressToIdeal * 100).round();

  double get remainingToMin => math.max(0.0, minTarget - balance);

  double get remainingToIdeal => math.max(0.0, idealTarget - balance);

  bool get hasMinimum => balance >= minTarget && minTarget > 0;

  bool get isComplete => balance >= idealTarget && idealTarget > 0;

  EmergencyReadiness get readiness {
    final double months = coverageMonths;
    if (months >= AppConstants.emergencyIdealMonths) {
      return EmergencyReadiness.excellent;
    }
    if (months >= AppConstants.emergencyMinMonths) return EmergencyReadiness.safe;
    if (months >= 1.5) return EmergencyReadiness.moderate;
    if (months >= 0.5) return EmergencyReadiness.low;
    return EmergencyReadiness.critical;
  }

  /// Months to the ideal target at a given monthly contribution.
  int monthsToIdeal(double monthlyContribution) {
    if (isComplete) return 0;
    if (monthlyContribution <= 0) return -1;
    return (remainingToIdeal / monthlyContribution).ceil();
  }

  int monthsToMin(double monthlyContribution) {
    if (hasMinimum) return 0;
    if (monthlyContribution <= 0) return -1;
    return (remainingToMin / monthlyContribution).ceil();
  }
}

abstract final class EmergencyFundEngine {
  /// Build the plan.
  ///
  /// The target is based on *essential* monthly spending, not income and not
  /// total spending. A fund exists to keep the lights on and food on the table
  /// while you sort things out — it does not need to fund your streaming
  /// subscriptions for six months.
  static EmergencyPlan plan({
    required double balance,
    required double essentialsMonthly,
    required double monthlySalary,
  }) {
    // If no budget has been set yet, fall back to a conservative half of
    // income as the essentials estimate rather than showing a zero target.
    final double essentials =
        essentialsMonthly > 0 ? essentialsMonthly : monthlySalary * 0.5;

    final double minTarget = essentials * AppConstants.emergencyMinMonths;
    final double idealTarget = essentials * AppConstants.emergencyIdealMonths;

    // Aim to reach the three-month floor within a year; that pace is
    // demanding but not absurd, and it is the number worth quoting.
    final double suggested = math.max(0.0, minTarget / 12);

    return EmergencyPlan(
      balance: balance,
      essentialsMonthly: essentials,
      minTarget: minTarget,
      idealTarget: idealTarget,
      suggestedMonthly: suggested,
    );
  }
}
