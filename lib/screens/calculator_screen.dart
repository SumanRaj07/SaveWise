import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../domain/engines/calculator_engine.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';
import 'goals_screen.dart';

enum _CalcMode { emi, deposit, simple, compound, goal }

extension _CalcModeX on _CalcMode {
  String get label => switch (this) {
        _CalcMode.emi => 'EMI',
        _CalcMode.deposit => 'Fixed deposit',
        _CalcMode.simple => 'Simple interest',
        _CalcMode.compound => 'Compound',
        _CalcMode.goal => 'Savings goal',
      };

  String get blurb => switch (this) {
        _CalcMode.emi => 'What a loan really costs you every month.',
        _CalcMode.deposit => 'What a lump sum grows into.',
        _CalcMode.simple => 'Interest that never compounds.',
        _CalcMode.compound => 'Interest earning interest, month by month.',
        _CalcMode.goal => 'What a target costs per month.',
      };

  IconData get icon => switch (this) {
        _CalcMode.emi => Icons.account_balance_outlined,
        _CalcMode.deposit => Icons.lock_clock_outlined,
        _CalcMode.simple => Icons.straighten_rounded,
        _CalcMode.compound => Icons.auto_graph_rounded,
        _CalcMode.goal => Icons.flag_outlined,
      };
}

/// The calculator tab: EMI, fixed deposit, simple interest, compound interest
/// and savings goal, as the brief lists them.
///
/// Every panel is wired to the user's own salary, so the results are not
/// abstract — an EMI is judged against what they actually earn, and a savings
/// goal can be promoted into a real tracked goal in one tap.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  _CalcMode _mode = _CalcMode.emi;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Calculators',
      subtitle: _mode.blurb,
      children: <Widget>[
        ChoiceRow<_CalcMode>(
          values: _CalcMode.values,
          selected: _mode,
          scroll: true,
          labelOf: (_CalcMode m) => m.label,
          iconOf: (_CalcMode m) => m.icon,
          onChanged: (_CalcMode m) => setState(() => _mode = m),
        ),
        const SizedBox(height: 18),
        switch (_mode) {
          _CalcMode.emi => const _EmiPanel(),
          _CalcMode.deposit => const _DepositPanel(compounding: false),
          _CalcMode.simple => const _SimplePanel(),
          _CalcMode.compound => const _DepositPanel(compounding: true),
          _CalcMode.goal => const _GoalPanel(),
        },
      ],
    );
  }
}

// ---------------------------------------------------------------------- shared

/// A percentage slider. Rates are stored as fractions internally and shown as
/// percentages, which keeps every call to the engine in the same unit.
class _RateInput extends StatelessWidget {
  const _RateInput({
    required this.fraction,
    required this.onChanged,
    this.label = 'Interest rate',
    this.max = 0.36,
  });

  final double fraction;
  final ValueChanged<double> onChanged;
  final String label;
  final double max;

  @override
  Widget build(BuildContext context) {
    return RateSlider(
      label: label,
      value: fraction,
      min: 0,
      max: max,
      divisions: (max / 0.0025).round(),
      valueLabel: '${(fraction * 100).toStringAsFixed(2)}% a year',
      onChanged: onChanged,
    );
  }
}

/// Months as a slider, labelled the way people talk about loan tenure.
class _TermInput extends StatelessWidget {
  const _TermInput({
    required this.months,
    required this.onChanged,
    this.label = 'Tenure',
    this.minMonths = 6,
    this.maxMonths = 360,
    this.step = 6,
  });

  final int months;
  final ValueChanged<int> onChanged;
  final String label;
  final int minMonths;
  final int maxMonths;
  final int step;

  static String describe(int months) {
    if (months < 12) return '$months months';
    final int years = months ~/ 12;
    final int rest = months % 12;
    final String y = '$years ${years == 1 ? 'year' : 'years'}';
    if (rest == 0) return y;
    return '$y $rest mo';
  }

  @override
  Widget build(BuildContext context) {
    return RateSlider(
      label: label,
      value: months.toDouble(),
      min: minMonths.toDouble(),
      max: maxMonths.toDouble(),
      divisions: ((maxMonths - minMonths) / step).round(),
      accent: AppColors.brass,
      valueLabel: describe(months),
      onChanged: (double v) => onChanged(v.round()),
    );
  }
}

