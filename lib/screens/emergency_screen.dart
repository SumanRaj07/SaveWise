import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/emergency_fund.dart';
import '../domain/engines/emergency_fund_engine.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';
import '../widgets/rings.dart';

/// The emergency fund.
///
/// The brief asks for current amount, recommended amount, remaining amount, a
/// percentage and a readiness level. The organising idea of this screen is that
/// the fund has *two* finish lines — three months of essentials is the floor
/// and six is the goal — so almost everything here is shown against both.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final EmergencyPlan plan = state.emergency;
    final EmergencyFund fund = state.fund;
    final List<FundEntry> entries = fund.recent;

    return ScreenScaffold(
      title: 'Emergency Fund',
      subtitle: plan.essentialsMonthly <= 0
          ? 'Set a budget and this sizes itself'
          : '${plan.readiness.label} · '
              '${_months(plan.coverageMonths)} of essentials covered',
      showBack: true,
      floating: FloatingActionButton.extended(
        onPressed: () => EmergencySheets.deposit(context),
        backgroundColor: AppColors.emerald,
        foregroundColor: AppColors.textOnAccent,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('Add money', style: AppTextStyles.button),
      ),
      children: <Widget>[
        Reveal(child: _Hero(plan: plan)),
        const SizedBox(height: 12),
        Reveal(delayMs: 60, child: _Targets(plan: plan)),
        const SizedBox(height: 12),
        Reveal(
          delayMs: 110,
          child: _Pace(plan: plan, fund: fund, capacity: state.monthlyCapacity),
        ),
        if (entries.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Reveal(delayMs: 160, child: _History(entries: entries)),
        ],
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Ledger',
          subtitle: entries.isEmpty
              ? null
              : '${entries.length} '
                  '${entries.length == 1 ? 'movement' : 'movements'}',
          icon: Icons.receipt_long_outlined,
          actionLabel: plan.balance > 0 ? 'Withdraw' : null,
          onAction: plan.balance > 0
              ? () => EmergencySheets.withdraw(context)
              : null,
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          EmptyState(
            icon: Icons.shield_outlined,
            title: 'The fund is empty',
            message: 'Even a small first deposit changes your readiness band '
                'and lifts your health score. Start with anything.',
            actionLabel: 'Add the first deposit',
            onAction: () => EmergencySheets.deposit(context),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              children: <Widget>[
                for (final FundEntry entry in entries)
                  _EntryRow(entry: entry),
              ],
            ),
          ),
        const SizedBox(height: 14),
        _WhyCard(plan: plan),
      ],
    );
  }

  static String _months(double value) {
    if (value <= 0) return 'no months';
    if (value >= 12) return '12+ months';
    final String n = value >= 10
        ? value.round().toString()
        : value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return '$n ${n == '1' ? 'month' : 'months'}';
  }
}

/// Balance, ring and readiness band — the answer to "am I covered?".
class _Hero extends StatelessWidget {
  const _Hero({required this.plan});

  final EmergencyPlan plan;

