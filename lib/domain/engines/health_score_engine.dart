import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/goal.dart';
import '../../data/models/user_profile.dart';
import 'advice.dart';
import 'budget_engine.dart';
import 'emergency_fund_engine.dart';
import 'goal_engine.dart';

enum HealthGrade { gettingStarted, needsWork, average, good, excellent }

extension HealthGradeX on HealthGrade {
  String get label => switch (this) {
        HealthGrade.gettingStarted => 'Getting started',
        HealthGrade.needsWork => 'Needs improvement',
        HealthGrade.average => 'Average',
        HealthGrade.good => 'Good',
        HealthGrade.excellent => 'Excellent',
      };

  String get blurb => switch (this) {
        HealthGrade.gettingStarted =>
          'Nothing to judge yet. Set a budget, start a fund, name one goal — the '
              'points are all still on the table.',
        HealthGrade.needsWork =>
          'The foundations are missing. Pick the single biggest gap below and fix '
              'only that this month.',
        HealthGrade.average =>
          'You are in control but thin on cushion. Steady contributions move this '
              'faster than any clever trick.',
        HealthGrade.good =>
          'Solid. You save consistently and stay inside your plan. Push the '
              'emergency fund to close the gap.',
        HealthGrade.excellent =>
          'Excellent. Savings, discipline, cushion and goals are all working '
              'together. Keep the system, raise the targets.',
      };

  Color get color => switch (this) {
        HealthGrade.gettingStarted => AppColors.textSecondary,
        HealthGrade.needsWork => AppColors.clay,
        HealthGrade.average => AppColors.brass,
        HealthGrade.good => AppColors.emeraldSoft,
        HealthGrade.excellent => AppColors.emerald,
      };
}

/// One weighted component of the score.
class ScoreFactor {
  const ScoreFactor({
    required this.id,
    required this.label,
    required this.weight,
    required this.ratio,
    required this.detail,
    required this.color,
  });

  final String id;
  final String label;

  /// Points this factor is worth.
  final int weight;

  /// How much of the weight is earned, 0–1.
  final double ratio;

  /// Plain-language explanation with the real numbers in it.
  final String detail;

  final Color color;

  int get earned => (weight * ratio).round();

  int get available => weight - earned;
}

class HealthScore {
  const HealthScore({
    required this.total,
    required this.factors,
    required this.grade,
    required this.recommendations,
    required this.isFresh,
  });

  final int total;
  final List<ScoreFactor> factors;
  final HealthGrade grade;
  final List<Recommendation> recommendations;

  /// True when there simply isn't enough data to judge anyone fairly.
  final bool isFresh;

  ScoreFactor factor(String id) => factors.firstWhere(
        (ScoreFactor f) => f.id == id,
        orElse: () => ScoreFactor(
          id: id,
          label: id,
          weight: 0,
          ratio: 0,
          detail: '',
          color: AppColors.textMuted,
        ),
      );

  Color get color => isFresh ? AppColors.textSecondary : AppColors.forScore(total);

  /// The factor with the most points left on the table.
  ScoreFactor? get biggestGap {
    ScoreFactor? worst;
    for (final ScoreFactor f in factors) {
      if (worst == null || f.available > worst.available) worst = f;
    }
    return worst;
  }
}

