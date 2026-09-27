import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/goal.dart';
import '../data/models/monthly_snapshot.dart';
import '../domain/engines/budget_engine.dart';
import '../domain/engines/health_score_engine.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';

enum _View { month, trends }

/// Reports & Analytics.
///
/// Two views, because two different questions are being asked. "Month" answers
/// *how did this month go* — one column of figures you could read out loud.
/// "Trends" answers *am I getting better* — the same figures over six months,
/// which is the only view in which a savings habit is visible at all.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _View _view = _View.month;

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<MonthlySnapshot> series = state.reportSeries;
    final MonthlySnapshot current = series.last;

    return ScreenScaffold(
      title: 'Reports',
      subtitle: _view == _View.month
          ? Dates.monthLabel(DateTime.now())
          : 'Last ${series.length} '
              '${series.length == 1 ? 'month' : 'months'}',
      showBack: true,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 4, AppTheme.gutter, 12),
        child: ChoiceRow<_View>(
          values: _View.values,
          selected: _view,
          labelOf: (_View v) => v == _View.month ? 'This month' : 'Trends',
          iconOf: (_View v) => v == _View.month
              ? Icons.description_rounded
              : Icons.show_chart_rounded,
          onChanged: (_View v) => setState(() => _view = v),
        ),
      ),
      children: _view == _View.month
          ? <Widget>[
              _MonthReport(snapshot: current, state: state),
              const SizedBox(height: 16),
              _BreakdownCard(summary: state.summary),
              const SizedBox(height: 16),
              const _PrivacyFooter(),
            ]
          : <Widget>[
              if (series.length < 2)
                const _NotEnoughHistory()
              else ...<Widget>[
                _SavingsTrend(series: series),
                const SizedBox(height: 16),
                _MoneyFlowTrend(series: series),
                const SizedBox(height: 16),
                _HealthTrend(series: series),
                const SizedBox(height: 16),
                _CushionTrend(series: series),
                const SizedBox(height: 16),
                _HistoryTable(series: series),
                const SizedBox(height: 16),
              ],
              const _PrivacyFooter(),
            ],
    );
  }
}

// ------------------------------------------------------------- month report

class _MonthReport extends StatelessWidget {
  const _MonthReport({required this.snapshot, required this.state});

  final MonthlySnapshot snapshot;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final BudgetSummary summary = state.summary;
    final double net = snapshot.income - snapshot.expenses - snapshot.savings;
    final double rate = snapshot.savingsRate;
    final bool onTarget = rate >= state.profile.savingsRateTarget;

