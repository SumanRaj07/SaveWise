import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../data/models/expense.dart';
import '../domain/engines/budget_engine.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';

/// Smart Salary Planner.
///
/// The seven categories from the brief, each with a limit, what has gone out of
/// it, and where a steady spender would be by today. That last figure is the
/// one that turns a budget from a scorecard into a warning system.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, this.openLogSheet = false});

  /// Set when arriving from a "log an expense" shortcut.
  final bool openLogSheet;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  bool _showSpend = false;

  @override
  void initState() {
    super.initState();
    if (widget.openLogSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _logExpense(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final BudgetSummary summary = state.summary;

    return ScreenScaffold(
      title: 'Salary Planner',
      subtitle: 'Cycle ${Dates.shortDate(state.cycle.start)} – '
          '${Dates.shortDate(state.cycle.end)}',
      showBack: true,
      actions: <Widget>[
        IconButton(
          onPressed: () => _editBudget(context, state),
          icon: const Icon(Icons.tune_rounded),
          color: AppColors.textSecondary,
          tooltip: 'Edit budget',
        ),
      ],
      floating: FloatingActionButton.extended(
        onPressed: () => _logExpense(context),
        backgroundColor: AppColors.emerald,
        foregroundColor: AppColors.textOnAccent,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Log spend',
          style: AppTextStyles.button.copyWith(color: AppColors.textOnAccent),
        ),
      ),
      children: <Widget>[
        Reveal(child: _Overview(summary: summary, cycleProgress: state.cycle.progress)),
        const SizedBox(height: 12),
        Reveal(delayMs: 60, child: _Breakdown(
          summary: summary,
          showSpend: _showSpend,
          onToggle: (bool v) => setState(() => _showSpend = v),
        )),
        if (state.budgetAlerts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Alerts',
            icon: Icons.warning_amber_rounded,
          ),
          for (final String alert in state.budgetAlerts)
            AdviceTile(
              icon: Icons.error_outline_rounded,
              color: AppColors.clay,
              title: 'Overspending',
              detail: alert,
            ),
        ],
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Categories',
          subtitle: 'Tap one to see where the money went.',
          actionLabel: 'Edit all',
          onAction: () => _editBudget(context, state),
        ),
        GlassCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < BudgetCategory.values.length; i++) ...<Widget>[
                if (i > 0) const Divider(height: 1),
                _CategoryRow(
                  usage: summary.forCategory(BudgetCategory.values[i]),
                  cycleProgress: state.cycle.progress,
                  onTap: () => _categoryDetail(
                    context,
                    state,
                    BudgetCategory.values[i],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'Analytics',
          icon: Icons.insights_rounded,
        ),
        Reveal(child: _Analytics(summary: summary)),
        const SizedBox(height: 20),
        SectionHeader(
          title: 'This cycle’s spending',
          subtitle: state.cycleExpenses.isEmpty
              ? null
              : '${state.cycleExpenses.length} entries logged',
        ),
        if (state.cycleExpenses.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Nothing logged yet',
            message:
                'Add what you spend and the planner starts telling you things you '
                'did not already know.',
            actionLabel: 'Log a spend',
            onAction: () => _logExpense(context),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: <Widget>[
                for (final Expense e in state.cycleExpenses.take(25))
                  _ExpenseRow(
                    expense: e,
                    onDelete: () => _confirmDelete(context, state, e),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppState state,
    Expense expense,
  ) async {
    final bool yes = await AppSheet.confirm(
      context: context,
      title: 'Delete this entry?',
      message: '${expense.displayLabel} — ${Money.format(expense.amount)}',
    );
    if (yes) await state.deleteExpense(expense.id);
  }

  Future<void> _logExpense(BuildContext context) =>
      AppSheet.show<void>(
        context: context,
        title: 'Log spending',
        subtitle: 'Savings deposits belong in Goals or the emergency fund.',
        child: const _ExpenseForm(),
      );

  Future<void> _editBudget(BuildContext context, AppState state) =>
      AppSheet.show<void>(
        context: context,
        title: 'Edit budget',
        subtitle: 'Limits for this cycle. The plan does not have to add up to '
            'your salary, but it helps if it does.',
        child: const _BudgetForm(),
      );

  Future<void> _categoryDetail(
    BuildContext context,
    AppState state,
    BudgetCategory category,
  ) =>
      AppSheet.show<void>(
        context: context,
        title: category.label,
        subtitle: category == BudgetCategory.savings
            ? 'Everything you put aside this cycle, from any screen.'
            : 'Entries logged against this category this cycle.',
        child: _CategoryDetail(category: category),
      );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary, required this.cycleProgress});

  final BudgetSummary summary;
  final double cycleProgress;

  @override
  Widget build(BuildContext context) {
    final bool over = summary.remaining < 0;

    return GlassCard(
      accent: over ? AppColors.clay : AppColors.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Spent',
                  value: Money.format(summary.totalSpent),
                  footnote: 'of ${Money.format(summary.totalLimit)} planned',
                  compact: true,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: over ? 'Over by' : 'Left',
                  value: Money.format(summary.remaining.abs()),
                  accent: over ? AppColors.clay : AppColors.emerald,
                  footnote: '${Money.format(summary.safeDailySpend)} a day',
                  compact: true,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Saved',
                  value: Money.format(summary.saved),
                  accent: AppColors.brass,
                  footnote: 'target ${Money.format(summary.savingsTarget)}',
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProgressBar(
            progress: summary.utilisation,
            marker: cycleProgress,
            height: 10,
          ),
          const SizedBox(height: 9),
          Text(
            'The marker is where a steady spender would be today '
            '(${Money.percent(cycleProgress)} through the cycle).',
            style: AppTextStyles.small,
          ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.summary,
    required this.showSpend,
    required this.onToggle,
  });

  final BudgetSummary summary;
  final bool showSpend;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final List<ChartSlice> slices = <ChartSlice>[
      for (final CategoryUsage u in summary.usage)
        if ((showSpend ? u.spent : u.limit) > 0)
          ChartSlice(
            label: u.category.label,
            value: showSpend ? u.spent : u.limit,
            color: u.category.color,
          ),
    ];

    final double total = showSpend
        ? summary.totalSpent + summary.saved
        : summary.budget.total;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  showSpend ? 'WHERE IT WENT' : 'HOW IT IS PLANNED',
                  style: AppTextStyles.label,
                ),
              ),
              PillButton(
                label: 'Plan',
                selected: !showSpend,
                onTap: () => onToggle(false),
              ),
              const SizedBox(width: 6),
              PillButton(
                label: 'Actual',
                selected: showSpend,
                onTap: () => onToggle(true),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (slices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  showSpend
                      ? 'Nothing spent yet this cycle.'
                      : 'No limits set yet.',
                  style: AppTextStyles.small,
                ),
              ),
            )
          else
            Row(
              children: <Widget>[
                DonutChart(
                  slices: slices,
                  size: 150,
                  thickness: 24,
                  centreValue: Money.compact(total),
                  centreLabel: showSpend ? 'moved' : 'planned',
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: ChartLegend(
                    slices: slices,
                    trailingBuilder: (ChartSlice s) =>
                        total <= 0 ? '—' : Money.percent(s.value / total),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.usage,
    required this.cycleProgress,
    required this.onTap,
  });

  final CategoryUsage usage;
  final double cycleProgress;
  final VoidCallback onTap;

  Color get _statusColor => switch (usage.status) {
        BudgetStatus.over => AppColors.clay,
        BudgetStatus.watch => AppColors.brass,
        BudgetStatus.onTrack => AppColors.emerald,
        BudgetStatus.unset => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final bool savings = usage.category == BudgetCategory.savings;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: usage.category.color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    usage.category.icon,
                    size: 16,
                    color: usage.category.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(usage.category.label, style: AppTextStyles.bodyStrong),
                      const SizedBox(height: 3),
                      Text(
                        usage.limit <= 0
                            ? 'No limit set'
                            : savings
                                ? '${Money.format(usage.spent)} of ${Money.format(usage.limit)} saved'
                                : '${Money.format(usage.spent)} of ${Money.format(usage.limit)}',
                        style: AppTextStyles.small,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      Money.percent(usage.utilisation),
                      style: AppTextStyles.numericSmall
                          .copyWith(color: _statusColor),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      usage.isOver
                          ? 'over ${Money.compact(usage.overspend)}'
                          : '${Money.compact(usage.remaining)} left',
                      style: AppTextStyles.label.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ProgressBar(
              progress: usage.utilisation,
              color: savings ? AppColors.brass : usage.category.color,
              marker: savings ? null : cycleProgress,
              height: 6,
            ),
          ],
        ),
      ),
    );
  }
}