abstract final class HealthScoreEngine {
  /// Score out of 100, weighted 30 / 25 / 25 / 20 per the brief.
  ///
  /// Two design decisions worth knowing:
  ///
  /// 1. Savings and discipline are graded against the *pay cycle*, with a floor,
  ///    so nobody is marked down on day two for not yet having saved a month's
  ///    worth of income.
  /// 2. Unearned points are framed as available rather than lost. A brand-new
  ///    user scores low by definition — telling them they have "70 points
  ///    waiting" is both true and more useful than telling them they failed.
  static HealthScore evaluate({
    required UserProfile profile,
    required BudgetSummary summary,
    required EmergencyPlan emergency,
    required List<Goal> goals,
    required DateTime now,
  }) {
    final double income = profile.monthlySalary;
    final List<Recommendation> recs = <Recommendation>[];

    // ---- Factor 1: savings rate (30) ----
    final double target = profile.savingsRateTarget;
    final double expectedSaved =
        income * target * summary.cycle.gradingProgress();
    final double savingsRatio = expectedSaved <= 0
        ? 0
        : (summary.saved / expectedSaved).clamp(0.0, 1.0).toDouble();

    final ScoreFactor savings = ScoreFactor(
      id: 'savings',
      label: 'Savings rate',
      weight: AppConstants.weightSavingsRate,
      ratio: savingsRatio,
      detail: income <= 0
          ? 'Add your income to grade this.'
          : 'You have saved ${Money.format(summary.saved)} this cycle. '
              'The target is ${Money.percent(target)} of income, which is '
              '${Money.format(income * target)} a month.',
      color: AppColors.emerald,
    );

    // ---- Factor 2: budget discipline (25) ----
    double disciplineRatio;
    if (summary.totalLimit <= 0) {
      disciplineRatio = 0;
    } else {
      final double pace = summary.totalSpent /
          (summary.totalLimit *
              (summary.cycle.progress < 0.2 ? 0.2 : summary.cycle.progress));
      // Exactly on pace scores full marks; double the pace scores nothing.
      final double base = (2 - pace).clamp(0.0, 1.0).toDouble();
      final double penalty = 0.1 * summary.overspent.length;
      disciplineRatio = (base - penalty).clamp(0.0, 1.0).toDouble();
    }

    final ScoreFactor discipline = ScoreFactor(
      id: 'discipline',
      label: 'Budget discipline',
      weight: AppConstants.weightDiscipline,
      ratio: disciplineRatio,
      detail: summary.totalLimit <= 0
          ? 'No spending plan set yet.'
          : 'You have used ${Money.format(summary.totalSpent)} of '
              '${Money.format(summary.totalLimit)} with '
              '${summary.cycle.daysLeft} days to payday.',
      color: AppColors.brass,
    );

    // ---- Factor 3: emergency fund (25) ----
    final ScoreFactor fund = ScoreFactor(
      id: 'emergency',
      label: 'Emergency fund',
      weight: AppConstants.weightEmergency,
      ratio: emergency.progressToIdeal,
      detail: emergency.balance <= 0
          ? 'No fund yet. Six months of essentials is '
              '${Money.format(emergency.idealTarget)}.'
          : '${Money.format(emergency.balance)} saved — '
              '${emergency.coverageMonths.toStringAsFixed(1)} months of '
              'essential spending covered.',
      color: AppColors.vizTeal,
    );

    // ---- Factor 4: goal progress (20) ----
    final List<Goal> open =
        goals.where((Goal g) => !g.isComplete).toList(growable: false);
    double goalRatio = 0;
    if (open.isNotEmpty) {
      final double avg = GoalEngine.averageOpenProgress(goals);
      int onTrack = 0;
      for (final Goal g in open) {
        final GoalPlan plan = GoalEngine.plan(goal: g, now: now);
        if (plan.onTrack) onTrack++;
      }
      final double onTrackFraction = onTrack / open.length;
      goalRatio = (avg * 0.7 + onTrackFraction * 0.3).clamp(0.0, 1.0).toDouble();
    } else if (goals.isNotEmpty) {
      // Every goal funded scores full marks. Anything else would drop the
      // score 20 points at the exact moment the user succeeded, which is a
      // perverse thing for a health score to do. Having no goals at all is a
      // different case, handled by the zero above and nudged in the advice.
      goalRatio = 1;
    }

    final ScoreFactor goalsFactor = ScoreFactor(
      id: 'goals',
      label: 'Goal progress',
      weight: AppConstants.weightGoals,
      ratio: goalRatio,
      detail: open.isEmpty
          ? goals.isEmpty
              ? 'No goals yet. Naming one is worth '
                  '${AppConstants.weightGoals} points.'
              : 'Every goal is funded. Full marks — name another whenever '
                  'you are ready.'
          : '${open.length} open ${open.length == 1 ? 'goal' : 'goals'}, '
              'average completion '
              '${Money.percent(GoalEngine.averageOpenProgress(goals))}.',
      color: AppColors.vizMauve,
    );

    final List<ScoreFactor> factors = <ScoreFactor>[
      savings,
      discipline,
      fund,
      goalsFactor,
    ];

    int total = 0;
    for (final ScoreFactor f in factors) {
      total += f.earned;
    }
    if (total > 100) total = 100;
    if (total < 0) total = 0;

    // A profile with no budget, no fund and no goals isn't unhealthy — it's
    // empty. Say so instead of calling it a failure.
    final bool isFresh = summary.totalLimit <= 0 &&
        emergency.balance <= 0 &&
        goals.isEmpty &&
        summary.saved <= 0;

    // ---- Recommendations, most valuable first ----
    if (summary.totalLimit <= 0) {
      recs.add(Recommendation(
        title: 'Set your spending plan',
        detail: 'Without limits there is nothing to keep. The planner can '
            'generate a full plan from your income in one tap.',
        severity: AdviceSeverity.urgent,
        action: AdviceAction.openPlanner,
        pointsAvailable: discipline.available,
      ));
    }

    for (final CategoryUsage u in summary.overspent) {
      recs.add(Recommendation(
        title: 'Pull back on ${u.category.label.toLowerCase()}',
        detail: '${Money.format(u.spent)} spent against a '
            '${Money.format(u.limit)} limit — '
            '${Money.format(u.overspend)} over. '
            '${summary.cycle.daysLeft} days until payday.',
        severity: AdviceSeverity.warning,
        action: AdviceAction.openPlanner,
        pointsAvailable: 0,
      ));
    }

    if (emergency.balance <= 0) {
      recs.add(Recommendation(
        title: 'Start an emergency fund',
        detail: 'Three months of essentials is '
            '${Money.format(emergency.minTarget)}. Starting with '
            '${Money.format(Money.niceRound(emergency.suggestedMonthly))} a '
            'month gets you there inside a year.',
        severity: AdviceSeverity.urgent,
        action: AdviceAction.openEmergency,
        pointsAvailable: fund.available,
      ));
    } else if (!emergency.hasMinimum) {
      recs.add(Recommendation(
        title: 'Get to three months of cover',
        detail: '${Money.format(emergency.remainingToMin)} short of the '
            '${Money.format(emergency.minTarget)} floor. This is the highest '
            'value use of your next spare money.',
        severity: AdviceSeverity.warning,
        action: AdviceAction.openEmergency,
        pointsAvailable: fund.available,
      ));
    }

    if (savingsRatio < 0.6 && income > 0) {
      final double shortfall = expectedSaved - summary.saved;
      recs.add(Recommendation(
        title: shortfall > 0
            ? 'Move ${Money.format(Money.niceRound(shortfall))} into savings'
            : 'Raise your savings rate',
        detail: 'Saving ${Money.percent(target)} of income is '
            '${Money.format(income * target)} a month. Automating it on payday '
            'beats trying to save whatever survives the month.',
        severity: AdviceSeverity.warning,
        action: AdviceAction.openPlanner,
        pointsAvailable: savings.available,
      ));
    }

    if (goals.isEmpty) {
      recs.add(Recommendation(
        title: 'Name one goal',
        detail: 'Saving without a target is a chore. A named goal with a date '
            'turns it into progress you can watch, and it is worth '
            '${AppConstants.weightGoals} points here.',
        severity: AdviceSeverity.nudge,
        action: AdviceAction.openGoals,
        pointsAvailable: goalsFactor.available,
      ));
    } else {
      for (final Goal g in open) {
        final GoalPlan plan = GoalEngine.plan(goal: g, now: now);
        if (!plan.onTrack && plan.monthlyRequired > 0) {
          recs.add(Recommendation(
            title: '${g.name} needs '
                '${Money.format(plan.monthlyRequired)} a month',
            detail: plan.isOverdue
                ? 'The target date has passed. Move the date or raise the '
                    'contribution — either is fine, drifting is not.'
                : 'At your current pace it lands '
                    '${plan.slipDays == null ? 'late' : Dates.durationLabel(plan.slipDays!)} '
                    'after the date you set.',
            severity: AdviceSeverity.nudge,
            action: AdviceAction.openGoals,
            pointsAvailable: 0,
          ));
          break;
        }
      }
    }

    if (summary.discretionarySpent > 0 && disciplineRatio < 0.7) {
      recs.add(Recommendation(
        title: 'Trim shopping and entertainment',
        detail: '${Money.format(summary.discretionarySpent)} went to wants this '
            'cycle. This is the only spending you can cut today without '
            'changing anything about your life.',
        severity: AdviceSeverity.nudge,
        action: AdviceAction.openChallenges,
        pointsAvailable: 0,
      ));
    }

    if (recs.isEmpty) {
      recs.add(const Recommendation(
        title: 'Nothing needs fixing',
        detail: 'Savings, spending, cushion and goals are all where they should '
            'be. Consider raising your savings target or adding a goal with a '
            'bigger number on it.',
        severity: AdviceSeverity.praise,
        action: AdviceAction.none,
      ));
    }

    recs.sort((Recommendation a, Recommendation b) {
      final int bySeverity = a.severity.index.compareTo(b.severity.index);
      if (bySeverity != 0) return bySeverity;
      return b.pointsAvailable.compareTo(a.pointsAvailable);
    });

    return HealthScore(
      total: total,
      factors: factors,
      grade: isFresh ? HealthGrade.gettingStarted : gradeFor(total),
      recommendations: recs,
      isFresh: isFresh,
    );
  }

  /// Bands from the brief: 90+, 75+, 50+, below 50.
  static HealthGrade gradeFor(int score) {
    if (score >= 90) return HealthGrade.excellent;
    if (score >= 75) return HealthGrade.good;
    if (score >= 50) return HealthGrade.average;
    return HealthGrade.needsWork;
  }
}
