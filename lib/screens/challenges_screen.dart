import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/challenge.dart';
import '../data/models/savings_challenge.dart';
import '../data/models/user_profile.dart';
import '../domain/engines/advice.dart';
import '../domain/engines/advisor_engine.dart';
import '../domain/engines/challenge_engine.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';
import '../widgets/rings.dart';
import 'main_shell.dart';

/// Challenges and streaks — the part of the app that has to be *fun*, because
/// nothing else here can make someone open a budgeting app on a Tuesday.
///
/// Two different clocks run on this screen: the daily challenge, which resets
/// every midnight and drives the streak, and the long savings challenges from
/// the brief (52-week, daily, weekend, no-spend), which run for months.
class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final UserProfile profile = state.profile;
    final DailyChallenge? today = state.todayChallenge;
    final ChallengeProgress? progress = state.todayProgress;
    final List<DailyChallenge> history = state.challengeHistory;
    final List<SavingsChallenge> running = state.savingsChallenges;
    final List<SavingsChallenge> active = running
        .where((SavingsChallenge c) => !c.isFinished)
        .toList(growable: false);
    final List<SavingsChallenge> done = running
        .where((SavingsChallenge c) => c.isFinished)
        .toList(growable: false);

    return ScreenScaffold(
      title: 'Challenges',
      subtitle: profile.streak > 0
          ? '${profile.streak}-day streak · ${ChallengeStreakCopy.next(profile.streak)}'
          : 'Build a streak. Small wins, every day.',
      children: <Widget>[
        Reveal(child: _RewardStrip(profile: profile)),
        const SizedBox(height: 12),
        if (today != null && progress != null)
          Reveal(
            delayMs: 60,
            child: _TodayCard(challenge: today, progress: progress),
          ),
        const SizedBox(height: 12),
        Reveal(
          delayMs: 110,
          child: _StreakCard(profile: profile, history: history),
        ),
        const SizedBox(height: 22),
        SectionHeader(
          title: 'Savings challenges',
          subtitle: 'Long runs that turn into real money.',
          icon: Icons.emoji_events_outlined,
          actionLabel: 'Start one',
          onAction: () => SavingsChallengeSheets.pick(context),
        ),
        const SizedBox(height: 10),
        if (active.isEmpty && done.isEmpty)
          const _ChallengeMenu()
        else ...<Widget>[
          for (final SavingsChallenge c in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SavingsCard(challenge: c, now: state.now),
            ),
          for (final SavingsChallenge c in done)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SavingsCard(challenge: c, now: state.now),
            ),
          GhostButton(
            label: 'Start another challenge',
            icon: Icons.add_rounded,
            expand: true,
            onPressed: () => SavingsChallengeSheets.pick(context),
          ),
        ],
        const SizedBox(height: 22),
        SectionHeader(
          title: 'Recent days',
          subtitle: history.length <= 1
              ? null
              : '${ChallengeEngine.completedCount(history)} completed of '
                  '${history.length}',
          icon: Icons.history_rounded,
        ),
        const SizedBox(height: 10),
        if (history.length <= 1)
          const GlassCard(
            dim: true,
            child: Text(
              'History fills in as the days pass. A challenge you never open '
              'still counts against the streak, so it is worth a daily glance.',
              style: AppTextStyles.small,
            ),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              children: <Widget>[
                for (final DailyChallenge c in history.take(20))
                  _HistoryRow(challenge: c),
              ],
            ),
          ),
      ],
    );
  }
}

