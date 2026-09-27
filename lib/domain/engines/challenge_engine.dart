import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/constants/challenge_pool.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/challenge.dart';
import '../../data/models/expense.dart';
import '../../data/models/user_profile.dart';

/// How today's challenge is going, measured against real logged data.
class ChallengeProgress {
  const ChallengeProgress({
    required this.challenge,
    required this.achieved,
    required this.target,
    required this.met,
    required this.broken,
    required this.dayIsOver,
  });

  final DailyChallenge challenge;

  /// Saved so far, or spent so far, depending on the challenge kind.
  final double achieved;

  /// The amount to beat. Zero for "no spend" style challenges.
  final double target;

  /// Conditions satisfied.
  final bool met;

  /// Definitively failed — spending already blew the cap.
  final bool broken;

  final bool dayIsOver;

  double get progress {
    if (target <= 0) return met ? 1 : 0;
    return (achieved / target).clamp(0.0, 1.0).toDouble();
  }

  /// One line for the challenge card, written to be useful mid-day.
  String get statusLine {
    if (challenge.isCompleted) return 'Done — rewards claimed';
    if (challenge.status == ChallengeStatus.skipped) return 'Missed this one';
    switch (challenge.kind) {
      case ChallengeKind.saveAmount:
        if (met) return 'Target reached — tap to claim';
        return '${Money.format(achieved)} of ${Money.format(target)} moved';
      case ChallengeKind.noSpendCategory:
        if (broken) return 'Broken: ${Money.format(achieved)} logged';
        return dayIsOver ? 'Held the line all day' : 'Clean so far today';
      case ChallengeKind.capSpend:
        if (broken) {
          return target <= 0
              ? '${Money.format(achieved)} spent today'
              : '${Money.format(achieved)} spent — over by '
                  '${Money.format(achieved - target)}';
        }
        return target <= 0
            ? 'Nothing spent yet today'
            : '${Money.format(achieved)} of ${Money.format(target)} used';
      case ChallengeKind.habit:
        return 'Mark it done when you have';
    }
  }
}

abstract final class ChallengeEngine {
  /// Build the challenge for one day.
  ///
  /// Deterministic: the same day always produces the same challenge, so a
  /// restart cannot reroll a challenge the user has already failed. The
  /// selection uses a hand-rolled FNV-1a hash rather than [String.hashCode],
  /// which Dart does not promise to keep stable between runs.
  ///
  /// Amounts are derived from the user's own numbers. Saving challenges scale
  /// off one day of discretionary money; spending caps scale off one day of
  /// total spendable money, because a cap set from pocket-money would be
  /// impossible rather than difficult.
  static DailyChallenge forDay({
    required DateTime day,
    required UserProfile profile,
    String? previousTemplateId,
  }) {
    final List<ChallengeTemplate> pool = ChallengePool.all;
    int index = _hash(Dates.dayKey(day)) % pool.length;
    if (previousTemplateId != null &&
        pool[index].id == previousTemplateId &&
        pool.length > 1) {
      index = (index + 1) % pool.length;
    }
    final ChallengeTemplate t = pool[index];

    final int days = Dates.daysInMonth(day);
    final double dailyWants = profile.dailyDiscretionary(days);
    final double dailySpendable = days <= 0
        ? 0
        : math.max(
            0.0,
            profile.monthlySalary * (1 - profile.savingsRateTarget) / days,
          );

    double amount = 0;
    if (t.amountFactor > 0) {
      final double basis =
          t.kind == ChallengeKind.capSpend ? dailySpendable : dailyWants;
      amount = Money.niceRound(math.max(1.0, basis * t.amountFactor));
    }

    final String money = Money.format(amount);
    return DailyChallenge(
      dayKey: Dates.dayKey(day),
      templateId: t.id,
      title: t.title.replaceAll('{amount}', money),
      detail: t.detail.replaceAll('{amount}', money),
      kind: t.kind,
      coins: t.coins,
      xp: t.xp,
      amount: amount,
      categoryId: t.categoryId,
    );
  }

  /// Grade a challenge against the expenses logged on its own day.
  static ChallengeProgress progressFor({
    required DailyChallenge challenge,
    required List<Expense> expenses,
    required DateTime now,
  }) {
    final bool dayIsOver = Dates.dayKey(now) != challenge.dayKey;

    double savedToday = 0;
    double spentToday = 0;
    double inCategory = 0;
    for (final Expense e in expenses) {
      if (Dates.dayKey(e.date) != challenge.dayKey) continue;
      if (e.categoryId == BudgetCategory.savings.id) {
        savedToday += e.amount;
      } else {
        spentToday += e.amount;
      }
      if (challenge.categoryId != null && e.categoryId == challenge.categoryId) {
        inCategory += e.amount;
      }
    }

    switch (challenge.kind) {
      case ChallengeKind.saveAmount:
        return ChallengeProgress(
          challenge: challenge,
          achieved: savedToday,
          target: challenge.amount,
          met: challenge.amount > 0 && savedToday >= challenge.amount,
          broken: false,
          dayIsOver: dayIsOver,
        );
      case ChallengeKind.noSpendCategory:
        final bool broken = inCategory > 0;
        return ChallengeProgress(
          challenge: challenge,
          achieved: inCategory,
          target: 0,
          met: !broken && dayIsOver,
          broken: broken,
          dayIsOver: dayIsOver,
        );
      case ChallengeKind.capSpend:
        final bool broken = spentToday > challenge.amount;
        return ChallengeProgress(
          challenge: challenge,
          achieved: spentToday,
          target: challenge.amount,
          met: !broken && dayIsOver,
          broken: broken,
          dayIsOver: dayIsOver,
        );
      case ChallengeKind.habit:
        return ChallengeProgress(
          challenge: challenge,
          achieved: challenge.isCompleted ? 1 : 0,
          target: 1,
          met: challenge.isCompleted,
          broken: false,
          dayIsOver: dayIsOver,
        );
    }
  }