/// Axis labels for a series of [count] points, thinned to at most [maxLabels]
/// so a 30-year chart does not try to draw thirty labels across a phone.
List<String> _sparseLabels(
  int count,
  String Function(int index) build, {
  int maxLabels = 6,
}) {
  if (count <= 0) return const <String>[];
  final int stride = math.max(1, (count / maxLabels).ceil());
  return <String>[
    for (int i = 0; i < count; i++)
      if (i == count - 1 || i % stride == 0) build(i) else '',
  ];
}

/// The big number a calculator exists to produce.
class _ResultHero extends StatelessWidget {
  const _ResultHero({
    required this.label,
    required this.value,
    required this.footnote,
    this.accent,
    this.icon,
  });

  final String label;
  final String value;
  final String footnote;
  final Color? accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? AppColors.emerald;
    return GlassCard(
      accent: tint,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 15, color: tint),
                const SizedBox(width: 7),
              ],
              Text(label.toUpperCase(), style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.moneyHero.copyWith(color: tint),
            ),
          ),
          const SizedBox(height: 6),
          Text(footnote, style: AppTextStyles.small),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------- EMI

class _EmiPanel extends StatefulWidget {
  const _EmiPanel();

  @override
  State<_EmiPanel> createState() => _EmiPanelState();
}