/// Level, XP, coins, streak. Gamification the brief asks for, kept to one strip
/// so it decorates the screen instead of taking it over.
class _RewardStrip extends StatelessWidget {
  const _RewardStrip({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.brass,
      child: Row(
        children: <Widget>[
          ProgressRing(
            progress: profile.levelProgress,
            size: 78,
            strokeWidth: 8,
            color: AppColors.brass,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('LVL', style: AppTextStyles.label.copyWith(fontSize: 8)),
                Text(
                  '${profile.level}',
                  style: AppTextStyles.moneyMedium.copyWith(
                    fontSize: 22,
                    color: AppColors.brass,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _Chip(
                      icon: Icons.monetization_on_rounded,
                      label: '${profile.coins}',
                      color: AppColors.brass,
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      icon: Icons.local_fire_department_rounded,
                      label: '${profile.streak}d',
                      color: profile.streak > 0
                          ? AppColors.clay
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      icon: Icons.military_tech_rounded,
                      label: 'Best ${profile.longestStreak}',
                      color: AppColors.emerald,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${profile.xpToNextLevel} XP to level ${profile.level + 1}',
                  style: AppTextStyles.small,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => ShellNav.achievements(context),
                  child: Row(
                    children: <Widget>[
                      Text(
                        'See badges',
                        style: AppTextStyles.small
                            .copyWith(color: AppColors.emeraldSoft),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppColors.emeraldSoft),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.numericSmall
                .copyWith(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

/// Today's challenge in full: what it is, how it is being measured, and what it
/// pays. Graded challenges show their live progress from the expense ledger, so
/// the card cannot be gamed by tapping "done".
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.challenge, required this.progress});

  final DailyChallenge challenge;
  final ChallengeProgress progress;

  @override
  Widget build(BuildContext context) {
    final AppState state = context.read<AppState>();
    final bool pending = challenge.isPending;
    final bool skipped = challenge.status == ChallengeStatus.skipped;
    final Color tint = challenge.isCompleted
        ? AppColors.emerald
        : skipped
            ? AppColors.clay
            : progress.broken
                ? AppColors.clay
                : AppColors.brass;

    return GlassCard(
      accent: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('TODAY', style: AppTextStyles.label),
              const Spacer(),
              StatusPill(
                text: challenge.isCompleted
                    ? 'Completed'
                    : skipped
                        ? 'Missed'
                        : progress.met
                            ? 'Target met'
                            : 'In progress',
                color: tint,
                icon: challenge.isCompleted
                    ? Icons.check_circle_rounded
                    : skipped
                        ? Icons.remove_circle_outline_rounded
                        : Icons.schedule_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(challenge.title, style: AppTextStyles.cardTitle),
          const SizedBox(height: 6),
          Text(
            challenge.detail,
            style: AppTextStyles.small.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          ProgressBar(
            progress: progress.progress,
            color: tint,
            height: 9,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(progress.statusLine, style: AppTextStyles.small),
              ),
              Text(
                '+${challenge.coins} coins · +${challenge.xp} XP',
                style: AppTextStyles.numericSmall
                    .copyWith(fontSize: 11, color: AppColors.brass),
              ),
            ],
          ),
          if (challenge.isSelfReported) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'This one is on your honour — the app cannot see it in your '
              'spending.',
              style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (pending) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: PrimaryButton(
                    label: progress.met ? 'Claim reward' : 'Mark done',
                    icon: Icons.check_rounded,
                    onPressed: () => state.completeChallenge(),
                  ),
                ),
                const SizedBox(width: 10),
                GhostButton(
                  label: 'Skip',
                  color: AppColors.textMuted,
                  onPressed: () => state.skipChallenge(),
                ),
              ],
            ),
          ],
          if (!challenge.isSelfReported && pending) ...<Widget>[
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () => ShellNav.go(context, AdviceAction.logExpense),
                icon: const Icon(Icons.add_card_outlined, size: 16),
                label: const Text('Log what you spent'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Streak mechanics, stated plainly. Nothing here is a surprise, which is the
/// point — a reward system you cannot predict does not change behaviour.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.profile, required this.history});

  final UserProfile profile;
  final List<DailyChallenge> history;

  @override
  Widget build(BuildContext context) {
    final double rate = ChallengeEngine.completionRate(history);
    final int toBonus = ChallengeEngine.daysToBonus(profile.streak);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.local_fire_department_rounded,
                  size: 16, color: AppColors.clay),
              const SizedBox(width: 8),
              Text('Streak', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Current',
                  value: '${profile.streak}',
                  footnote: profile.streak == 1 ? 'day' : 'days',
                  icon: Icons.bolt_rounded,
                  accent: AppColors.clay,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Completed',
                  value: '${ChallengeEngine.completedCount(history)}',
                  footnote: history.isEmpty
                      ? 'challenges'
                      : '${Money.percent(rate)} of attempts',
                  icon: Icons.done_all_rounded,
                  accent: AppColors.emerald,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DayStrip(history: history),
          const SizedBox(height: 14),
          KeyValueRow(
            label: 'Next bonus',
            value: ChallengeEngine.bonusDueAt(profile.streak)
                ? '+${AppConstants.streakBonusCoins} coins today'
                : 'in $toBonus ${toBonus == 1 ? 'day' : 'days'}',
            icon: Icons.card_giftcard_rounded,
            dense: true,
          ),
          KeyValueRow(
            label: 'A perfect week is worth',
            value: '${ChallengeEngine.coinsForPerfectWeek()} coins',
            icon: Icons.workspace_premium_outlined,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// Last seven days as dots. The fastest possible read on "am I keeping this up".
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.history});

  final List<DailyChallenge> history;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final Map<String, DailyChallenge> byDay = <String, DailyChallenge>{
      for (final DailyChallenge c in history) c.dayKey: c,
    };

    return Row(
      children: <Widget>[
        for (int back = 6; back >= 0; back--)
          Expanded(
            child: _DayDot(
              day: now.subtract(Duration(days: back)),
              challenge: byDay[Dates.dayKey(now.subtract(Duration(days: back)))],
              isToday: back == 0,
            ),
          ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.day,
    required this.challenge,
    required this.isToday,
  });

  final DateTime day;
  final DailyChallenge? challenge;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final ChallengeStatus? status = challenge?.status;
    final Color color = switch (status) {
      ChallengeStatus.completed => AppColors.emerald,
      ChallengeStatus.skipped => AppColors.clay,
      ChallengeStatus.pending => AppColors.brass,
      null => AppColors.hairline,
    };
    final bool filled = status == ChallengeStatus.completed;

    return Column(
      children: <Widget>[
        Container(
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isToday ? AppColors.textSecondary : color.withValues(alpha: 0.35),
            ),
          ),
          child: Center(
            child: Icon(
              switch (status) {
                ChallengeStatus.completed => Icons.check_rounded,
                ChallengeStatus.skipped => Icons.close_rounded,
                ChallengeStatus.pending => Icons.more_horiz_rounded,
                null => Icons.remove_rounded,
              },
              size: 14,
              color: filled ? AppColors.textOnAccent : color,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          Dates.weekdayShort(day),
          style: AppTextStyles.label.copyWith(fontSize: 8.5),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.challenge});

  final DailyChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final Color tint = switch (challenge.status) {
      ChallengeStatus.completed => AppColors.emerald,
      ChallengeStatus.skipped => AppColors.clay,
      ChallengeStatus.pending => AppColors.brass,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: <Widget>[
          Icon(
            switch (challenge.status) {
              ChallengeStatus.completed => Icons.check_circle_rounded,
              ChallengeStatus.skipped => Icons.cancel_outlined,
              ChallengeStatus.pending => Icons.schedule_rounded,
            },
            size: 17,
            color: tint,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  challenge.title,
                  style: AppTextStyles.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  Dates.mediumDate(_dayOf(challenge.dayKey)),
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ),
          if (challenge.isCompleted)
            Text(
              '+${challenge.coins}',
              style: AppTextStyles.numericSmall
                  .copyWith(fontSize: 11, color: AppColors.brass),
            ),
        ],
      ),
    );
  }

  static DateTime _dayOf(String key) {
    final List<String> parts = key.split('-');
    if (parts.length < 3) return DateTime.now();
    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }
}

/// A running savings challenge, with every step tickable. Ticking a step logs
/// the money as savings, which is what stops these from being a sticker chart.
class _SavingsCard extends StatefulWidget {
  const _SavingsCard({required this.challenge, required this.now});

  final SavingsChallenge challenge;
  final DateTime now;

  @override
  State<_SavingsCard> createState() => _SavingsCardState();
}

class _SavingsCardState extends State<_SavingsCard> {
  bool _showAll = false;

  static const int _preview = 14;

  @override
  Widget build(BuildContext context) {
    final AppState state = context.read<AppState>();
    final SavingsChallenge c = widget.challenge;
    final Color accent = c.type.accent;
    final int expected = c.expectedStepsBy(widget.now);
    final bool behind = !c.isFinished && c.stepsDone < expected;
    final int visible = _showAll ? c.totalSteps : math.min(_preview, c.totalSteps);

    return GlassCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(c.type.icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(c.type.label, style: AppTextStyles.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      'Started ${Dates.mediumDate(c.startDate)}',
                      style: AppTextStyles.small,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _end(context, state),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.more_horiz_rounded,
                    size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(Money.format(c.totalSaved), style: AppTextStyles.moneyMedium),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'of ${Money.format(c.targetTotal)}',
                  style: AppTextStyles.small,
                ),
              ),
              const Spacer(),
              if (c.isFinished)
                StatusPill(
                  text: 'Finished',
                  color: AppColors.emerald,
                  icon: Icons.emoji_events_rounded,
                  filled: true,
                )
              else
                StatusPill(
                  text: behind
                      ? '${expected - c.stepsDone} behind'
                      : 'On track',
                  color: behind ? AppColors.clay : AppColors.emerald,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(progress: c.progress, color: accent, height: 8),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text(
                '${c.stepsDone} of ${c.totalSteps} '
                '${c.type.stepNoun.toLowerCase()}s done',
                style: AppTextStyles.small,
              ),
              const Spacer(),
              if (c.streak > 1)
                Text(
                  '${c.streak} in a row',
                  style: AppTextStyles.small.copyWith(color: accent),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (int i = 0; i < visible; i++)
                _StepChip(
                  step: i,
                  challenge: c,
                  isNext: i == c.nextStep,
                  onTap: () => state.toggleSavingsStep(
                    challengeId: c.id,
                    step: i,
                  ),
                ),
            ],
          ),
          if (c.totalSteps > _preview) ...<Widget>[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll
                      ? 'Show fewer'
                      : 'Show all ${c.totalSteps} ${c.type.stepNoun.toLowerCase()}s',
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Next: ${c.type.stepNoun} ${c.nextStep + 1} · '
            '${Money.format(c.amountForStep(c.nextStep))}',
            style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _end(BuildContext context, AppState state) async {
    final SavingsChallenge c = widget.challenge;
    final bool yes = await AppSheet.confirm(
      context: context,
      title: c.isFinished ? 'Clear this challenge?' : 'End this challenge?',
      message: c.isFinished
          ? 'It stays in your savings history — only the card goes away.'
          : 'The ${Money.format(c.totalSaved)} you already saved stays saved. '
              'Only the challenge is removed.',
      confirmLabel: c.isFinished ? 'Clear' : 'End it',
    );
    if (yes) await state.endSavingsChallenge(c.id);
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.step,
    required this.challenge,
    required this.isNext,
    required this.onTap,
  });

  final int step;
  final SavingsChallenge challenge;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool done = challenge.completedSteps.contains(step);
    final Color accent = challenge.type.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: done ? accent : AppColors.slateHigh,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: done
                ? accent
                : isNext
                    ? accent.withValues(alpha: 0.6)
                    : AppColors.hairline,
            width: isNext && !done ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '${step + 1}',
              style: AppTextStyles.numericSmall.copyWith(
                fontSize: 12,
                color: done ? AppColors.textOnAccent : AppColors.textSecondary,
              ),
            ),
            Text(
              Money.compact(challenge.amountForStep(step)),
              style: AppTextStyles.label.copyWith(
                fontSize: 7.5,
                color: done
                    ? AppColors.textOnAccent.withValues(alpha: 0.8)
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four challenge types, shown as an invitation when none are running.
class _ChallengeMenu extends StatelessWidget {
  const _ChallengeMenu();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final SavingsChallengeType type in SavingsChallengeType.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              onTap: () => SavingsChallengeSheets.start(context, type),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: type.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(type.icon, size: 19, color: type.accent),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(type.label,
                                  style: AppTextStyles.bodyStrong),
                            ),
                            Text(
                              '${type.totalSteps} ${type.stepNoun.toLowerCase()}s',
                              style: AppTextStyles.label,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type.blurb,
                          style: AppTextStyles.small.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Sheets for picking and configuring a savings challenge.
abstract final class SavingsChallengeSheets {
  static Future<void> pick(BuildContext context) {
    return AppSheet.show<void>(
      context: context,
      title: 'Start a savings challenge',
      subtitle: 'Pick the shape that fits how you actually spend.',
      child: const _PickList(),
    );
  }

  static Future<void> start(BuildContext context, SavingsChallengeType type) {
    return AppSheet.show<void>(
      context: context,
      title: type.label,
      subtitle: type.blurb,
      child: _StartForm(type: type),
    );
  }

  /// A sensible starting unit, derived from the user's own money rather than a
  /// round number pulled out of the air.
  static double suggestedBase(SavingsChallengeType type, UserProfile profile) {
    final int days = Dates.daysInMonth(DateTime.now());
    final double wants = profile.dailyDiscretionary(days);
    final double raw = switch (type) {
      // 52-week: the unit multiplies up to 1378× over the year, so the unit
      // itself has to be small or the last months are impossible.
      SavingsChallengeType.fiftyTwoWeek => profile.monthlySalary * 0.0005,
      SavingsChallengeType.daily => wants * 0.25,
      SavingsChallengeType.weekend => wants * 0.3,
      SavingsChallengeType.noSpend => wants,
    };
    return Money.niceRound(math.max(1.0, raw));
  }
}

class _PickList extends StatelessWidget {
  const _PickList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final SavingsChallengeType type in SavingsChallengeType.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              onTap: () {
                Navigator.of(context).pop();
                SavingsChallengeSheets.start(context, type);
              },
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Icon(type.icon, size: 18, color: type.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(type.label, style: AppTextStyles.bodyStrong),
                        const SizedBox(height: 3),
                        Text(
                          '${type.totalSteps} ${type.stepNoun.toLowerCase()}s',
                          style: AppTextStyles.small,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StartForm extends StatefulWidget {
  const _StartForm({required this.type});

  final SavingsChallengeType type;

  @override
  State<_StartForm> createState() => _StartFormState();
}

class _StartFormState extends State<_StartForm> {
  final TextEditingController _base = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final UserProfile profile = context.read<AppState>().profile;
    _base.text = Money.plain(
      SavingsChallengeSheets.suggestedBase(widget.type, profile),
    );
  }

  @override
  void dispose() {
    _base.dispose();
    super.dispose();
  }

  double get _value => AmountField.valueOf(_base) ?? 0;

  /// Preview the whole run so nobody signs up for a 52-week challenge without
  /// seeing what week 52 costs.
  SavingsChallenge get _preview => SavingsChallenge(
        id: 'preview',
        type: widget.type,
        startDate: DateTime.now(),
        baseAmount: _value,
      );

  Future<void> _submit() async {
    if (_value <= 0 || _busy) return;
    setState(() => _busy = true);
    await context.read<AppState>().startSavingsChallenge(
          type: widget.type,
          baseAmount: _value,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final SavingsChallenge p = _preview;
    final bool ladder = widget.type == SavingsChallengeType.fiftyTwoWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AmountField(
          controller: _base,
          label: ladder ? 'Week 1 amount' : 'Amount per ${widget.type.stepNoun.toLowerCase()}',
          helper: ladder
              ? 'Week 2 doubles it, week 3 triples it, and so on.'
              : 'The same amount each ${widget.type.stepNoun.toLowerCase()}.',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        GlassCard(
          dim: true,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: <Widget>[
              KeyValueRow(
                label: 'Total if you finish',
                value: Money.format(p.targetTotal),
                icon: Icons.flag_outlined,
                valueColor: AppColors.emerald,
                strong: true,
              ),
              KeyValueRow(
                label: 'Length',
                value: '${p.totalSteps} ${widget.type.stepNoun.toLowerCase()}s',
                icon: Icons.timeline_rounded,
                dense: true,
              ),
              if (ladder)
                KeyValueRow(
                  label: 'The last week costs',
                  value: Money.format(p.amountForStep(p.totalSteps - 1)),
                  icon: Icons.trending_up_rounded,
                  dense: true,
                ),
              KeyValueRow(
                label: 'Each step logs as savings',
                value: 'Yes',
                icon: Icons.savings_outlined,
                dense: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Start the challenge',
          icon: Icons.play_arrow_rounded,
          busy: _busy,
          onPressed: _value > 0 ? _submit : null,
        ),
      ],
    );
  }
}