  /// The new status a challenge has earned, or null to leave it alone.
  ///
  /// Habit challenges are never auto-resolved — the app has no way to know
  /// whether you cooked twice, and pretending otherwise would make the whole
  /// streak worthless.
  static DailyChallenge? autoResolve({
    required DailyChallenge challenge,
    required List<Expense> expenses,
    required DateTime now,
  }) {
    if (!challenge.isPending || challenge.isSelfReported) return null;
    final ChallengeProgress p = progressFor(
      challenge: challenge,
      expenses: expenses,
      now: now,
    );
    if (p.met) return challenge.copyWith(status: ChallengeStatus.completed);
    if (p.broken && p.dayIsOver) {
      return challenge.copyWith(status: ChallengeStatus.skipped);
    }
    return null;
  }

  /// Pay out coins, XP and the streak for a completed challenge.
  ///
  /// Idempotent per day: completing twice cannot double-count, because the
  /// profile remembers the last day it paid out for.
  static UserProfile award({
    required UserProfile profile,
    required DailyChallenge challenge,
  }) {
    if (profile.lastChallengeDay == challenge.dayKey) return profile;

    final DateTime day = _dayFromKey(challenge.dayKey);
    final String? lastKey = profile.lastChallengeDay;
    final DateTime? last = lastKey == null ? null : _dayFromKey(lastKey);

    int coins = profile.coins + challenge.coins;
    final int xp = profile.xp + challenge.xp;

    // Backfilling an older day pays out but does not touch the streak.
    if (last != null && Dates.daysBetween(last, day) < 0) {
      return profile.copyWith(coins: coins, xp: xp);
    }

    final int gap = last == null ? -1 : Dates.daysBetween(last, day);
    final int streak = gap == 1 ? profile.streak + 1 : 1;

    if (streak > 0 && streak % AppConstants.streakBonusEvery == 0) {
      coins += AppConstants.streakBonusCoins;
    }

    return profile.copyWith(
      coins: coins,
      xp: xp,
      streak: streak,
      longestStreak: math.max(profile.longestStreak, streak),
      lastChallengeDay: challenge.dayKey,
    );
  }

  /// True when finishing today would land a streak bonus.
  static bool bonusDueAt(int streak) =>
      streak > 0 && streak % AppConstants.streakBonusEvery == 0;

  /// Days until the next streak bonus.
  static int daysToBonus(int streak) {
    final int into = streak % AppConstants.streakBonusEvery;
    return AppConstants.streakBonusEvery - into;
  }

  /// A streak with a gap in it is not a streak. Called on app open so the
  /// dashboard never shows a number the user did not earn.
  static UserProfile resetStaleStreak(UserProfile profile, DateTime now) {
    final String? last = profile.lastChallengeDay;
    if (last == null || profile.streak == 0) return profile;
    if (Dates.daysBetween(_dayFromKey(last), now) <= 1) return profile;
    return profile.copyWith(streak: 0);
  }

  static int completedCount(Iterable<DailyChallenge> history) =>
      history.where((DailyChallenge c) => c.isCompleted).length;

  /// Share of attempted days that were completed, 0–1.
  static double completionRate(Iterable<DailyChallenge> history) {
    final List<DailyChallenge> settled = history
        .where((DailyChallenge c) => !c.isPending)
        .toList(growable: false);
    if (settled.isEmpty) return 0;
    return completedCount(settled) / settled.length;
  }

  /// Total coins the pool would pay for a perfect week, for the UI's "worth"
  /// line. Cheap to compute, and it makes the reward economy legible.
  static int coinsForPerfectWeek() {
    final List<ChallengeTemplate> pool = ChallengePool.all;
    int sum = 0;
    for (int i = 0; i < 7 && i < pool.length; i++) {
      sum += pool[i].coins;
    }
    return sum + AppConstants.streakBonusCoins;
  }

  /// FNV-1a over the day key. Stable across runs, platforms and Dart versions.
  static int _hash(String value) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < value.length; i++) {
      hash ^= value.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static DateTime _dayFromKey(String key) {
    final List<String> parts = key.split('-');
    if (parts.length < 3) return DateTime.now();
    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }
}