class _EmiPanelState extends State<_EmiPanel> {
  final TextEditingController _amount = TextEditingController();
  double _rate = 0.095;
  int _months = 60;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    // Seed with something plausible for this user rather than an empty field:
    // twelve months of salary is a recognisable loan size.
    final double salary = context.read<AppState>().profile.monthlySalary;
    if (salary > 0) _amount.text = Money.plain(Money.niceRound(salary * 12));
    _seeded = true;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final double salary = state.profile.monthlySalary;
    final double principal = AmountField.valueOf(_amount) ?? 0;
    final EmiResult r = CalculatorEngine.emi(
      principal: principal,
      annualRate: _rate * 100,
      months: _months,
    );
    final double share = r.shareOfIncome(salary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AmountField(
                controller: _amount,
                label: 'Loan amount',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              QuickAmounts(
                amounts: <double>[
                  Money.niceRound(math.max(1000.0, salary * 6)),
                  Money.niceRound(math.max(2000.0, salary * 12)),
                  Money.niceRound(math.max(5000.0, salary * 24)),
                  Money.niceRound(math.max(10000.0, salary * 60)),
                ],
                onPick: (double v) => setState(() {
                  _amount.text = Money.plain(v);
                }),
              ),
              const SizedBox(height: 20),
              _RateInput(
                fraction: _rate,
                onChanged: (double v) => setState(() => _rate = v),
              ),
              const SizedBox(height: 16),
              _TermInput(
                months: _months,
                onChanged: (int v) => setState(() => _months = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ResultHero(
          label: 'Monthly EMI',
          value: Money.format(r.monthlyPayment),
          footnote: '${_TermInput.describe(_months)} at '
              '${(_rate * 100).toStringAsFixed(2)}% a year',
          icon: Icons.event_repeat_rounded,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: GlassCard(
                child: StatTile(
                  label: 'Total interest',
                  value: Money.format(r.totalInterest),
                  footnote:
                      '${Money.percent(r.interestToPrincipal)} of the amount borrowed',
                  icon: Icons.percent_rounded,
                  accent: AppColors.clay,
                  compact: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCard(
                child: StatTile(
                  label: 'Total payment',
                  value: Money.format(r.totalPayment),
                  footnote: '${r.months} payments',
                  icon: Icons.summarize_outlined,
                  accent: AppColors.brass,
                  compact: true,
                ),
              ),
            ),
          ],
        ),
        if (salary > 0 && principal > 0) ...<Widget>[
          const SizedBox(height: 12),
          _AffordabilityCard(result: r, salary: salary, share: share),
        ],
        if (principal > 0) ...<Widget>[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Where the money goes', style: AppTextStyles.cardTitle),
                const SizedBox(height: 6),
                Text(
                  'Interest is ${Money.percent(r.interestShare)} of everything '
                  'you would hand over.',
                  style: AppTextStyles.small,
                ),
                const SizedBox(height: 16),
                Center(
                  child: DonutChart(
                    slices: <ChartSlice>[
                      ChartSlice(
                        label: 'Principal',
                        value: r.principal,
                        color: AppColors.emerald,
                      ),
                      ChartSlice(
                        label: 'Interest',
                        value: r.totalInterest,
                        color: AppColors.clay,
                      ),
                    ],
                    centreLabel: 'Total',
                    centreValue: Money.compact(r.totalPayment),
                  ),
                ),
                const SizedBox(height: 16),
                ChartLegend(
                  slices: <ChartSlice>[
                    ChartSlice(
                      label: 'Principal',
                      value: r.principal,
                      color: AppColors.emerald,
                    ),
                    ChartSlice(
                      label: 'Interest',
                      value: r.totalInterest,
                      color: AppColors.clay,
                    ),
                  ],
                  trailingBuilder: (ChartSlice s) => Money.format(s.value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _BalanceTimeline(result: r),
          if (r.interestByYear.length > 1) ...<Widget>[
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Interest paid each year',
                      style: AppTextStyles.cardTitle),
                  const SizedBox(height: 6),
                  Text(
                    'Front-loaded, always. Early extra payments are worth far '
                    'more than late ones.',
                    style: AppTextStyles.small,
                  ),
                  const SizedBox(height: 16),
                  BarChart(
                    bars: <BarDatum>[
                      for (int i = 0; i < r.interestByYear.length; i++)
                        BarDatum(
                          label: 'Y${i + 1}',
                          value: r.interestByYear[i],
                          color: AppColors.clay,
                        ),
                    ],
                    height: 140,
                    valueFormatter: (double v) => Money.compact(v),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// The judgement the brief's "can I afford this?" question really wants.
class _AffordabilityCard extends StatelessWidget {
  const _AffordabilityCard({
    required this.result,
    required this.salary,
    required this.share,
  });

  final EmiResult result;
  final double salary;
  final double share;

  @override
  Widget build(BuildContext context) {
    final bool comfortable = result.isComfortable(salary);
    final bool stretched = result.isStretched(salary);
    final Color tint = comfortable
        ? AppColors.emerald
        : stretched
            ? AppColors.brass
            : AppColors.clay;
    final String verdict = comfortable
        ? 'Comfortable'
        : stretched
            ? 'Stretched'
            : 'Too much';
    final String detail = comfortable
        ? 'This EMI takes ${Money.percent(share)} of your salary, inside the '
            '30% that lenders and common sense both like.'
        : stretched
            ? 'At ${Money.percent(share)} of salary this is above the 30% '
                'comfort line. Doable, but it will squeeze everything else.'
            : 'At ${Money.percent(share)} of salary this is past the 40% line. '
                'A longer tenure or a smaller loan is the only honest fix.';

    return GlassCard(
      accent: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('AGAINST YOUR SALARY', style: AppTextStyles.label),
              const Spacer(),
              StatusPill(text: verdict, color: tint, filled: true),
            ],
          ),
          const SizedBox(height: 14),
          ProgressBar(
            progress: share,
            color: tint,
            marker: 0.30,
            height: 9,
          ),
          const SizedBox(height: 8),
          Text(
            '${Money.percent(share)} of ${Money.format(salary)} · '
            'the marker is the 30% line',
            style: AppTextStyles.small,
          ),
          const SizedBox(height: 12),
          Text(detail, style: AppTextStyles.small.copyWith(height: 1.45)),
        ],
      ),
    );
  }
}

/// Outstanding balance over the life of the loan, sampled so a 30-year mortgage
/// draws as smoothly as a two-year personal loan.
class _BalanceTimeline extends StatelessWidget {
  const _BalanceTimeline({required this.result});

  final EmiResult result;

  @override
  Widget build(BuildContext context) {
    final List<AmortisationRow> rows = result.schedule;
    if (rows.length < 2) return const SizedBox.shrink();

    const int maxPoints = 24;
    final int stride = math.max(1, (rows.length / maxPoints).ceil());
    final List<double> balances = <double>[result.principal];
    final List<String> labels = <String>[''];
    for (int i = stride - 1; i < rows.length; i += stride) {
      balances.add(rows[i].balance);
      labels.add(rows[i].month % 12 == 0 ? 'Y${rows[i].month ~/ 12}' : '');
    }
    if (balances.last != rows.last.balance) {
      balances.add(rows.last.balance);
      labels.add('');
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Repayment timeline', style: AppTextStyles.cardTitle),
          const SizedBox(height: 6),
          Text(
            'What you still owe, month by month.',
            style: AppTextStyles.small,
          ),
          const SizedBox(height: 16),
          LineChart(
            series: <LineSeries>[
              LineSeries(
                values: balances,
                color: AppColors.vizTeal,
                label: 'Outstanding',
                fill: true,
              ),
            ],
            labels: labels,
            height: 170,
            minY: 0,
            yLabelFormatter: (double v) => Money.compact(v),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------- fixed deposit / compounding

class _DepositPanel extends StatefulWidget {
  const _DepositPanel({required this.compounding});

  /// Compound-interest mode compounds monthly and leads with the multiple;
  /// fixed-deposit mode compounds quarterly and leads with maturity value.
  final bool compounding;

  @override
  State<_DepositPanel> createState() => _DepositPanelState();
}

class _DepositPanelState extends State<_DepositPanel> {
  final TextEditingController _principal = TextEditingController();
  final TextEditingController _monthly = TextEditingController();
  double _rate = 0.07;
  int _months = 60;
  late int _frequency = widget.compounding ? 12 : 4;
  bool _seeded = false;

  static const Map<int, String> _frequencies = <int, String>{
    1: 'Yearly',
    2: 'Half-yearly',
    4: 'Quarterly',
    12: 'Monthly',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final double salary = context.read<AppState>().profile.monthlySalary;
    if (salary > 0) {
      _principal.text = Money.plain(Money.niceRound(salary * 3));
    }
    _seeded = true;
  }

  @override
  void dispose() {
    _principal.dispose();
    _monthly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double principal = AmountField.valueOf(_principal) ?? 0;
    final double monthly = AmountField.valueOf(_monthly) ?? 0;
    final double years = _months / 12;
    final DepositResult r = widget.compounding
        ? CalculatorEngine.compoundInterest(
            principal: principal,
            annualRate: _rate * 100,
            years: years,
            compoundsPerYear: _frequency,
            monthlyContribution: monthly,
          )
        : CalculatorEngine.fixedDeposit(
            principal: principal,
            annualRate: _rate * 100,
            years: years,
            compoundsPerYear: _frequency,
            monthlyContribution: monthly,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AmountField(
                controller: _principal,
                label: widget.compounding ? 'Starting amount' : 'Deposit amount',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              AmountField(
                controller: _monthly,
                label: 'Adding monthly (optional)',
                allowZero: true,
                helper: 'Leave empty for a plain lump sum.',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _RateInput(
                fraction: _rate,
                max: 0.20,
                onChanged: (double v) => setState(() => _rate = v),
              ),
              const SizedBox(height: 16),
              _TermInput(
                label: 'Term',
                months: _months,
                minMonths: 6,
                maxMonths: 360,
                step: 6,
                onChanged: (int v) => setState(() => _months = v),
              ),
              const SizedBox(height: 18),
              ChoiceRow<int>(
                label: 'Compounded',
                values: _frequencies.keys.toList(growable: false),
                selected: _frequency,
                labelOf: (int f) => _frequencies[f] ?? '$f×',
                onChanged: (int f) => setState(() => _frequency = f),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ResultHero(
          label: widget.compounding ? 'Final balance' : 'Maturity value',
          value: Money.format(r.maturity),
          footnote: 'After ${_TermInput.describe(_months)} at '
              '${(_rate * 100).toStringAsFixed(2)}%, compounded '
              '${(_frequencies[_frequency] ?? '').toLowerCase()}',
          icon: Icons.savings_outlined,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: GlassCard(
                child: StatTile(
                  label: 'Interest earned',
                  value: Money.format(r.interest),
                  footnote: '${Money.percent(r.interestShare)} of the total',
                  icon: Icons.trending_up_rounded,
                  accent: AppColors.emerald,
                  compact: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCard(
                child: StatTile(
                  label: 'You put in',
                  value: Money.format(r.totalContributed),
                  footnote: monthly > 0
                      ? '${Money.format(monthly)} a month'
                      : 'One deposit',
                  icon: Icons.input_rounded,
                  accent: AppColors.brass,
                  compact: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              KeyValueRow(
                label: 'Effective annual rate',
                value: Money.percent(r.effectiveAnnualRate, decimals: 2),
                icon: Icons.calculate_outlined,
                dense: true,
              ),
              KeyValueRow(
                label: 'Growth multiple',
                value: r.totalContributed <= 0
                    ? '—'
                    : '${r.growthMultiple.toStringAsFixed(2)}×',
                icon: Icons.close_fullscreen_rounded,
                dense: true,
              ),
              KeyValueRow(
                label: 'Nominal rate',
                value: '${(_rate * 100).toStringAsFixed(2)}%',
                icon: Icons.percent_rounded,
                dense: true,
              ),
            ],
          ),
        ),
        if (r.series.length > 1) ...<Widget>[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Growth', style: AppTextStyles.cardTitle),
                const SizedBox(height: 6),
                Text(
                  'The gap between the two lines is interest — money you never '
                  'had to earn.',
                  style: AppTextStyles.small,
                ),
                const SizedBox(height: 16),
                LineChart(
                  series: <LineSeries>[
                    LineSeries(
                      values: <double>[
                        for (final GrowthPoint p in r.series) p.balance,
                      ],
                      color: AppColors.emerald,
                      label: 'Balance',
                      fill: true,
                    ),
                    LineSeries(
                      values: <double>[
                        for (final GrowthPoint p in r.series) p.contributed,
                      ],
                      color: AppColors.vizSteel,
                      label: 'Contributed',
                    ),
                  ],
                  labels: _sparseLabels(
                    r.series.length,
                    (int i) => 'Y${r.series[i].period}',
                  ),
                  height: 180,
                  minY: 0,
                  yLabelFormatter: (double v) => Money.compact(v),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// -------------------------------------------------------------- simple interest

class _SimplePanel extends StatefulWidget {
  const _SimplePanel();

  @override
  State<_SimplePanel> createState() => _SimplePanelState();
}

class _SimplePanelState extends State<_SimplePanel> {
  final TextEditingController _principal = TextEditingController();
  double _rate = 0.08;
  int _months = 36;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final double salary = context.read<AppState>().profile.monthlySalary;
    if (salary > 0) {
      _principal.text = Money.plain(Money.niceRound(salary * 2));
    }
    _seeded = true;
  }

  @override
  void dispose() {
    _principal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double principal = AmountField.valueOf(_principal) ?? 0;
    final double years = _months / 12;
    final SimpleInterestResult r = CalculatorEngine.simpleInterest(
      principal: principal,
      annualRate: _rate * 100,
      years: years,
    );
    final double compounded = r.compoundedComparison();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AmountField(
                controller: _principal,
                label: 'Principal',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _RateInput(
                fraction: _rate,
                max: 0.30,
                onChanged: (double v) => setState(() => _rate = v),
              ),
              const SizedBox(height: 16),
              _TermInput(
                label: 'Time',
                months: _months,
                minMonths: 3,
                maxMonths: 240,
                step: 3,
                onChanged: (int v) => setState(() => _months = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ResultHero(
          label: 'Interest',
          value: Money.format(r.interest),
          footnote: 'P × R × T ÷ 100 over ${_TermInput.describe(_months)}',
          icon: Icons.straighten_rounded,
          accent: AppColors.brass,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: GlassCard(
                child: StatTile(
                  label: 'Total repayable',
                  value: Money.format(r.total),
                  footnote: 'Principal plus interest',
                  icon: Icons.summarize_outlined,
                  accent: AppColors.brass,
                  compact: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCard(
                child: StatTile(
                  label: 'If it compounded',
                  value: Money.format(compounded),
                  footnote:
                      '${Money.format(r.compoundingAdvantage)} more, yearly',
                  icon: Icons.auto_graph_rounded,
                  accent: AppColors.emerald,
                  compact: true,
                ),
              ),
            ),
          ],
        ),
        if (principal > 0) ...<Widget>[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Simple against compound', style: AppTextStyles.cardTitle),
                const SizedBox(height: 6),
                Text(
                  'Same money, same rate, same time. The only difference is '
                  'whether interest earns interest.',
                  style: AppTextStyles.small,
                ),
                const SizedBox(height: 16),
                BarChart(
                  bars: <BarDatum>[
                    BarDatum(
                      label: 'Simple',
                      value: r.total,
                      color: AppColors.brass,
                    ),
                    BarDatum(
                      label: 'Compound',
                      value: compounded,
                      color: AppColors.emerald,
                    ),
                  ],
                  height: 130,
                  valueFormatter: (double v) => Money.compact(v),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ goal solver

class _GoalPanel extends StatefulWidget {
  const _GoalPanel();

  @override
  State<_GoalPanel> createState() => _GoalPanelState();
}

class _GoalPanelState extends State<_GoalPanel> {
  final TextEditingController _target = TextEditingController();
  final TextEditingController _starting = TextEditingController();
  double _rate = 0;
  int _months = 12;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final double salary = context.read<AppState>().profile.monthlySalary;
    if (salary > 0) _target.text = Money.plain(Money.niceRound(salary * 4));
    _seeded = true;
  }

  @override
  void dispose() {
    _target.dispose();
    _starting.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final double capacity = state.monthlyCapacity;
    final SavingsGoalResult r = CalculatorEngine.savingsGoal(
      target: AmountField.valueOf(_target) ?? 0,
      months: _months,
      annualRate: _rate * 100,
      startingAmount: AmountField.valueOf(_starting) ?? 0,
    );
    final bool withinReach = capacity <= 0 || r.monthlyRequired <= capacity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AmountField(
                controller: _target,
                label: 'Target amount',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              AmountField(
                controller: _starting,
                label: 'Already saved (optional)',
                allowZero: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _TermInput(
                label: 'Time to target',
                months: _months,
                minMonths: 1,
                maxMonths: 120,
                step: 1,
                onChanged: (int v) => setState(() => _months = v),
              ),
              const SizedBox(height: 16),
              _RateInput(
                label: 'Return on savings (optional)',
                fraction: _rate,
                max: 0.15,
                onChanged: (double v) => setState(() => _rate = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ResultHero(
          label: 'Save each month',
          value: Money.format(r.monthlyRequired),
          footnote: 'To reach ${Money.format(r.target)} in '
              '${_TermInput.describe(_months)}',
          icon: Icons.flag_outlined,
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: StatTile(
                      label: 'Per week',
                      value: Money.format(r.weeklyRequired),
                      icon: Icons.calendar_view_week_rounded,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Per day',
                      value: Money.format(r.dailyRequired),
                      icon: Icons.today_rounded,
                      compact: true,
                    ),
                  ),
                ],
              ),
              const Divider(height: 26),
              KeyValueRow(
                label: 'With no interest at all',
                value: Money.format(r.withoutInterest),
                icon: Icons.money_off_rounded,
                dense: true,
              ),
              KeyValueRow(
                label: 'Interest does the work',
                value: Money.format(r.interestEarned),
                icon: Icons.auto_graph_rounded,
                valueColor: r.interestEarned > 0 ? AppColors.emerald : null,
                dense: true,
              ),
              KeyValueRow(
                label: 'You contribute',
                value: Money.format(r.totalContributed),
                icon: Icons.input_rounded,
                dense: true,
              ),
              if (capacity > 0)
                KeyValueRow(
                  label: 'Your monthly surplus',
                  value: Money.format(capacity),
                  icon: Icons.account_balance_wallet_outlined,
                  valueColor:
                      withinReach ? AppColors.emerald : AppColors.clay,
                  dense: true,
                ),
            ],
          ),
        ),
        if (capacity > 0 && r.monthlyRequired > 0) ...<Widget>[
          const SizedBox(height: 12),
          AdviceTile(
            icon: withinReach
                ? Icons.thumb_up_alt_outlined
                : Icons.warning_amber_rounded,
            color: withinReach ? AppColors.emerald : AppColors.clay,
            title: withinReach ? 'This fits' : 'This does not fit yet',
            detail: withinReach
                ? 'It uses ${Money.percent(r.monthlyRequired / capacity)} of '
                    'your ${Money.format(capacity)} monthly surplus.'
                : 'It needs ${Money.format(r.monthlyRequired - capacity)} a '
                    'month more than your surplus. Stretch the date, or free '
                    'up money in the planner.',
          ),
        ],
        if (r.series.length > 1) ...<Widget>[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('The climb', style: AppTextStyles.cardTitle),
                const SizedBox(height: 16),
                LineChart(
                  series: <LineSeries>[
                    LineSeries(
                      values: <double>[
                        for (final GrowthPoint p in r.series) p.balance,
                      ],
                      color: AppColors.emerald,
                      label: 'Balance',
                      fill: true,
                    ),
                  ],
                  labels: _sparseLabels(
                    r.series.length,
                    (int i) => 'M${r.series[i].period}',
                  ),
                  height: 170,
                  minY: 0,
                  maxY: math.max(r.target, r.series.last.balance),
                  yLabelFormatter: (double v) => Money.compact(v),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Make this a real goal',
          icon: Icons.add_task_rounded,
          onPressed: () => GoalSheets.add(context),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter / 2),
          child: Text(
            'Tracked goals get progress rings, milestones and a nudge when you '
            'fall behind.',
            style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
