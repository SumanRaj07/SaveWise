import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/achievement_catalog.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/user_profile.dart';
import '../domain/engines/achievement_engine.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/rings.dart';

/// The badge cabinet.
///
/// Locked badges are shown, not hidden, and every one carries the exact figure
/// still needed. A badge you cannot see is not a target; a badge that says
/// "two more months of income" is.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<AchievementProgress> all = state.achievementProgress;
    final AchievementInputs inputs = state.achievementInputs;

    final List<AchievementProgress> unlocked = all
        .where((AchievementProgress a) => a.isUnlocked)
        .toList(growable: false);
    final AchievementProgress? next = AchievementEngine.nextUp(
      inputs: inputs,
      unlockedAt: state.unlockedAt,
    );

    return ScreenScaffold(
      title: 'Achievements',
      subtitle: '${unlocked.length} of ${all.length} earned',
      showBack: true,
      children: <Widget>[
        _LevelCard(profile: state.profile, unlocked: unlocked.length, total: all.length),
        const SizedBox(height: 16),
        if (next != null) ...<Widget>[
          _NextUpCard(progress: next, inputs: inputs),
          const SizedBox(height: 16),
        ],
        for (final AchievementGroup group in AchievementGroup.values) ...<Widget>[
          _GroupBlock(
            group: group,
            items: AchievementEngine.forGroup(
              inputs: inputs,
              unlockedAt: state.unlockedAt,
              group: group,
            ),
            inputs: inputs,
          ),
          const SizedBox(height: 18),
        ],
        _HowCard(inputs: inputs),
      ],
    );
  }
}