  @override
  Widget build(BuildContext context) {
    final EmergencyReadiness readiness = plan.readiness;
    return GlassCard(
      accent: readiness.color,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              ProgressRing(
                progress: plan.progressToIdeal,
                size: 116,
                strokeWidth: 11,
                color: readiness.color,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${plan.percentOfIdeal}%',
                      style: AppTextStyles.moneyMedium.copyWith(
                        fontSize: 24,
                        color: readiness.color,
                      ),
                    ),
                    Text('of 6 months', style: AppTextStyles.label),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('CURRENT FUND', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Money.format(plan.balance),
                        style: AppTextStyles.moneyLarge,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StatusPill(
                      text: readiness.label,
                      color: readiness.color,
                      icon: readiness.icon,
                      filled: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: readiness.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(color: readiness.color.withValues(alpha: 0.22)),
            ),
            child: Text(
              readiness.blurb,
              style: AppTextStyles.small.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two finish lines, each with its own bar and its own remaining amount.
class _Targets extends StatelessWidget {
  const _Targets({required this.plan});

  final EmergencyPlan plan;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.flag_outlined, size: 16, color: AppColors.brass),
              const SizedBox(width: 8),
              Text('Targets', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 16),
          LabelledBar(
            label: '${AppConstants.emergencyMinMonths} months — the floor',
            value: plan.hasMinimum
                ? 'Reached'
                : '${Money.format(plan.remainingToMin)} to go',
            progress: plan.progressToMin,
            color: plan.hasMinimum ? AppColors.emerald : AppColors.clay,
            icon: Icons.horizontal_rule_rounded,
            footnote: 'Target ${Money.format(plan.minTarget)}',
          ),
          const SizedBox(height: 16),
          LabelledBar(
            label: '${AppConstants.emergencyIdealMonths} months — the goal',
            value: plan.isComplete
                ? 'Complete'
                : '${Money.format(plan.remainingToIdeal)} to go',
            progress: plan.progressToIdeal,
            color: plan.isComplete ? AppColors.emerald : AppColors.brass,
            icon: Icons.verified_outlined,
            footnote: 'Target ${Money.format(plan.idealTarget)}',
          ),
          const Divider(height: 26),
          KeyValueRow(
            label: 'Essential spending a month',
            value: Money.format(plan.essentialsMonthly),
            icon: Icons.receipt_outlined,
            dense: true,
          ),
          KeyValueRow(
            label: 'Recommended fund',
            value: Money.format(plan.idealTarget),
            icon: Icons.savings_outlined,
            dense: true,
          ),
          KeyValueRow(
            label: 'Still needed',
            value: plan.isComplete
                ? 'Nothing — done'
                : Money.format(plan.remainingToIdeal),
            icon: Icons.trending_flat_rounded,
            valueColor: plan.isComplete ? AppColors.emerald : null,
            dense: true,
          ),
          KeyValueRow(
            label: 'Cover if income stopped',
            value: plan.coverageMonths <= 0
                ? '—'
                : Dates.durationLabel(
                    (plan.coverageMonths * 30).round(),
                  ),
            icon: Icons.timelapse_rounded,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// How long the fund takes to finish at three different paces. The point of the
/// card is that the answer is always "sooner than you think, if you commit".
class _Pace extends StatelessWidget {
  const _Pace({
    required this.plan,
    required this.fund,
    required this.capacity,
  });

  final EmergencyPlan plan;
  final EmergencyFund fund;
  final double capacity;

  @override
  Widget build(BuildContext context) {
    final double thisMonth = fund.contributedThisMonth;
    final double suggested = plan.suggestedMonthly;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.speed_rounded, size: 16, color: AppColors.emerald),
              const SizedBox(width: 8),
              Text('Getting there', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Suggested monthly',
                  value: Money.format(suggested),
                  footnote: 'Hits the floor in a year',
                  icon: Icons.recommend_outlined,
                  accent: AppColors.emerald,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Added this month',
                  value: Money.format(thisMonth),
                  footnote: thisMonth >= suggested && suggested > 0
                      ? 'Ahead of the suggestion'
                      : 'Suggestion not met yet',
                  icon: Icons.calendar_today_outlined,
                  accent: thisMonth >= suggested && suggested > 0
                      ? AppColors.emerald
                      : AppColors.brass,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (plan.isComplete)
            KeyValueRow(
              label: 'Six months of cover',
              value: 'Complete',
              icon: Icons.workspace_premium_rounded,
              valueColor: AppColors.emerald,
              strong: true,
            )
          else ...<Widget>[
            _PaceRow(
              label: 'At the suggested ${Money.format(suggested)} a month',
              plan: plan,
              monthly: suggested,
            ),
            if (thisMonth > 0)
              _PaceRow(
                label: 'At this month\'s ${Money.format(thisMonth)}',
                plan: plan,
                monthly: thisMonth,
              ),
            if (capacity > 0)
              _PaceRow(
                label: 'If you saved your whole ${Money.format(capacity)} '
                    'surplus',
                plan: plan,
                monthly: capacity,
                accent: AppColors.brass,
              ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: GhostButton(
                  label: 'Add ${Money.compact(Money.niceRound(suggested))}',
                  icon: Icons.bolt_rounded,
                  expand: true,
                  onPressed: suggested <= 0
                      ? null
                      : () => EmergencySheets.deposit(
                            context,
                            preset: Money.niceRound(suggested),
                          ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  label: 'Withdraw',
                  icon: Icons.north_east_rounded,
                  color: AppColors.clay,
                  expand: true,
                  onPressed: plan.balance <= 0
                      ? null
                      : () => EmergencySheets.withdraw(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaceRow extends StatelessWidget {
  const _PaceRow({
    required this.label,
    required this.plan,
    required this.monthly,
    this.accent,
  });

  final String label;
  final EmergencyPlan plan;
  final double monthly;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final int toMin = plan.monthsToMin(monthly);
    final int toIdeal = plan.monthsToIdeal(monthly);
    final String value;
    if (monthly <= 0 || toIdeal < 0) {
      value = 'never';
    } else if (plan.hasMinimum) {
      value = '$toIdeal mo to the goal';
    } else {
      value = '$toMin mo to the floor · $toIdeal to the goal';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(
              color: accent ?? AppColors.emerald,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Text(label, style: AppTextStyles.small)),
          const SizedBox(width: 10),
          Text(
            value,
            style: AppTextStyles.numericSmall.copyWith(
              color: accent ?? AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Net movement per month for the last six months, so a stalled fund is
/// obvious without reading the ledger.
class _History extends StatelessWidget {
  const _History({required this.entries});

  final List<FundEntry> entries;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final List<BarDatum> bars = <BarDatum>[];
    for (int back = 5; back >= 0; back--) {
      final DateTime month = DateTime(now.year, now.month - back);
      double net = 0;
      for (final FundEntry e in entries) {
        if (e.date.year == month.year && e.date.month == month.month) {
          net += e.amount;
        }
      }
      bars.add(
        BarDatum(
          label: Dates.monthShort(month),
          value: net < 0 ? 0 : net,
          color: net < 0 ? AppColors.clay : AppColors.emerald,
        ),
      );
    }
    final bool anything = bars.any((BarDatum b) => b.value > 0);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.bar_chart_rounded,
                  size: 16, color: AppColors.vizTeal),
              const SizedBox(width: 8),
              Text('Last six months', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 16),
          if (!anything)
            Text(
              'Nothing added in the last six months.',
              style: AppTextStyles.small,
            )
          else
            BarChart(
              bars: bars,
              height: 130,
              valueFormatter: (double v) => Money.compact(v),
            ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final FundEntry entry;

  @override
  Widget build(BuildContext context) {
    final bool out = entry.isWithdrawal;
    final Color tint = out ? AppColors.clay : AppColors.emerald;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      onLongPress: () => _delete(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                out ? Icons.north_east_rounded : Icons.south_west_rounded,
                size: 16,
                color: tint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.note.trim().isEmpty
                        ? (out ? 'Withdrawal' : 'Deposit')
                        : entry.note.trim(),
                    style: AppTextStyles.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(Dates.mediumDate(entry.date), style: AppTextStyles.small),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Money.formatSigned(entry.amount),
              style: AppTextStyles.numericSmall.copyWith(color: tint),
            ),
            IconButton(
              onPressed: () => _delete(context),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded,
                  size: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final AppState state = context.read<AppState>();
    final bool yes = await AppSheet.confirm(
      context: context,
      title: 'Remove this entry?',
      message: 'The balance recalculates from what is left in the ledger.',
    );
    if (yes) await state.deleteFundEntry(entry.id);
  }
}

/// A short, unglamorous explanation. The fund is the least exciting and most
/// important number in the app, so it gets an argument rather than a badge.
class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.plan});

  final EmergencyPlan plan;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      dim: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('WHY THIS COMES FIRST', style: AppTextStyles.label),
          const SizedBox(height: 10),
          Text(
            'The target is ${AppConstants.emergencyMinMonths} to '
            '${AppConstants.emergencyIdealMonths} months of essential '
            'spending — rent, food, transport, medical — not of your whole '
            'salary. A fund exists to keep the lights on while you sort '
            'things out, not to keep your lifestyle intact.\n\n'
            'It is worth ${AppConstants.weightEmergency} points of your health '
            'score for the same reason: without it, one bad month undoes a '
            'year of goal progress.',
            style: AppTextStyles.small.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Deposit and withdrawal sheets. Public so the dashboard and profile can open
/// them without pushing this screen first.
abstract final class EmergencySheets {
  static Future<void> deposit(BuildContext context, {double? preset}) {
    return AppSheet.show<void>(
      context: context,
      title: 'Add to emergency fund',
      subtitle: 'Counts towards your savings for this month.',
      child: _MoveForm(withdrawal: false, preset: preset),
    );
  }

  static Future<void> withdraw(BuildContext context) {
    return AppSheet.show<void>(
      context: context,
      title: 'Withdraw from the fund',
      subtitle: 'Only for a real emergency — that is what it is for.',
      child: const _MoveForm(withdrawal: true),
    );
  }
}

class _MoveForm extends StatefulWidget {
  const _MoveForm({required this.withdrawal, this.preset});

  final bool withdrawal;
  final double? preset;

  @override
  State<_MoveForm> createState() => _MoveFormState();
}

class _MoveFormState extends State<_MoveForm> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _countAsSavings = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.preset != null && widget.preset! > 0) {
      _amount.text = Money.plain(widget.preset!);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final double? value = AmountField.valueOf(_amount);
    if (value == null || value <= 0 || _busy) return;
    setState(() => _busy = true);
    final AppState state = context.read<AppState>();
    if (widget.withdrawal) {
      await state.withdrawFromEmergencyFund(
        amount: value,
        note: _note.text.trim(),
      );
    } else {
      await state.addToEmergencyFund(
        amount: value,
        note: _note.text.trim(),
        logAsSavings: _countAsSavings,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.read<AppState>();
    final EmergencyPlan plan = state.emergency;
    final bool out = widget.withdrawal;

    final List<double> quick = out
        ? <double>[
            Money.niceRound(plan.balance * 0.25),
            Money.niceRound(plan.balance * 0.5),
            Money.niceRound(plan.balance),
          ]
        : <double>[
            Money.niceRound(plan.suggestedMonthly),
            Money.niceRound(state.profile.monthlySalary * 0.05),
            if (plan.remainingToMin > 0) Money.niceRound(plan.remainingToMin),
            if (plan.remainingToIdeal > 0)
              Money.niceRound(plan.remainingToIdeal),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AmountField(
          controller: _amount,
          label: out ? 'Amount to withdraw' : 'Amount to add',
          autofocus: true,
          max: out ? plan.balance : null,
          helper: out
              ? 'Available ${Money.format(plan.balance)}'
              : 'Current fund ${Money.format(plan.balance)}',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        QuickAmounts(
          amounts: _dedupe(quick),
          onPick: (double value) => setState(() {
            _amount.text = Money.plain(value);
          }),
        ),
        const SizedBox(height: 18),
        TextInputBox(
          controller: _note,
          label: 'Note (optional)',
          hintText: out ? 'What happened?' : 'Where did it come from?',
          maxLength: 60,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        if (!out) ...<Widget>[
          const SizedBox(height: 8),
          ToggleRow(
            title: 'Count as savings this month',
            subtitle: 'Feeds your savings rate and health score.',
            icon: Icons.trending_up_rounded,
            value: _countAsSavings,
            onChanged: (bool v) => setState(() => _countAsSavings = v),
          ),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: out ? 'Withdraw' : 'Add to fund',
          icon: out ? Icons.north_east_rounded : Icons.add_rounded,
          busy: _busy,
          gradient: out ? null : AppColors.emeraldSweep,
          onPressed: (AmountField.valueOf(_amount) ?? 0) > 0 ? _submit : null,
        ),
      ],
    );
  }

  List<double> _dedupe(List<double> values) {
    final List<double> out = <double>[];
    for (final double v in values) {
      if (v > 0 && !out.contains(v)) out.add(v);
    }
    out.sort();
    return out;
  }
}
