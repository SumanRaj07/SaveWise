import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/json.dart';

enum SavingsChallengeType { fiftyTwoWeek, daily, weekend, noSpend }

extension SavingsChallengeTypeX on SavingsChallengeType {
  String get label => switch (this) {
        SavingsChallengeType.fiftyTwoWeek => '52-week challenge',
        SavingsChallengeType.daily => 'Daily saving',
        SavingsChallengeType.weekend => 'Weekend saving',
        SavingsChallengeType.noSpend => 'No-spend run',
      };

  String get blurb => switch (this) {
        SavingsChallengeType.fiftyTwoWeek =>
          'Week 1 you save one unit, week 2 two units, and so on for a year. '
              'Starts trivially, ends serious.',
        SavingsChallengeType.daily =>
          'The same amount every day for 30 days. Boring on purpose — this is '
              'the one that becomes a habit.',
        SavingsChallengeType.weekend =>
          'Save on Saturdays and Sundays for 12 weeks. Weekends are where most '
              'discretionary money actually goes.',
        SavingsChallengeType.noSpend =>
          '30 days, no discretionary spending. Each day you hold the line, the '
              'money you would have spent counts as saved.',
      };

  IconData get icon => switch (this) {
        SavingsChallengeType.fiftyTwoWeek => Icons.stairs_rounded,
        SavingsChallengeType.daily => Icons.today_rounded,
        SavingsChallengeType.weekend => Icons.weekend_rounded,
        SavingsChallengeType.noSpend => Icons.block_rounded,
      };

  Color get accent => switch (this) {
        SavingsChallengeType.fiftyTwoWeek => AppColors.brass,
        SavingsChallengeType.daily => AppColors.emerald,
        SavingsChallengeType.weekend => AppColors.vizTeal,
        SavingsChallengeType.noSpend => AppColors.clay,
      };

  int get totalSteps => switch (this) {
        SavingsChallengeType.fiftyTwoWeek => 52,
        SavingsChallengeType.daily => 30,
        SavingsChallengeType.weekend => 24,
        SavingsChallengeType.noSpend => 30,
      };

  /// What one step is called in the UI.
  String get stepNoun => switch (this) {
        SavingsChallengeType.fiftyTwoWeek => 'Week',
        SavingsChallengeType.daily => 'Day',
        SavingsChallengeType.weekend => 'Day',
        SavingsChallengeType.noSpend => 'Day',
      };
}

/// A long-running savings challenge. Steps are marked off one at a time; the
/// total saved is always derived from the marked steps.
class SavingsChallenge {
  const SavingsChallenge({
    required this.id,
    required this.type,
    required this.startDate,
    required this.baseAmount,
    this.completedSteps = const <int>[],
    this.active = true,
    this.completedAt,
  });

  final String id;
  final SavingsChallengeType type;
  final DateTime startDate;

  /// The unit amount. Meaning depends on type: per-week multiplier base for the
  /// 52-week run, per-day amount for the others.
  final double baseAmount;

  /// Zero-based step indices already marked off.
  final List<int> completedSteps;

  final bool active;
  final DateTime? completedAt;

  int get totalSteps => type.totalSteps;

  /// Amount attached to a given zero-based step.
  double amountForStep(int step) {
    if (type == SavingsChallengeType.fiftyTwoWeek) {
      return baseAmount * (step + 1);
    }
    if (type == SavingsChallengeType.weekend) {
      return baseAmount * 2;
    }
    return baseAmount;
  }

  double get totalSaved {
    double sum = 0;
    for (final int step in completedSteps) {
      if (step >= 0 && step < totalSteps) sum += amountForStep(step);
    }
    return sum;
  }

  /// What the whole challenge is worth if finished.
  double get targetTotal {
    double sum = 0;
    for (int i = 0; i < totalSteps; i++) {
      sum += amountForStep(i);
    }
    return sum;
  }

  int get stepsDone => completedSteps.where((int s) => s < totalSteps).length;

  double get progress =>
      totalSteps == 0 ? 0 : (stepsDone / totalSteps).clamp(0.0, 1.0).toDouble();

  bool get isFinished => stepsDone >= totalSteps;

  /// The next step the user is expected to mark, in order.
  int get nextStep {
    for (int i = 0; i < totalSteps; i++) {
      if (!completedSteps.contains(i)) return i;
    }
    return totalSteps - 1;
  }

  /// Consecutive completed steps ending at the highest one marked. This is the
  /// streak the UI shows, and it breaks honestly if a step is skipped.
  int get streak {
    if (completedSteps.isEmpty) return 0;
    final List<int> sorted = List<int>.of(completedSteps)..sort();
    int best = 1;
    int run = 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == sorted[i - 1] + 1) {
        run++;
        best = math.max(best, run);
      } else {
        run = 1;
      }
    }
    return best;
  }

  /// How many steps *should* be done by now, so the UI can say "you're behind".
  int expectedStepsBy(DateTime now) {
    final int days = math.max(0, now.difference(startDate).inDays);
    final int raw = switch (type) {
      SavingsChallengeType.fiftyTwoWeek => (days / 7).floor() + 1,
      SavingsChallengeType.daily => days + 1,
      SavingsChallengeType.weekend => ((days / 7).floor() * 2) + 1,
      SavingsChallengeType.noSpend => days + 1,
    };
    return raw > totalSteps ? totalSteps : raw;
  }

  SavingsChallenge copyWith({
    List<int>? completedSteps,
    bool? active,
    DateTime? completedAt,
    double? baseAmount,
    bool clearCompletedAt = false,
  }) =>
      SavingsChallenge(
        id: id,
        type: type,
        startDate: startDate,
        baseAmount: baseAmount ?? this.baseAmount,
        completedSteps: completedSteps ?? this.completedSteps,
        active: active ?? this.active,
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'startDate': startDate.toIso8601String(),
        'baseAmount': baseAmount,
        'completedSteps': completedSteps,
        'active': active,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory SavingsChallenge.fromJson(Map<String, dynamic> json) =>
      SavingsChallenge(
        id: J.asString(json['id']),
        type: J.asEnum(json['type'], SavingsChallengeType.values,
            SavingsChallengeType.daily),
        startDate: J.asDate(json['startDate']),
        baseAmount: J.asDouble(json['baseAmount']),
        completedSteps: J.asIntList(json['completedSteps']),
        active: J.asBool(json['active'], true),
        completedAt: J.asDateOrNull(json['completedAt']),
      );
}