class _Analytics extends StatelessWidget {
  const _Analytics({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final CategoryUsage? largest = summary.largestSpend;
    final double essentials = summary.essentialsSpent;
    final double discretionary = summary.discretionarySpent;
    final double moved = essentials + discretionary;

    return GlassCard(
      child: Column(
        children: <Widget>[
          KeyValueRow(
            label: 'Safe to spend per day',
            value: Money.format(summary.safeDailySpend),
            icon: Icons.today_rounded,
            valueColor: AppColors.emeraldSoft,
          ),
          const Divider(height: 18),
          KeyValueRow(
            label: 'Biggest category',
            value: largest == null
                ? '—'
                : '${largest.category.label} · ${Money.format(largest.spent)}',
            icon: Icons.trending_up_rounded,
          ),
          const Divider(height: 18),
          KeyValueRow(
            label: 'Essentials vs wants',
            value: moved <= 0
                ? '—'
                : '${Money.percent(essentials / moved)} / ${Money.percent(discretionary / moved)}',
            icon: Icons.balance_rounded,
          ),
          const Divider(height: 18),
          KeyValueRow(
            label: 'Savings rate this cycle',
            value: Money.percent(summary.savingsRate),
            icon: Icons.savings_outlined,
            valueColor: summary.savingsRate >= AppConstants.targetSavingsRate
                ? AppColors.emerald
                : AppColors.brass,
          ),
          const Divider(height: 18),
          KeyValueRow(
            label: 'Unallocated salary',
            value: Money.format(summary.unallocated),
            icon: Icons.pie_chart_outline_rounded,
            valueColor:
                summary.unallocated < 0 ? AppColors.clay : AppColors.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.onDelete});

  final Expense expense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool savings = expense.category == BudgetCategory.savings;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: expense.category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              expense.category.icon,
              size: 14,
              color: expense.category.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  expense.displayLabel,
                  style: AppTextStyles.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${expense.category.label} · ${Dates.shortDate(expense.date)}',
                  style: AppTextStyles.label.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
          Text(
            savings
                ? Money.formatSigned(expense.amount)
                : Money.formatSigned(-expense.amount),
            style: AppTextStyles.numericSmall.copyWith(
              color: savings ? AppColors.emerald : AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded, size: 15),
            color: AppColors.textMuted,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Add-expense form. Lives in a sheet, so it keeps its own state.
class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  BudgetCategory _category = BudgetCategory.food;
  late DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final AppState state = context.read<AppState>();
    await state.addExpense(
      category: _category,
      amount: Money.parse(_amount.text) ?? 0,
      date: _date,
      note: _note.text,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final CategoryUsage usage = state.summary.forCategory(_category);
    final double salary = state.profile.monthlySalary;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AmountField(
            controller: _amount,
            label: 'Amount',
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          QuickAmounts(
            amounts: <double>[
              Money.niceRound(salary * 0.005),
              Money.niceRound(salary * 0.01),
              Money.niceRound(salary * 0.025),
              Money.niceRound(salary * 0.05),
            ],
            onPick: (double v) => setState(() {
              _amount.text = Money.plain(v);
            }),
          ),
          const SizedBox(height: 20),
          ChoiceRow<BudgetCategory>(
            label: 'Category',
            values: BudgetCategory.values,
            selected: _category,
            labelOf: (BudgetCategory c) => c.label,
            iconOf: (BudgetCategory c) => c.icon,
            colorOf: (BudgetCategory c) => c.color,
            onChanged: (BudgetCategory c) => setState(() => _category = c),
          ),
          const SizedBox(height: 10),
          if (usage.limit > 0)
            Text(
              usage.isOver
                  ? '${_category.label} is already ${Money.format(usage.overspend)} over its limit.'
                  : '${Money.format(usage.remaining)} left in ${_category.label} this cycle.',
              style: AppTextStyles.small.copyWith(
                color: usage.isOver ? AppColors.clay : AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 20),
          DateField(
            label: 'Date',
            value: _date,
            lastDate: DateTime.now(),
            onChanged: (DateTime d) => setState(() => _date = d),
          ),
          const SizedBox(height: 20),
          TextInputBox(
            controller: _note,
            label: 'Note (optional)',
            hintText: 'Coffee, cab, groceries…',
            maxLength: 40,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Save entry',
            icon: Icons.check_rounded,
            busy: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// Edit every limit at once, with a running total against salary.
class _BudgetForm extends StatefulWidget {
  const _BudgetForm();

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  final Map<BudgetCategory, TextEditingController> _fields =
      <BudgetCategory, TextEditingController>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final AppState state = context.read<AppState>();
    for (final BudgetCategory c in BudgetCategory.values) {
      _fields[c] = TextEditingController(
        text: Money.plain(state.budget.limitFor(c)),
      );
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total {
    double sum = 0;
    for (final TextEditingController c in _fields.values) {
      sum += Money.parse(c.text) ?? 0;
    }
    return sum;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final Map<BudgetCategory, double> limits = <BudgetCategory, double>{
      for (final BudgetCategory c in BudgetCategory.values)
        c: Money.parse(_fields[c]!.text) ?? 0,
    };
    await context.read<AppState>().setLimits(limits);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _regenerate() async {
    final bool yes = await AppSheet.confirm(
      context: context,
      title: 'Rebuild from salary?',
      message: 'This replaces the limits below with a fresh split of your '
          'salary. Logged spending is not affected.',
      confirmLabel: 'Rebuild',
      destructive: false,
    );
    if (!yes || !mounted) return;
    await context.read<AppState>().regenerateBudget();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final double salary = state.profile.monthlySalary;
    final double total = _total;
    final double drift = salary - total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final BudgetCategory c in BudgetCategory.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(c.icon, size: 16, color: c.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(c.label, style: AppTextStyles.body),
                ),
                SizedBox(
                  width: 140,
                  child: AmountField(
                    controller: _fields[c]!,
                    allowZero: true,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 20),
        KeyValueRow(
          label: 'Total planned',
          value: Money.format(total),
          strong: true,
          valueColor: drift < 0 ? AppColors.clay : AppColors.textPrimary,
        ),
        KeyValueRow(
          label: drift < 0 ? 'Over your salary by' : 'Left unplanned',
          value: Money.format(drift.abs()),
          dense: true,
          valueColor: drift < 0 ? AppColors.clay : AppColors.emeraldSoft,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Save limits',
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: _save,
        ),
        const SizedBox(height: 10),
        GhostButton(
          label: 'Rebuild from my salary',
          icon: Icons.auto_fix_high_rounded,
          expand: true,
          onPressed: _regenerate,
        ),
      ],
    );
  }
}

/// One category's entries, plus a shortcut to change its limit.
class _CategoryDetail extends StatelessWidget {
  const _CategoryDetail({required this.category});

  final BudgetCategory category;

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final CategoryUsage usage = state.summary.forCategory(category);
    final List<Expense> entries = state.expensesForCategory(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: 'Limit',
                value: Money.format(usage.limit),
                compact: true,
              ),
            ),
            Expanded(
              child: StatTile(
                label: category == BudgetCategory.savings ? 'Saved' : 'Spent',
                value: Money.format(usage.spent),
                compact: true,
                accent: usage.isOver ? AppColors.clay : null,
              ),
            ),
            Expanded(
              child: StatTile(
                label: 'Expected by now',
                value: Money.format(usage.expectedByNow),
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ProgressBar(
          progress: usage.utilisation,
          color: category.color,
          height: 8,
        ),
        const SizedBox(height: 8),
        Text(usage.status.label, style: AppTextStyles.small),
        const SizedBox(height: 20),
        if (entries.isEmpty)
          Text(
            'No entries in this category this cycle.',
            style: AppTextStyles.small,
          )
        else
          for (final Expense e in entries.take(20))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      e.displayLabel,
                      style: AppTextStyles.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    Dates.shortDate(e.date),
                    style: AppTextStyles.label.copyWith(fontSize: 9),
                  ),
                  const SizedBox(width: 12),
                  Text(Money.format(e.amount), style: AppTextStyles.numericSmall),
                ],
              ),
            ),
      ],
    );
  }
}