    return Column(
      children: <Widget>[
        GlassCard(
          accent: onTarget ? AppColors.emerald : AppColors.brass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('SAVED THIS MONTH', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Text(Money.format(snapshot.savings),
                  style: AppTextStyles.moneyHero),
              const SizedBox(height: 6),
              Text(
                snapshot.income <= 0
                    ? 'Add your salary to see this as a rate.'
                    : '${Money.percent(rate)} of income. Your target is '
                        '${Money.percent(state.profile.savingsRateTarget)}.',
                style: AppTextStyles.small,
              ),
              const SizedBox(height: 14),
              ProgressBar(
                progress: state.profile.savingsRateTarget <= 0
                    ? 0
                    : rate / state.profile.savingsRateTarget,
                color: onTarget ? AppColors.emerald : AppColors.brass,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: 'Income',
                value: Money.compact(snapshot.income),
                icon: Icons.arrow_downward_rounded,
                accent: AppColors.emerald,
                compact: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Spent',
                value: Money.compact(snapshot.expenses),
                icon: Icons.arrow_upward_rounded,
                accent: AppColors.clay,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: 'Health score',
                value: '${state.score.total}',
                footnote: state.score.grade.label,
                icon: Icons.favorite_rounded,
                accent: AppColors.forScore(state.score.total),
                compact: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Unspent',
                value: Money.compact(math.max(0.0, net)),
                footnote: net < 0 ? 'Over income' : 'Not yet allocated',
                icon: Icons.account_balance_wallet_rounded,
                accent: net < 0 ? AppColors.clay : null,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeader(
                title: 'The month in figures',
                icon: Icons.receipt_long_rounded,
              ),
              KeyValueRow(
                label: 'Income',
                value: Money.format(snapshot.income),
                dense: true,
              ),
              KeyValueRow(
                label: 'Spending',
                value: Money.format(snapshot.expenses),
                dense: true,
              ),
              KeyValueRow(
                label: 'Savings',
                value: Money.format(snapshot.savings),
                valueColor: AppColors.emerald,
                dense: true,
              ),
              KeyValueRow(
                label: 'Savings rate',
                value: Money.percent(rate),
                dense: true,
              ),
              const Divider(color: AppColors.hairlineSoft, height: 22),
              KeyValueRow(
                label: 'Budget used',
                value: '${Money.format(summary.totalSpent)} of '
                    '${Money.format(summary.totalLimit)}',
                dense: true,
              ),
              KeyValueRow(
                label: 'Budget utilisation',
                value: Money.percent(summary.utilisation),
                valueColor: summary.utilisation > 1
                    ? AppColors.clay
                    : AppColors.textPrimary,
                dense: true,
              ),
              KeyValueRow(
                label: 'Categories over limit',
                value: '${summary.overspent.length} of 7',
                valueColor: summary.overspent.isEmpty
                    ? AppColors.emerald
                    : AppColors.clay,
                dense: true,
              ),
              const Divider(color: AppColors.hairlineSoft, height: 22),
              KeyValueRow(
                label: 'Emergency fund',
                value: Money.format(snapshot.emergencyFund),
                dense: true,
              ),
              KeyValueRow(
                label: 'Months of cover',
                value: state.emergency.coverageMonths.toStringAsFixed(1),
                dense: true,
              ),
              KeyValueRow(
                label: 'Goal progress, average',
                value: Money.percent(snapshot.goalProgress),
                dense: true,
              ),
              KeyValueRow(
                label: 'Goals active',
                value: '${state.goals.where((Goal g) => !g.isComplete).length}',
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Budget breakdown for the month in progress. Planned sits behind actual, so
/// the gap between intention and behaviour is the thing you see first.
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<CategoryUsage> spending = summary.usage
        .where((CategoryUsage u) => u.category != BudgetCategory.savings)
        .toList(growable: false);

    double spent = 0;
    for (final CategoryUsage u in spending) {
      spent += u.spent;
    }

    final List<ChartSlice> slices = <ChartSlice>[
      for (final CategoryUsage u in spending)
        if (u.spent > 0)
          ChartSlice(
            label: u.category.label,
            value: u.spent,
            color: u.category.color,
          ),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(
            title: 'Where the money went',
            subtitle: 'This month, spending only',
            icon: Icons.donut_large_rounded,
          ),
          if (slices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Nothing logged yet this month. Once you log spending it is '
                'broken down here by category.',
                style: AppTextStyles.small,
              ),
            )
          else ...<Widget>[
            Center(
              child: DonutChart(
                slices: slices,
                centreLabel: 'Spent',
                centreValue: Money.compact(spent),
              ),
            ),
            const SizedBox(height: 16),
            ChartLegend(
              slices: slices,
              trailingBuilder: (ChartSlice s) =>
                  spent <= 0 ? '' : Money.percent(s.value / spent),
            ),
          ],
          const SizedBox(height: 16),
          BarChart(
            bars: <BarDatum>[
              for (final CategoryUsage u in spending)
                BarDatum(
                  label: u.category.label.length > 5
                      ? u.category.label.substring(0, 5)
                      : u.category.label,
                  value: u.spent,
                  color: u.isOver ? AppColors.clay : u.category.color,
                  secondary: u.limit,
                ),
            ],
            height: 160,
            valueFormatter: Money.compact,
          ),
          const SizedBox(height: 8),
          Text(
            'The faint bar behind each is the limit you set.',
            style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- trends

class _NotEnoughHistory extends StatelessWidget {
  const _NotEnoughHistory();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 30),
      child: EmptyState(
        icon: Icons.show_chart_rounded,
        title: 'One month in',
        message:
            'Trends need a second month to compare against. SaveWise freezes '
            'each month when it ends, so the first chart appears on the first '
            'day of next month — and nothing you do now is lost.',
      ),
    );
  }
}

class _SavingsTrend extends StatelessWidget {
  const _SavingsTrend({required this.series});

  final List<MonthlySnapshot> series;

  @override
  Widget build(BuildContext context) {
    final List<double> saved = <double>[
      for (final MonthlySnapshot s in series) s.savings,
    ];
    final List<double> rates = <double>[
      for (final MonthlySnapshot s in series) s.savingsRate * 100,
    ];

    double total = 0;
    for (final double v in saved) {
      total += v;
    }
    final double average = total / saved.length;
    final double change = saved.length < 2
        ? 0
        : saved.last - saved[saved.length - 2];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Savings trend',
            subtitle: '${Money.format(total)} saved over '
                '${series.length} months',
            icon: Icons.savings_rounded,
          ),
          BarChart(
            bars: <BarDatum>[
              for (final MonthlySnapshot s in series)
                BarDatum(
                  label: _shortMonth(s.monthKey),
                  value: s.savings,
                  color: AppColors.emerald,
                ),
            ],
            valueFormatter: Money.compact,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Monthly average',
                  value: Money.compact(average),
                  compact: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Versus last month',
                  value: Money.formatSigned(change),
                  accent: change >= 0 ? AppColors.emerald : AppColors.clay,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('SAVINGS RATE, PER CENT OF INCOME',
              style: AppTextStyles.label),
          const SizedBox(height: 12),
          LineChart(
            series: <LineSeries>[
              LineSeries(
                values: rates,
                color: AppColors.emeraldSoft,
                label: 'Rate',
                fill: true,
              ),
            ],
            labels: _sparse(series),
            height: 140,
            minY: 0,
            yLabelFormatter: (double v) => '${v.round()}%',
          ),
          const SizedBox(height: 10),
          Text(
            'A rate holds its meaning when income changes; an amount does not. '
            'This is the line to watch.',
            style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MoneyFlowTrend extends StatelessWidget {
  const _MoneyFlowTrend({required this.series});

  final List<MonthlySnapshot> series;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(
            title: 'Income against spending',
            subtitle: 'The gap is what you keep',
            icon: Icons.swap_vert_rounded,
          ),
          LineChart(
            series: <LineSeries>[
              LineSeries(
                values: <double>[
                  for (final MonthlySnapshot s in series) s.income,
                ],
                color: AppColors.vizSteel,
                label: 'Income',
              ),
              LineSeries(
                values: <double>[
                  for (final MonthlySnapshot s in series) s.expenses,
                ],
                color: AppColors.clay,
                label: 'Spending',
                fill: true,
              ),
            ],
            labels: _sparse(series),
            minY: 0,
            yLabelFormatter: Money.compact,
          ),
          const SizedBox(height: 14),
          const ChartLegend(
            slices: <ChartSlice>[
              ChartSlice(label: 'Income', value: 1, color: AppColors.vizSteel),
              ChartSlice(label: 'Spending', value: 1, color: AppColors.clay),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthTrend extends StatelessWidget {
  const _HealthTrend({required this.series});

  final List<MonthlySnapshot> series;

  @override
  Widget build(BuildContext context) {
    final List<double> scores = <double>[
      for (final MonthlySnapshot s in series) s.healthScore.toDouble(),
    ];
    final double first = scores.first;
    final double last = scores.last;
    final double delta = last - first;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Health score trend',
            subtitle: delta == 0
                ? 'Level over ${series.length} months'
                : '${delta > 0 ? 'Up' : 'Down'} ${delta.abs().round()} points '
                    'over ${series.length} months',
            icon: Icons.favorite_rounded,
          ),
          LineChart(
            series: <LineSeries>[
              LineSeries(
                values: scores,
                color: AppColors.forScore(last.round()),
                label: 'Score',
                fill: true,
              ),
            ],
            labels: _sparse(series),
            minY: 0,
            maxY: 100,
            yLabelFormatter: (double v) => v.round().toString(),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Now',
                  value: '${last.round()}',
                  accent: AppColors.forScore(last.round()),
                  compact: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Change',
                  value: delta == 0
                      ? 'Level'
                      : '${delta > 0 ? '+' : '−'}${delta.abs().round()}',
                  accent: delta >= 0 ? AppColors.emerald : AppColors.clay,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Scored out of 100 from savings rate (${AppConstants.weightSavingsRate}), '
            'budget discipline (${AppConstants.weightDiscipline}), emergency fund '
            '(${AppConstants.weightEmergency}) and goal progress '
            '(${AppConstants.weightGoals}).',
            style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Fund growth and average goal completion share a card because both answer the
/// same question over time: is the cushion getting thicker, and are the plans
/// actually moving.
class _CushionTrend extends StatelessWidget {
  const _CushionTrend({required this.series});

  final List<MonthlySnapshot> series;

  @override
  Widget build(BuildContext context) {
    final double growth = series.last.emergencyFund - series.first.emergencyFund;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Cushion and goals',
            subtitle: growth >= 0
                ? '${Money.format(growth)} added to the fund'
                : '${Money.format(growth.abs())} drawn from the fund',
            icon: Icons.shield_rounded,
          ),
          LineChart(
            series: <LineSeries>[
              LineSeries(
                values: <double>[
                  for (final MonthlySnapshot s in series) s.emergencyFund,
                ],
                color: AppColors.emerald,
                label: 'Fund',
                fill: true,
              ),
            ],
            labels: _sparse(series),
            minY: 0,
            height: 140,
            yLabelFormatter: Money.compact,
          ),
          const SizedBox(height: 18),
          Text('AVERAGE GOAL COMPLETION', style: AppTextStyles.label),
          const SizedBox(height: 12),
          BarChart(
            bars: <BarDatum>[
              for (final MonthlySnapshot s in series)
                BarDatum(
                  label: _shortMonth(s.monthKey),
                  value: s.goalProgress * 100,
                  color: AppColors.brass,
                ),
            ],
            height: 130,
            valueFormatter: (double v) => '${v.round()}%',
          ),
        ],
      ),
    );
  }
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.series});

  final List<MonthlySnapshot> series;

  @override
  Widget build(BuildContext context) {
    final List<MonthlySnapshot> rows = series.reversed.toList(growable: false);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(
            title: 'Month by month',
            subtitle: 'Newest first',
            icon: Icons.table_rows_rounded,
          ),
          Row(
            children: <Widget>[
              Expanded(flex: 3, child: Text('MONTH', style: AppTextStyles.label)),
              Expanded(
                flex: 3,
                child: Text('SAVED',
                    textAlign: TextAlign.right, style: AppTextStyles.label),
              ),
              Expanded(
                flex: 3,
                child: Text('SPENT',
                    textAlign: TextAlign.right, style: AppTextStyles.label),
              ),
              Expanded(
                flex: 2,
                child: Text('SCORE',
                    textAlign: TextAlign.right, style: AppTextStyles.label),
              ),
            ],
          ),
          const Divider(color: AppColors.hairlineSoft, height: 18),
          for (final MonthlySnapshot s in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Text(
                      _longMonth(s.monthKey),
                      style: AppTextStyles.body,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      Money.compact(s.savings),
                      textAlign: TextAlign.right,
                      style: AppTextStyles.numericSmall
                          .copyWith(color: AppColors.emeraldSoft),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      Money.compact(s.expenses),
                      textAlign: TextAlign.right,
                      style: AppTextStyles.numericSmall,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${s.healthScore}',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.numericSmall.copyWith(
                        color: AppColors.forScore(s.healthScore),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'SaveWise keeps up to two years of closed months on this device and '
            'charts the most recent ${AppConstants.reportMonths}.',
            style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.phone_android_rounded,
            size: 13, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Every figure on this page was computed on this phone.',
            style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ helpers

String _shortMonth(String monthKey) =>
    Dates.monthShort(Dates.monthFromKey(monthKey));

String _longMonth(String monthKey) =>
    Dates.monthLabel(Dates.monthFromKey(monthKey));

/// Axis labels for the line charts. [LineChart] lays labels out in a spaced row,
/// so with six months every label fits; this stays defensive in case the report
/// window is ever widened.
List<String> _sparse(List<MonthlySnapshot> series) {
  if (series.length <= 6) {
    return <String>[for (final MonthlySnapshot s in series) _shortMonth(s.monthKey)];
  }
  final int step = (series.length / 6).ceil();
  return <String>[
    for (int i = 0; i < series.length; i++)
      i % step == 0 || i == series.length - 1 ? _shortMonth(series[i].monthKey) : '',
  ];
}
