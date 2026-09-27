import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../data/models/goal.dart';
import '../domain/engines/goal_engine.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';
import '../widgets/rings.dart';

/// Smart Goal Saving.
///
/// The user supplies a name, a cost and a date. Everything else — the monthly,
/// weekly and daily figure, the projected landing date, the milestones — is
/// derived, and the projection uses the pace they have actually kept rather
/// than the one they intended.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<Goal> goals = state.goals;
    final List<Goal> open =
        goals.where((Goal g) => !g.isComplete).toList(growable: false);
    final List<Goal> done =
        goals.where((Goal g) => g.isComplete).toList(growable: false);

    return ScreenScaffold(
      title: 'Goals',
      subtitle: goals.isEmpty
          ? 'Turn a want into a number and a date.'
          : '${open.length} in progress · ${done.length} funded',
      floating: FloatingActionButton.extended(
        onPressed: () => GoalSheets.add(context),
        backgroundColor: AppColors.emerald,
        foregroundColor: AppColors.textOnAccent,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'New goal',
          style: AppTextStyles.button.copyWith(color: AppColors.textOnAccent),
        ),
      ),
      children: <Widget>[
        if (goals.isEmpty)
          EmptyState(
            icon: Icons.flag_outlined,
            title: 'No goals yet',
            message:
                'A phone, a trip, a deposit. Give it a price and a date and I will '
                'work out what it costs you per day.',
            actionLabel: 'Create a goal',
            onAction: () => GoalSheets.add(context),
          )
        else ...<Widget>[
          Reveal(child: _CapacityCard(state: state)),
          const SizedBox(height: 20),
          if (open.isNotEmpty) ...<Widget>[
            const SectionHeader(title: 'In progress'),
            for (int i = 0; i < open.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Reveal(
                  delayMs: 40 * i,
                  child: _GoalCard(
                    goal: open[i],
                    plan: state.planFor(open[i].id),
                  ),
                ),
              ),
          ],
          if (done.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            SectionHeader(
              title: 'Funded',
              subtitle: '${done.length} goal${done.length == 1 ? '' : 's'} paid for',
            ),
            for (final Goal g in done)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GoalCard(goal: g, plan: state.planFor(g.id)),
              ),
          ],
        ],
      ],
    );
  }
}

class _CapacityCard extends StatelessWidget {
  const _CapacityCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final double capacity = state.monthlyCapacity;
    double demanded = 0;
    for (final GoalPlan p in state.goalPlans) {
      if (!p.isComplete) demanded += p.monthlyRequired;
    }
    final bool stretched = demanded > capacity && capacity > 0;

