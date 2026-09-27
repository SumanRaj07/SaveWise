import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/challenge.dart';
import '../data/models/goal.dart';
import '../domain/engines/advice.dart';
import '../domain/engines/advisor_engine.dart';
import '../domain/engines/challenge_engine.dart';
import '../domain/engines/emergency_fund_engine.dart';
import '../domain/engines/goal_engine.dart';
import '../domain/engines/health_score_engine.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/live_clock.dart';
import '../widgets/rings.dart';
import 'main_shell.dart';

/// Home. Everything the brief asks to see on opening the app, in the order a
/// person actually wants it: how am I doing, what came in, what is left, what
/// am I protected against, what am I working towards, what can I do today.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter, 14, AppTheme.gutter, 108),
          physics: const BouncingScrollPhysics(),
          children: <Widget>[
            _Greeting(state: state),
            const SizedBox(height: 20),
            Reveal(child: _ScoreCard(state: state)),
            const SizedBox(height: 12),
            Reveal(delayMs: 60, child: _SalaryCard(state: state)),
            const SizedBox(height: 12),
            Reveal(delayMs: 110, child: _BudgetCard(state: state)),
            const SizedBox(height: 12),
            Reveal(
              delayMs: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: _EmergencyCard(state: state)),
                  const SizedBox(width: 12),
                  Expanded(child: _GoalCard(state: state)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Reveal(delayMs: 210, child: _ChallengeCard(state: state)),
            if (state.budgetAlerts.isNotEmpty ||
                state.reminderMessages.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              const SectionHeader(
                title: 'Needs attention',
                icon: Icons.notifications_active_outlined,
              ),
              for (final String alert in state.budgetAlerts)
                AdviceTile(
                  icon: Icons.error_outline_rounded,
                  color: AppColors.clay,
                  title: 'Budget',
                  detail: alert,
                  actionLabel: 'Open planner',
                  onAction: () => ShellNav.planner(context),
                ),
              for (final String message in state.reminderMessages)
                AdviceTile(
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.brass,
                  title: 'Bill due',
                  detail: message,
                  actionLabel: 'Open bills',
                  onAction: () => ShellNav.bills(context),
                ),
            ],
            const SizedBox(height: 18),
            const SectionHeader(
              title: 'Recommended for you',
              subtitle: 'Worked out from your own numbers, on this device.',
              icon: Icons.auto_awesome_rounded,
            ),
            if (state.score.recommendations.isEmpty)
              AdviceTile(
                icon: Icons.verified_rounded,
                color: AppColors.emerald,
                title: 'Nothing to fix',
                detail:
                    'Budget, savings and emergency fund are all where they should be. '
                    'Keep the streak going.',
                actionLabel: 'Today’s challenge',
                onAction: () =>
                    ShellScope.maybeOf(context)?.goToTab(ShellTab.challenges),
              )
            else
              for (final Recommendation r in state.score.recommendations)
                AdviceTile(
                  icon: r.severity.icon,
                  color: r.severity.color,
                  title: r.title,
                  detail: r.pointsAvailable > 0
                      ? '${r.detail} Worth up to ${r.pointsAvailable} points.'
                      : r.detail,
                  actionLabel: r.action == AdviceAction.none
                      ? null
                      : r.action.label,
                  onAction: r.action == AdviceAction.none
                      ? null
                      : () => ShellNav.go(context, r.action),
                ),
            const SizedBox(height: 8),
            _AdvisorTeaser(state: state),
            const SizedBox(height: 18),
            const SectionHeader(title: 'Quick actions'),
            const _QuickActions(),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.state});

  final AppState state;

  String get _salutation {
    final int hour = state.now.hour;
    if (hour < 5) return 'Still up';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final String name = state.profile.greetingName;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('$_salutation,', style: AppTextStyles.small),
              const SizedBox(height: 3),
              Text(
                name,
                style: AppTextStyles.screenTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Icon(Icons.calendar_today_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(Dates.longDate(state.now), style: AppTextStyles.small),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            const LiveClock(),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _MiniChip(
                  icon: Icons.monetization_on_rounded,
                  label: '${state.profile.coins}',
                  color: AppColors.brass,
                  onTap: () => ShellNav.achievements(context),
                ),
                const SizedBox(width: 6),
                _MiniChip(
                  icon: Icons.local_fire_department_rounded,
                  label: '${state.profile.streak}',
                  color: AppColors.clay,
                  onTap: () =>
                      ShellScope.maybeOf(context)?.goToTab(ShellTab.challenges),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.numericSmall
                  .copyWith(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final HealthScore score = state.score;

    return GlassCard(
      accent: score.color,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('FINANCIAL HEALTH', style: AppTextStyles.label),
              ),
              StatusPill(
                text: score.grade.label,
                color: score.color,
                icon: Icons.favorite_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ScoreRing(
            score: score.total,
            segments: <RingSegment>[
              for (final ScoreFactor f in score.factors)
                RingSegment(
                  weight: f.weight.toDouble(),
                  fill: f.ratio,
                  color: f.color,
                ),
            ],
            caption: score.isFresh ? 'Fresh start' : null,
          ),
          const SizedBox(height: 16),
          Text(
            score.grade.blurb,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          for (final ScoreFactor f in score.factors)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: f.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(f.label, style: AppTextStyles.small),
                        const SizedBox(height: 4),
                        ProgressBar(
                          progress: f.ratio,
                          color: f.color,
                          height: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${f.earned}/${f.weight}',
                    style: AppTextStyles.numericSmall.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: GhostButton(
                  label: 'Full report',
                  icon: Icons.analytics_outlined,
                  expand: true,
                  onPressed: () => ShellNav.reports(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  label: 'Ask SaveWise',
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.emerald,
                  expand: true,
                  onPressed: () => ShellNav.advisor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalaryCard extends StatelessWidget {
  const _SalaryCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final double balance = state.summary.unallocated;
    final int daysToPay = state.cycle.daysToPayday;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Monthly salary',
                  value: Money.format(state.profile.monthlySalary),
                  icon: Icons.account_balance_wallet_outlined,
                  footnote: 'Credited on the '
                      '${_ordinal(state.profile.salaryDay)}',
                ),
              ),
              Container(width: 1, height: 52, color: AppColors.hairlineSoft),
              const SizedBox(width: 16),
              Expanded(
                child: StatTile(
                  label: 'Unspent balance',
                  value: Money.format(balance),
                  icon: Icons.savings_outlined,
                  accent: balance <= 0 ? AppColors.clay : AppColors.emerald,
                  footnote: balance <= 0
                      ? 'Fully allocated'
                      : '${Money.format(state.summary.safeDailySpend)} a day is safe',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProgressBar(
            progress: state.cycle.progress,
            color: AppColors.vizSteel,
            height: 6,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Day ${state.cycle.elapsedDays} of ${state.cycle.totalDays} '
                  'in this pay cycle',
                  style: AppTextStyles.small,
                ),
              ),
              Text(
                daysToPay == 0
                    ? 'Payday today'
                    : 'Next pay in ${Dates.durationLabel(daysToPay)}',
                style: AppTextStyles.small.copyWith(color: AppColors.emeraldSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final double used = state.summary.totalSpent;
    final double left = state.summary.remaining;
    final double utilisation = state.summary.utilisation;
    final bool over = left < 0;

    return GlassCard(
      onTap: () => ShellNav.planner(context),
      accent: over ? AppColors.clay : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('THIS CYCLE’S BUDGET',
                    style: AppTextStyles.label),
              ),
              Text(
                Money.percent(utilisation),
                style: AppTextStyles.numericSmall.copyWith(
                  color: over ? AppColors.clay : AppColors.emeraldSoft,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(Money.format(used), style: AppTextStyles.moneyLarge),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'of ${Money.format(state.summary.totalLimit)}',
                  style: AppTextStyles.small,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(
            progress: utilisation,
            marker: state.cycle.progress,
            height: 9,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  over
                      ? '${Money.format(-left)} over the plan'
                      : '${Money.format(left)} left to spend',
                  style: AppTextStyles.small.copyWith(
                    color: over ? AppColors.clay : AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                'Pace marker at ${Money.percent(state.cycle.progress)}',
                style: AppTextStyles.label.copyWith(fontSize: 9),
              ),
            ],
          ),
          if (state.summary.saved > 0) ...<Widget>[
            const Divider(height: 22),
            KeyValueRow(
              label: 'Saved this cycle',
              value: Money.format(state.summary.saved),
              icon: Icons.trending_up_rounded,
              valueColor: AppColors.emerald,
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final EmergencyPlan plan = state.emergency;

    return GlassCard(
      onTap: () => ShellNav.emergency(context),
      accent: plan.readiness.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('EMERGENCY FUND', style: AppTextStyles.label),
          const SizedBox(height: 14),
          Center(
            child: ProgressRing(
              progress: plan.progressToIdeal,
              size: 86,
              strokeWidth: 8,
              color: plan.readiness.color,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    Money.percent(plan.progressToIdeal),
                    style: AppTextStyles.numericSmall.copyWith(
                      fontSize: 15,
                      color: plan.readiness.color,
                    ),
                  ),
                  Text('of ideal', style: AppTextStyles.label.copyWith(fontSize: 8)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(Money.format(plan.balance), style: AppTextStyles.moneyMedium),
          const SizedBox(height: 3),
          Text(
            'of ${Money.format(plan.idealTarget)} target',
            style: AppTextStyles.small,
          ),
          const SizedBox(height: 10),
          StatusPill(
            text: plan.readiness.label,
            color: plan.readiness.color,
            icon: plan.readiness.icon,
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final Goal? goal = state.activeGoal;

    if (goal == null) {
      return GlassCard(
        onTap: () => ShellScope.maybeOf(context)?.goToTab(ShellTab.goals),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('ACTIVE GOAL', style: AppTextStyles.label),
            const SizedBox(height: 14),
            Center(
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.hairline, width: 2),
                ),
                child: const Icon(Icons.add_rounded,
                    color: AppColors.textMuted, size: 26),
              ),
            ),
            const SizedBox(height: 14),
            Text('No goal yet', style: AppTextStyles.moneySmall),
            const SizedBox(height: 3),
            Text(
              'Name something you want and I will work out the monthly figure.',
              style: AppTextStyles.small,
            ),
          ],
        ),
      );
    }

    final GoalPlan? plan = state.planFor(goal.id);

    return GlassCard(
      onTap: () => ShellScope.maybeOf(context)?.goToTab(ShellTab.goals),
      accent: goal.priority.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('ACTIVE GOAL', style: AppTextStyles.label),
          const SizedBox(height: 14),
          Center(
            child: ProgressRing(
              progress: goal.progress,
              size: 86,
              strokeWidth: 8,
              color: goal.priority.color,
              showPercent: true,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            goal.name,
            style: AppTextStyles.moneySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            '${Money.format(goal.saved)} of ${Money.format(goal.cost)}',
            style: AppTextStyles.small,
          ),
          const SizedBox(height: 10),
          if (plan != null)
            StatusPill(
              text: plan.isComplete
                  ? 'Complete'
                  : '${Money.compact(plan.monthlyRequired)}/mo',
              color: plan.onTrack ? AppColors.emerald : AppColors.brass,
              icon: plan.onTrack
                  ? Icons.trending_up_rounded
                  : Icons.priority_high_rounded,
            ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final DailyChallenge? challenge = state.todayChallenge;
    if (challenge == null) return const SizedBox.shrink();

    final ChallengeProgress? progress = state.todayProgress;
    final bool done = challenge.isCompleted;

    return GlassCard(
      accent: done ? AppColors.emerald : AppColors.brass,
      dim: challenge.status == ChallengeStatus.skipped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                done ? Icons.task_alt_rounded : Icons.bolt_rounded,
                size: 15,
                color: done ? AppColors.emerald : AppColors.brass,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('TODAY’S CHALLENGE', style: AppTextStyles.label),
              ),
              Text(
                '+${challenge.coins} coins  ·  +${challenge.xp} XP',
                style: AppTextStyles.label.copyWith(color: AppColors.brass),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(challenge.title, style: AppTextStyles.cardTitle),
          const SizedBox(height: 5),
          Text(challenge.detail, style: AppTextStyles.small),
          if (progress != null && progress.target > 0) ...<Widget>[
            const SizedBox(height: 12),
            ProgressBar(
              progress: progress.progress,
              color: progress.broken ? AppColors.clay : AppColors.brass,
              height: 6,
            ),
            const SizedBox(height: 7),
            Text(progress.statusLine, style: AppTextStyles.small),
          ],
          const SizedBox(height: 16),
          if (challenge.isPending)
            Row(
              children: <Widget>[
                Expanded(
                  child: PrimaryButton(
                    label: challenge.isSelfReported ? 'I did it' : 'Mark done',
                    icon: Icons.check_rounded,
                    gradient: AppColors.brassSweep,
                    onPressed: () => state.completeChallenge(),
                  ),
                ),
                const SizedBox(width: 10),
                GhostButton(
                  label: 'Skip',
                  onPressed: () => state.skipChallenge(),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                StatusPill(
                  text: done ? 'Completed' : 'Skipped',
                  color: done ? AppColors.emerald : AppColors.textMuted,
                  icon: done ? Icons.check_rounded : Icons.remove_rounded,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ChallengeStreakCopy.next(state.profile.streak),
                    style: AppTextStyles.small,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AdvisorTeaser extends StatelessWidget {
  const _AdvisorTeaser({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final List<String> insights = state.insights;
    if (insights.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      onTap: () => ShellNav.advisor(context),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF10201A), Color(0xFF0B1114)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  gradient: AppColors.emeraldSweep,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 15, color: AppColors.textOnAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('SaveWise Advisor', style: AppTextStyles.cardTitle),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 14),
          for (final String insight in insights.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 3, right: 8),
                    child: Icon(Icons.trending_flat_rounded,
                        size: 13, color: AppColors.emeraldSoft),
                  ),
                  Expanded(child: Text(insight, style: AppTextStyles.small)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Tap to ask anything about your money.',
            style: AppTextStyles.small.copyWith(color: AppColors.emeraldSoft),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final List<_Action> actions = <_Action>[
      _Action('Log spend', Icons.remove_circle_outline_rounded,
          AppColors.clay, () => ShellNav.go(context, AdviceAction.logExpense)),
      _Action('Add savings', Icons.add_circle_outline_rounded,
          AppColors.emerald, () => ShellNav.emergency(context)),
      _Action('Bills', Icons.receipt_long_outlined, AppColors.brass,
          () => ShellNav.bills(context)),
      _Action('Reports', Icons.bar_chart_rounded, AppColors.vizSteel,
          () => ShellNav.reports(context)),
      _Action('Badges', Icons.workspace_premium_outlined, AppColors.vizMauve,
          () => ShellNav.achievements(context)),
      _Action('Ask AI', Icons.auto_awesome_rounded, AppColors.emeraldSoft,
          () => ShellNav.advisor(context)),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: <Widget>[
        for (final _Action a in actions)
          GlassCard(
            padding: const EdgeInsets.all(10),
            onTap: a.onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(a.icon, size: 17, color: a.color),
                ),
                const SizedBox(height: 9),
                Text(
                  a.label,
                  style: AppTextStyles.small,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Action {
  const _Action(this.label, this.icon, this.color, this.onTap);

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