// ------------------------------------------------------------------- header

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.profile,
    required this.unlocked,
    required this.total,
  });

  final UserProfile profile;
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.brass,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF17201B), Color(0xFF0D1215)],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              ProgressRing(
                progress: profile.levelProgress,
                size: 86,
                strokeWidth: 8,
                color: AppColors.brass,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('LEVEL', style: AppTextStyles.label.copyWith(fontSize: 8)),
                    Text('${profile.level}',
                        style: AppTextStyles.moneyMedium
                            .copyWith(color: AppColors.brass)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('$unlocked of $total badges',
                        style: AppTextStyles.cardTitle),
                    const SizedBox(height: 6),
                    Text(
                      '${profile.xpToNextLevel} XP to level ${profile.level + 1}. '
                      'Every ${AppConstants.xpPerLevel} XP is a level.',
                      style: AppTextStyles.small,
                    ),
                    const SizedBox(height: 12),
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
                          color: AppColors.clay,
                        ),
                        const SizedBox(width: 8),
                        _Chip(
                          icon: Icons.bolt_rounded,
                          label: '${profile.xp} XP',
                          color: AppColors.emerald,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProgressBar(
            progress: total == 0 ? 0 : unlocked / total,
            color: AppColors.brass,
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
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.numericSmall
                  .copyWith(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.progress, required this.inputs});

  final AchievementProgress progress;
  final AchievementInputs inputs;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: progress.def.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('CLOSEST BADGE', style: AppTextStyles.label),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _Medal(def: progress.def, unlocked: false, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(progress.def.title, style: AppTextStyles.cardTitle),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.percent}% of the way there',
                      style: AppTextStyles.small
                          .copyWith(color: progress.def.accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ProgressBar(progress: progress.progress, color: progress.def.accent),
          const SizedBox(height: 10),
          Text(
            _remainingSentence(progress, inputs),
            style: AppTextStyles.small,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- groups

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.group,
    required this.items,
    required this.inputs,
  });

  final AchievementGroup group;
  final List<AchievementProgress> items;
  final AchievementInputs inputs;

  @override
  Widget build(BuildContext context) {
    final int done =
        items.where((AchievementProgress a) => a.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: group.label,
          subtitle: '$done of ${items.length} earned',
          icon: group.icon,
        ),
        for (final AchievementProgress a in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BadgeRow(progress: a, inputs: inputs),
          ),
      ],
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.progress, required this.inputs});

  final AchievementProgress progress;
  final AchievementInputs inputs;

  @override
  Widget build(BuildContext context) {
    final AchievementDef def = progress.def;
    final bool got = progress.isUnlocked;

    return GlassCard(
      dim: !got,
      accent: got ? def.accent : null,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Medal(def: def, unlocked: got, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        def.title,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: got
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (got)
                      StatusPill(
                        text: 'Earned',
                        color: def.accent,
                        icon: Icons.check_rounded,
                        filled: true,
                      )
                    else
                      Text(
                        '${progress.percent}%',
                        style: AppTextStyles.numericSmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(def.detail, style: AppTextStyles.small),
                const SizedBox(height: 10),
                if (got)
                  Text(
                    'Unlocked ${Dates.mediumDate(progress.unlockedAt!)}',
                    style: AppTextStyles.small
                        .copyWith(fontSize: 11, color: AppColors.textMuted),
                  )
                else ...<Widget>[
                  ProgressBar(
                    progress: progress.progress,
                    height: 6,
                    color: def.accent,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _remainingSentence(progress, inputs),
                    style: AppTextStyles.small
                        .copyWith(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({
    required this.def,
    required this.unlocked,
    required this.size,
  });

  final AchievementDef def;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unlocked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[def.accent, def.accent.withValues(alpha: 0.55)],
              )
            : null,
        color: unlocked ? null : AppColors.slateHigh,
        border: Border.all(
          color: unlocked ? Colors.transparent : AppColors.hairline,
        ),
        boxShadow: unlocked
            ? <BoxShadow>[
                BoxShadow(
                  color: def.accent.withValues(alpha: 0.28),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Icon(
        unlocked ? def.icon : Icons.lock_outline_rounded,
        size: size * 0.42,
        color: unlocked ? AppColors.textOnAccent : AppColors.textMuted,
      ),
    );
  }
}

/// Why the savings tiers are income multiples rather than fixed sums. Worth
/// saying once, plainly, so the badges do not look arbitrary.
class _HowCard extends StatelessWidget {
  const _HowCard({required this.inputs});

  final AchievementInputs inputs;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      dim: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.help_outline_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text('HOW BADGES ARE MEASURED', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 12),
          KeyValueRow(
            label: 'Saved so far',
            value: inputs.monthlySalary <= 0
                ? Money.format(inputs.lifetimeSaved)
                : '${Money.format(inputs.lifetimeSaved)} · '
                    '${inputs.savingsMultiple.toStringAsFixed(2)}× salary',
            dense: true,
          ),
          KeyValueRow(
            label: 'Goals finished',
            value: '${inputs.goalsCompleted}',
            dense: true,
          ),
          KeyValueRow(
            label: 'Longest streak',
            value: '${inputs.longestStreak} days',
            dense: true,
          ),
          KeyValueRow(
            label: 'Emergency fund',
            value: Money.percent(inputs.emergencyFraction),
            dense: true,
          ),
          const SizedBox(height: 10),
          Text(
            'Savings badges are multiples of your own monthly income, not fixed '
            'amounts. A fixed sum means something different to every earner and '
            'in every currency; a month of income means the same thing to '
            'everyone.',
            style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Turns "0.8 of a 1.0 threshold" into something a person can act on. Each
/// metric needs its own units, which is why this is not a single format call.
String _remainingSentence(AchievementProgress p, AchievementInputs inputs) {
  if (p.isUnlocked) return 'Earned.';
  final double gap = p.remaining;

  switch (p.def.metric) {
    case AchievementMetric.savingsMultiple:
      if (inputs.monthlySalary <= 0) {
        return 'Set your salary so savings can be measured against it.';
      }
      final double money = gap * inputs.monthlySalary;
      return '${Money.format(money)} more saved to earn this.';
    case AchievementMetric.goalsCompleted:
      final int goals = gap.ceil();
      return goals == 1
          ? 'One more finished goal.'
          : '$goals more finished goals.';
    case AchievementMetric.streakDays:
      final int days = gap.ceil();
      return days == 1
          ? 'One more day on the streak.'
          : '$days more days on the streak. Best so far: '
              '${inputs.longestStreak}.';
    case AchievementMetric.emergencyFraction:
      return '${Money.percent(gap)} more of the six-month fund.';
  }
}