    return GlassCard(
      accent: stretched ? AppColors.brass : AppColors.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Monthly capacity',
                  value: Money.format(capacity),
                  footnote: 'What your plan can spare for goals',
                  compact: true,
                  icon: Icons.savings_outlined,
                  accent: AppColors.emerald,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Goals demand',
                  value: Money.format(demanded),
                  footnote: stretched
                      ? 'More than you can spare'
                      : 'Within your capacity',
                  compact: true,
                  icon: Icons.flag_outlined,
                  accent: stretched ? AppColors.brass : null,
                ),
              ),
            ],
          ),
          if (capacity > 0) ...<Widget>[
            const SizedBox(height: 14),
            ProgressBar(
              progress: demanded / capacity,
              color: stretched ? AppColors.brass : AppColors.emerald,
              height: 7,
            ),
          ],
          if (stretched) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Something has to give: push a target date out, lower a cost, or '
              'raise your savings target.',
              style: AppTextStyles.small,
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.plan});

  final Goal goal;
  final GoalPlan? plan;

  @override
  Widget build(BuildContext context) {
    final Color tint = goal.isComplete ? AppColors.emerald : goal.priority.color;

    return GlassCard(
      accent: tint,
      dim: goal.isComplete,
      onTap: () => GoalSheets.detail(context, goal.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ProgressRing(
                progress: goal.progress,
                size: 58,
                strokeWidth: 6,
                color: tint,
                child: goal.isComplete
                    ? const Icon(Icons.check_rounded,
                        size: 22, color: AppColors.emerald)
                    : Text(
                        '${goal.progressPercent}',
                        style: AppTextStyles.numericSmall
                            .copyWith(fontSize: 14, color: tint),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      goal.name,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Money.format(goal.saved)} of ${Money.format(goal.cost)}',
                      style: AppTextStyles.small,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        StatusPill(
                          text: goal.priority.label,
                          color: goal.priority.color,
                        ),
                        const SizedBox(width: 8),
                        if (plan != null)
                          Flexible(
                            child: Text(
                              plan!.verdict,
                              style: AppTextStyles.label.copyWith(
                                fontSize: 9.5,
                                color: plan!.onTrack
                                    ? AppColors.emeraldSoft
                                    : AppColors.brass,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!goal.isComplete && plan != null) ...<Widget>[
            const Divider(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Mini(
                    label: 'Per month',
                    value: Money.compact(plan!.monthlyRequired),
                  ),
                ),
                Expanded(
                  child: _Mini(
                    label: 'Per week',
                    value: Money.compact(plan!.weeklyRequired),
                  ),
                ),
                Expanded(
                  child: _Mini(
                    label: 'Per day',
                    value: Money.compact(plan!.dailyRequired),
                  ),
                ),
                Expanded(
                  child: _Mini(
                    label: 'Days left',
                    value: plan!.daysRemaining < 0
                        ? 'passed'
                        : '${plan!.daysRemaining}',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _Milestones(goal: goal, tint: tint),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: AppTextStyles.label.copyWith(fontSize: 8.5)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.numericSmall),
      ],
    );
  }
}

class _Milestones extends StatelessWidget {
  const _Milestones({required this.goal, required this.tint});

  final Goal goal;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final int m in AppConstants.goalMilestones)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: goal.progressPercent >= m
                          ? tint
                          : AppColors.hairlineSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$m%',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 8.5,
                      color: goal.progressPercent >= m
                          ? tint
                          : AppColors.textMuted,
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

/// Sheets for creating, funding and editing a goal. Grouped so the dashboard
/// and the advisor can open them too.
abstract final class GoalSheets {
  static Future<void> add(BuildContext context) => AppSheet.show<void>(
        context: context,
        title: 'New goal',
        subtitle: 'Name it, price it, date it. I will do the arithmetic.',
        child: const _GoalForm(),
      );

  static Future<void> edit(BuildContext context, Goal goal) =>
      AppSheet.show<void>(
        context: context,
        title: 'Edit goal',
        child: _GoalForm(existing: goal),
      );

  static Future<void> detail(BuildContext context, String goalId) =>
      AppSheet.show<void>(
        context: context,
        title: 'Goal',
        child: _GoalDetail(goalId: goalId),
      );

  static Future<void> contribute(BuildContext context, Goal goal) =>
      AppSheet.show<void>(
        context: context,
        title: 'Add to ${goal.name}',
        subtitle: 'Counts as savings, so it lifts your score too.',
        child: _ContributeForm(goal: goal),
      );

  static Future<void> withdraw(BuildContext context, Goal goal) =>
      AppSheet.show<void>(
        context: context,
        title: 'Take out of ${goal.name}',
        subtitle: 'Plans change. This does not delete the goal.',
        child: _ContributeForm(goal: goal, withdrawing: true),
      );
}

class _GoalForm extends StatefulWidget {
  const _GoalForm({this.existing});

  final Goal? existing;

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _note;
  late DateTime _target;
  late GoalPriority _priority;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final Goal? g = widget.existing;
    _name = TextEditingController(text: g?.name ?? '');
    _cost = TextEditingController(
      text: g == null ? '' : Money.plain(g.cost),
    );
    _note = TextEditingController(text: g?.note ?? '');
    _target = g?.targetDate ?? DateTime.now().add(const Duration(days: 180));
    _priority = g?.priority ?? GoalPriority.medium;
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final AppState state = context.read<AppState>();
    final double cost = Money.parse(_cost.text) ?? 0;

    if (widget.existing == null) {
      await state.addGoal(
        name: _name.text,
        cost: cost,
        targetDate: _target,
        priority: _priority,
        note: _note.text,
      );
    } else {
      await state.updateGoal(
        widget.existing!.copyWith(
          name: _name.text.trim(),
          cost: cost,
          targetDate: _target,
          priority: _priority,
          note: _note.text.trim(),
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final double cost = Money.parse(_cost.text) ?? 0;
    final int days = Dates.daysBetween(state.now, _target);
    final double monthly = cost <= 0 || days <= 0 ? 0 : cost / (days / 30.44);

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextInputBox(
            controller: _name,
            label: 'What is it?',
            hintText: 'iPhone, Japan trip, house deposit…',
            required: true,
            autofocus: widget.existing == null,
            maxLength: 32,
          ),
          const SizedBox(height: 20),
          AmountField(
            controller: _cost,
            label: 'Total cost',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          DateField(
            label: 'Target date',
            value: _target,
            firstDate: state.now,
            onChanged: (DateTime d) => setState(() => _target = d),
          ),
          const SizedBox(height: 20),
          ChoiceRow<GoalPriority>(
            label: 'Priority',
            values: GoalPriority.values,
            selected: _priority,
            labelOf: (GoalPriority p) => p.label,
            colorOf: (GoalPriority p) => p.color,
            onChanged: (GoalPriority p) => setState(() => _priority = p),
          ),
          const SizedBox(height: 8),
          Text(
            'Priority decides how spare savings get split between goals.',
            style: AppTextStyles.small,
          ),
          const SizedBox(height: 20),
          TextInputBox(
            controller: _note,
            label: 'Note (optional)',
            hintText: 'Model, colour, who it is for…',
            maxLength: 60,
          ),
          if (monthly > 0) ...<Widget>[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('THAT WORKS OUT TO', style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Mini(
                          label: 'Monthly',
                          value: Money.format(monthly),
                        ),
                      ),
                      Expanded(
                        child: _Mini(
                          label: 'Weekly',
                          value: Money.format(cost / (days / 7)),
                        ),
                      ),
                      Expanded(
                        child: _Mini(
                          label: 'Daily',
                          value: Money.format(cost / days),
                        ),
                      ),
                    ],
                  ),
                  if (monthly > state.monthlyCapacity &&
                      state.monthlyCapacity > 0) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      'That is above the ${Money.format(state.monthlyCapacity)} '
                      'a month your plan can spare. Consider a later date.',
                      style: AppTextStyles.small.copyWith(color: AppColors.brass),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: widget.existing == null ? 'Create goal' : 'Save changes',
            icon: Icons.check_rounded,
            busy: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _GoalDetail extends StatelessWidget {
  const _GoalDetail({required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final Goal? goal = state.goalById(goalId);
    if (goal == null) return const SizedBox.shrink();
    final GoalPlan? plan = state.planFor(goalId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: ProgressRing(
            progress: goal.progress,
            size: 120,
            strokeWidth: 11,
            color: goal.isComplete ? AppColors.emerald : goal.priority.color,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${goal.progressPercent}%',
                  style: AppTextStyles.moneyMedium.copyWith(
                    color: goal.isComplete
                        ? AppColors.emerald
                        : goal.priority.color,
                  ),
                ),
                Text('funded', style: AppTextStyles.label),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(child: Text(goal.name, style: AppTextStyles.cardTitle)),
        if (goal.note.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Center(child: Text(goal.note, style: AppTextStyles.small)),
        ],
        const SizedBox(height: 20),
        KeyValueRow(
          label: 'Saved',
          value: Money.format(goal.saved),
          strong: true,
          valueColor: AppColors.emerald,
        ),
        KeyValueRow(label: 'Cost', value: Money.format(goal.cost), dense: true),
        KeyValueRow(
          label: 'Still needed',
          value: Money.format(goal.remaining),
          dense: true,
        ),
        const Divider(height: 22),
        KeyValueRow(
          label: 'Target date',
          value: Dates.mediumDate(goal.targetDate),
          icon: Icons.event_rounded,
          dense: true,
        ),
        if (plan != null) ...<Widget>[
          KeyValueRow(
            label: 'Needed per month',
            value: Money.format(plan.monthlyRequired),
            icon: Icons.calendar_month_rounded,
            dense: true,
          ),
          KeyValueRow(
            label: 'Needed per week',
            value: Money.format(plan.weeklyRequired),
            icon: Icons.date_range_rounded,
            dense: true,
          ),
          KeyValueRow(
            label: 'Needed per day',
            value: Money.format(plan.dailyRequired),
            icon: Icons.today_rounded,
            dense: true,
          ),
          const Divider(height: 22),
          KeyValueRow(
            label: 'Your actual pace',
            value: plan.observedMonthlyPace <= 0
                ? 'Not started'
                : '${Money.format(plan.observedMonthlyPace)} / month',
            icon: Icons.speed_rounded,
            dense: true,
          ),
          KeyValueRow(
            label: 'Expected completion',
            value: plan.projectedCompletion == null
                ? 'Needs a first deposit'
                : Dates.mediumDate(plan.projectedCompletion!),
            icon: Icons.flag_circle_outlined,
            dense: true,
            valueColor: plan.onTrack ? AppColors.emerald : AppColors.brass,
          ),
          const SizedBox(height: 10),
          Text(plan.verdict, style: AppTextStyles.small),
        ],
        const SizedBox(height: 22),
        if (!goal.isComplete)
          PrimaryButton(
            label: 'Add money',
            icon: Icons.add_rounded,
            onPressed: () {
              Navigator.of(context).pop();
              GoalSheets.contribute(context, goal);
            },
          ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: GhostButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                expand: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  GoalSheets.edit(context, goal);
                },
              ),
            ),
            const SizedBox(width: 10),
            if (goal.saved > 0)
              Expanded(
                child: GhostButton(
                  label: 'Withdraw',
                  icon: Icons.remove_rounded,
                  expand: true,
                  color: AppColors.brass,
                  onPressed: () {
                    Navigator.of(context).pop();
                    GoalSheets.withdraw(context, goal);
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () async {
              final bool yes = await AppSheet.confirm(
                context: context,
                title: 'Delete ${goal.name}?',
                message:
                    'The goal goes away. Money you logged as savings stays counted.',
              );
              if (!yes) return;
              await state.deleteGoal(goal.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Delete goal'),
            style: TextButton.styleFrom(foregroundColor: AppColors.clay),
          ),
        ),
      ],
    );
  }
}

class _ContributeForm extends StatefulWidget {
  const _ContributeForm({required this.goal, this.withdrawing = false});

  final Goal goal;
  final bool withdrawing;

  @override
  State<_ContributeForm> createState() => _ContributeFormState();
}

class _ContributeFormState extends State<_ContributeForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final AppState state = context.read<AppState>();
    final double amount = Money.parse(_amount.text) ?? 0;
    if (widget.withdrawing) {
      await state.withdrawFromGoal(goalId: widget.goal.id, amount: amount);
    } else {
      await state.contributeToGoal(goalId: widget.goal.id, amount: amount);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final GoalPlan? plan = state.planFor(widget.goal.id);
    final double max = widget.withdrawing ? widget.goal.saved : double.infinity;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AmountField(
            controller: _amount,
            label: 'Amount',
            autofocus: true,
            max: max.isFinite ? max : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (!widget.withdrawing)
            QuickAmounts(
              amounts: <double>[
                if (plan != null && plan.dailyRequired > 0)
                  Money.niceRound(plan.dailyRequired),
                if (plan != null && plan.weeklyRequired > 0)
                  Money.niceRound(plan.weeklyRequired),
                if (plan != null && plan.monthlyRequired > 0)
                  Money.niceRound(plan.monthlyRequired),
                if (widget.goal.remaining > 0) widget.goal.remaining,
              ],
              onPick: (double v) =>
                  setState(() => _amount.text = Money.plain(v)),
            ),
          const SizedBox(height: 18),
          KeyValueRow(
            label: 'Currently saved',
            value: Money.format(widget.goal.saved),
            dense: true,
          ),
          KeyValueRow(
            label: 'Still needed',
            value: Money.format(widget.goal.remaining),
            dense: true,
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: widget.withdrawing ? 'Withdraw' : 'Add to goal',
            icon: widget.withdrawing ? Icons.remove_rounded : Icons.check_rounded,
            gradient: widget.withdrawing ? AppColors.brassSweep : null,
            busy: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
