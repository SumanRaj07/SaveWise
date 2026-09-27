import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/goal.dart';

/// Everything the UI needs to talk about one goal.
class GoalPlan {
  const GoalPlan({
    required this.goal,
    required this.monthlyRequired,
    required this.weeklyRequired,
    required this.dailyRequired,
    required this.daysRemaining,
    required this.observedMonthlyPace,
    required this.projectedCompletion,
    required this.allocatedMonthly,
  });

  final Goal goal;

  /// What the target date demands from here.
  final double monthlyRequired;
  final double weeklyRequired;
  final double dailyRequired;

  final int daysRemaining;

  /// What the user has actually been contributing per month, measured from the
  /// goal's own history. Zero until they start.
  final double observedMonthlyPace;

  /// When the goal lands at the current real pace. Null if the pace is zero.
  final DateTime? projectedCompletion;

  /// Share of spare savings capacity this goal would get, by priority.
  final double allocatedMonthly;

  bool get isComplete => goal.isComplete;

  bool get isOverdue => daysRemaining < 0 && !isComplete;

  /// On track if the real pace meets what the deadline requires.
  bool get onTrack {
    if (isComplete) return true;
    if (monthlyRequired <= 0) return true;
    return observedMonthlyPace >= monthlyRequired * 0.95;
  }

  /// How far ahead or behind the deadline the projection lands, in days.
  int? get slipDays {
    final DateTime? p = projectedCompletion;
    if (p == null || isComplete) return null;
    return Dates.daysBetween(goal.targetDate, p);
  }

  /// One-line verdict for cards.
  String get verdict {
    if (isComplete) return 'Funded';
    if (monthlyRequired <= 0) return 'Ready to fund';
    if (isOverdue) return 'Target date passed';
    if (onTrack) return 'On track';
    final int? slip = slipDays;
    if (slip == null) return 'Not started';
    if (slip <= 0) return 'On track';
    return 'Running ${Dates.durationLabel(slip)} late';
  }
}

abstract final class GoalEngine {
  /// Work out the maths for one goal.
  static GoalPlan plan({
    required Goal goal,
    required DateTime now,
    double allocatedMonthly = 0,
  }) {
    final double remaining = goal.remaining;
    final int days = math.max(1, Dates.daysBetween(now, goal.targetDate));
    final double months = math.max(1.0, days / 30.44);
    final double weeks = math.max(1.0, days / 7);

    final double monthly = remaining <= 0 ? 0 : remaining / months;
    final double weekly = remaining <= 0 ? 0 : remaining / weeks;
    final double daily = remaining <= 0 ? 0 : remaining / days;

    // Observed pace: what has actually gone in, over how long the goal has
    // existed. Using real behaviour rather than intent is what makes the
    // projected date worth reading.
    final int ageDays = math.max(1, Dates.daysBetween(goal.createdAt, now));
    final double observed =
        goal.saved <= 0 ? 0 : goal.saved / (ageDays / 30.44);

    // If nothing has gone in yet, fall back to whatever capacity the planner
    // can allocate, so a fresh goal still gets an honest projection.
    final double pace = observed > 0 ? observed : allocatedMonthly;

    DateTime? projected;
    if (remaining <= 0) {
      projected = goal.completedAt ?? now;
    } else if (pace > 0) {
      final double monthsNeeded = remaining / pace;
      projected = now.add(Duration(days: (monthsNeeded * 30.44).ceil()));
    }

    return GoalPlan(
      goal: goal,
      monthlyRequired: monthly,
      weeklyRequired: weekly,
      dailyRequired: daily,
      daysRemaining: Dates.daysBetween(now, goal.targetDate),
      observedMonthlyPace: observed,
      projectedCompletion: projected,
      allocatedMonthly: allocatedMonthly,
    );
  }

  /// Split available monthly savings across unfinished goals by priority.
  ///
  /// High priority gets three shares, medium two, low one. Finished goals get
  /// nothing, which is the whole point of finishing them.
  static Map<String, double> allocate({
    required List<Goal> goals,
    required double monthlyCapacity,
  }) {
    final List<Goal> open =
        goals.where((Goal g) => !g.isComplete).toList(growable: false);
    if (open.isEmpty || monthlyCapacity <= 0) return <String, double>{};

    double totalWeight = 0;
    for (final Goal g in open) {
      totalWeight += g.priority.weight;
    }
    if (totalWeight <= 0) return <String, double>{};

    return <String, double>{
      for (final Goal g in open)
        g.id: monthlyCapacity * (g.priority.weight / totalWeight),
    };
  }

  /// Milestones crossed between two states of the same goal.
  static List<int> newMilestones(Goal before, Goal after) {
    final int from = before.progressPercent;
    final int to = after.progressPercent;
    return AppConstants.goalMilestones
        .where((int m) =>
            to >= m && from < m && !after.milestonesUnlocked.contains(m))
        .toList();
  }

  /// Sort for the goals list: unfinished first, then by priority, then by how
  /// soon the deadline is.
  static List<Goal> sorted(List<Goal> goals) {
    final List<Goal> copy = List<Goal>.of(goals);
    copy.sort((Goal a, Goal b) {
      if (a.isComplete != b.isComplete) return a.isComplete ? 1 : -1;
      final int byPriority =
          a.priority.index.compareTo(b.priority.index);
      if (byPriority != 0) return byPriority;
      return a.targetDate.compareTo(b.targetDate);
    });
    return copy;
  }

  /// The goal to feature on the dashboard: highest priority, nearest deadline,
  /// not yet finished.
  static Goal? active(List<Goal> goals) {
    final List<Goal> open = sorted(goals)
        .where((Goal g) => !g.isComplete)
        .toList(growable: false);
    return open.isEmpty ? null : open.first;
  }

  static int completedCount(List<Goal> goals) =>
      goals.where((Goal g) => g.isComplete).length;

  /// Average completion across *every* goal, 0–1, with a funded goal counting
  /// as a full 1. This is the reporting figure — what a monthly snapshot and
  /// the reports screen show as "goal progress".
  ///
  /// A plain mean on purpose: priority is a label the user picked for their own
  /// planning, and it should not quietly skew a percentage they are reading.
  static double averageProgress(List<Goal> goals) {
    if (goals.isEmpty) return 0;
    double sum = 0;
    for (final Goal g in goals) {
      sum += g.isComplete ? 1.0 : g.progress;
    }
    return sum / goals.length;
  }

  /// Average completion across the goals still *open*, priority-weighted, 0–1.
  ///
  /// This is the health score's figure, and it asks a different question:
  /// how are the goals you are still working on coming along? Finished goals
  /// are excluded because including them would let a user coast on past wins
  /// while a live goal sits untouched. Callers must handle the no-open-goals
  /// case themselves — see the health score, which treats it as full marks.
  static double averageOpenProgress(List<Goal> goals) {
    final List<Goal> open =
        goals.where((Goal g) => !g.isComplete).toList(growable: false);
    if (open.isEmpty) return 0;
    double weighted = 0;
    double weights = 0;
    for (final Goal g in open) {
      weighted += g.progress * g.priority.weight;
      weights += g.priority.weight;
    }
    return weights <= 0 ? 0 : weighted / weights;
  }
}
