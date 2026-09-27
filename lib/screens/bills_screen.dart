import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/bill.dart';
import '../domain/engines/reminder_engine.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';

/// Bills & Reminder Centre.
///
/// The organising idea: a bill is not an expense you choose, it is money that is
/// already spoken for. So the screen leads with what is still owed this cycle,
/// then shows the fixed cost of a month, and only then lists rows. Reminders are
/// computed on open at the brief's 7 / 3 / 1 / today windows — no notification
/// permission, no background service, nothing to sync.
class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<BillReminder> all = state.reminders;

    final List<BillReminder> overdue = ReminderEngine.overdue(all);
    final List<BillReminder> unpaid = ReminderEngine.unpaid(all);
    final List<BillReminder> paid = ReminderEngine.paid(all);
    final double outstanding = ReminderEngine.outstanding(all);

    final List<BillReminder> dueSoon = unpaid
        .where((BillReminder r) =>
            r.urgency != BillUrgency.overdue && r.daysUntil <= 7)
        .toList(growable: false);
    final List<BillReminder> later = unpaid
        .where((BillReminder r) =>
            r.urgency != BillUrgency.overdue && r.daysUntil > 7)
        .toList(growable: false);

    return ScreenScaffold(
      title: 'Bills',
      subtitle: all.isEmpty
          ? 'Nothing tracked yet'
          : '${unpaid.length} unpaid · ${Money.format(outstanding)} outstanding',
      showBack: true,
      floating: all.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => BillSheets.add(context),
              backgroundColor: AppColors.emerald,
              foregroundColor: AppColors.textOnAccent,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('Add bill', style: AppTextStyles.button),
            ),
      children: all.isEmpty
          ? <Widget>[
              const SizedBox(height: 40),
              EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'No bills tracked',
                message:
                    'Add rent, electricity, internet — anything that comes back '
                    'every month. SaveWise will hold the dates and warn you a '
                    'week out, three days out, the day before, and on the day.',
                actionLabel: 'Add your first bill',
                onAction: () => BillSheets.add(context),
              ),
              const SizedBox(height: 18),
              const _WindowsCard(),
            ]
          : <Widget>[
              _Summary(reminders: all, state: state),
              const SizedBox(height: 16),
              if (ReminderEngine.messages(all, limit: 4).isNotEmpty) ...<Widget>[
                _Alerts(reminders: all),
                const SizedBox(height: 16),
              ],
              if (overdue.isNotEmpty)
                _Group(
                  title: 'Overdue',
                  subtitle: 'Past the due date and still open',
                  reminders: overdue,
                ),
              if (dueSoon.isNotEmpty)
                _Group(
                  title: 'Due soon',
                  subtitle: 'Within the next seven days',
                  reminders: dueSoon,
                ),
              if (later.isNotEmpty)
                _Group(
                  title: 'Later',
                  subtitle: 'Further out this cycle',
                  reminders: later,
                ),
              if (paid.isNotEmpty)
                _Group(
                  title: 'Settled',
                  subtitle: 'Paid for ${Dates.monthLabel(DateTime.now())}',
                  reminders: paid,
                ),
              const SizedBox(height: 4),
              _FixedCostCard(bills: state.bills),
              const SizedBox(height: 16),
              const _WindowsCard(),
            ],
    );
  }
}

// ---------------------------------------------------------------- summary

class _Summary extends StatelessWidget {
  const _Summary({required this.reminders, required this.state});

  final List<BillReminder> reminders;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final double outstanding = ReminderEngine.outstanding(reminders);
    final double settled = ReminderEngine.paidTotal(reminders);
    final double fixed = ReminderEngine.monthlyFixedCost(state.bills);
    final BillReminder? next = ReminderEngine.next(reminders);

    final double salary = state.profile.monthlySalary;
    final double shareOfSalary = salary <= 0 ? 0 : fixed / salary;
    final double afterBills = salary - fixed;

    return GlassCard(
      accent: outstanding > 0 ? AppColors.brass : AppColors.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('STILL OWED THIS CYCLE', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Text(
            Money.format(outstanding),
            style: AppTextStyles.moneyHero.copyWith(
              color: outstanding > 0 ? AppColors.textPrimary : AppColors.emerald,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            outstanding <= 0
                ? 'Every bill is settled. What is left is genuinely yours to '
                    'spend or save.'
                : 'Set this aside before you count anything as spendable.',
            style: AppTextStyles.small,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Paid so far',
                  value: Money.compact(settled),
                  icon: Icons.check_circle_outline_rounded,
                  accent: AppColors.emerald,
                  compact: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Fixed a month',
                  value: Money.compact(fixed),
                  footnote: salary <= 0
                      ? null
                      : '${Money.percent(shareOfSalary)} of salary',
                  icon: Icons.event_repeat_rounded,
                  compact: true,
                ),
              ),
            ],
          ),
          if (salary > 0) ...<Widget>[
            const SizedBox(height: 14),
            ProgressBar(
              progress: shareOfSalary,
              color: shareOfSalary > 0.5
                  ? AppColors.clay
                  : shareOfSalary > 0.35
                      ? AppColors.brass
                      : AppColors.emerald,
              marker: 0.35,
            ),
            const SizedBox(height: 8),
            Text(
              afterBills <= 0
                  ? 'Your fixed bills alone exceed your salary. That gap has to '
                      'close before any plan can work.'
                  : '${Money.format(afterBills)} of salary is left after fixed '
                      'bills. The marker sits at 35%, a comfortable ceiling.',
              style: AppTextStyles.small,
            ),
          ],
          if (next != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.slate,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: Border.all(color: AppColors.hairlineSoft),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    AppConstants.billIcon(next.bill.type),
                    size: 16,
                    color: _urgencyColor(next.urgency),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Next up: ${next.bill.name}, '
                      '${Money.format(next.bill.amount)} '
                      '${next.dueLabel.toLowerCase()}',
                      style: AppTextStyles.small
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The nudges. Rendered as advice tiles with a one-tap settle button, because a
/// reminder you cannot act on is just an interruption.
class _Alerts extends StatelessWidget {
  const _Alerts({required this.reminders});

  final List<BillReminder> reminders;

  @override
  Widget build(BuildContext context) {
    final AppState state = context.read<AppState>();
    final List<BillReminder> flagged = reminders
        .where((BillReminder r) => r.needsAttention || r.isReminderDay)
        .take(4)
        .toList(growable: false);
    if (flagged.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Needs attention',
          icon: Icons.notifications_active_rounded,
        ),
        for (final BillReminder r in flagged)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AdviceTile(
              icon: AppConstants.billIcon(r.bill.type),
              color: _urgencyColor(r.urgency),
              title: r.urgency.label,
              detail: r.message,
              actionLabel: 'Mark paid',
              onAction: () => state.payBill(r.bill.id),
            ),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------------- groups

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.subtitle,
    required this.reminders,
  });

  final String title;
  final String subtitle;
  final List<BillReminder> reminders;

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for (final BillReminder r in reminders) {
      total += r.bill.amount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: title,
          subtitle: '$subtitle · ${Money.format(total)}',
        ),
        for (final BillReminder r in reminders)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BillRow(reminder: r),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.reminder});

  final BillReminder reminder;

  @override
  Widget build(BuildContext context) {
    final AppState state = context.read<AppState>();
    final Bill bill = reminder.bill;
    final Color tint = _urgencyColor(reminder.urgency);
    final bool paid = reminder.isPaid;

    return GlassCard(
      dim: paid,
      accent: reminder.needsAttention ? tint : null,
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      onTap: () => BillSheets.edit(context, bill),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: paid ? 0.10 : 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(AppConstants.billIcon(bill.type), size: 19, color: tint),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        bill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: paid
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Money.format(bill.amount),
                      style: AppTextStyles.moneySmall.copyWith(
                        color: paid
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[
                    StatusPill(
                      text: paid ? 'Paid' : reminder.dueLabel,
                      color: tint,
                      filled: reminder.needsAttention,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bill.recurring
                            ? '${bill.type} · ${DayOfMonthField.ordinal(bill.dueDay)} monthly'
                            : '${bill.type} · one-off ${Dates.shortDate(reminder.dueDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.small,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _SettleButton(
            paid: paid,
            onTap: () => paid
                ? state.unpayBill(bill.id)
                : state.payBill(bill.id),
          ),
        ],
      ),
    );
  }
}

class _SettleButton extends StatelessWidget {
  const _SettleButton({required this.paid, required this.onTap});

  final bool paid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: paid ? Colors.transparent : AppColors.emerald.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(
            color: paid ? AppColors.hairline : AppColors.emerald.withValues(alpha: 0.34),
          ),
        ),
        child: Icon(
          paid ? Icons.undo_rounded : Icons.check_rounded,
          size: 18,
          color: paid ? AppColors.textMuted : AppColors.emerald,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- fixed cost

/// Where the unavoidable money goes. Bills are the part of a budget nobody
/// examines, which is exactly why it is worth drawing.
class _FixedCostCard extends StatelessWidget {
  const _FixedCostCard({required this.bills});

  final List<Bill> bills;

  static const List<Color> _palette = <Color>[
    AppColors.emerald,
    AppColors.brass,
    AppColors.vizTeal,
    AppColors.vizSteel,
    AppColors.vizMauve,
    AppColors.clay,
    AppColors.vizGrey,
  ];

  @override
  Widget build(BuildContext context) {
    final Map<String, double> byType = <String, double>{};
    double total = 0;
    for (final Bill b in bills) {
      if (!b.recurring) continue;
      byType[b.type] = (byType[b.type] ?? 0) + b.amount;
      total += b.amount;
    }
    if (byType.length < 2 || total <= 0) return const SizedBox.shrink();

    final List<String> types = byType.keys.toList()
      ..sort((String a, String b) => byType[b]!.compareTo(byType[a]!));
    final List<ChartSlice> slices = <ChartSlice>[
      for (int i = 0; i < types.length; i++)
        ChartSlice(
          label: types[i],
          value: byType[types[i]]!,
          color: _palette[i % _palette.length],
        ),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(
            title: 'Fixed monthly cost',
            subtitle: 'Recurring bills only',
            icon: Icons.donut_large_rounded,
          ),
          Center(
            child: DonutChart(
              slices: slices,
              centreLabel: 'Every month',
              centreValue: Money.compact(total),
            ),
          ),
          const SizedBox(height: 16),
          ChartLegend(
            slices: slices,
            trailingBuilder: (ChartSlice s) =>
                '${Money.compact(s.value)} · ${Money.percent(s.value / total)}',
          ),
        ],
      ),
    );
  }
}

/// The brief's reminder windows, stated plainly. Users trust a reminder system
/// more when they know exactly when it will speak.
class _WindowsCard extends StatelessWidget {
  const _WindowsCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      dim: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.schedule_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text('WHEN YOU WILL BE REMINDED', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 12),
          const KeyValueRow(
              label: 'A week ahead', value: '7 days before', dense: true),
          const KeyValueRow(
              label: 'Getting close', value: '3 days before', dense: true),
          const KeyValueRow(
              label: 'Last call', value: 'The day before', dense: true),
          const KeyValueRow(label: 'Due', value: 'On the day', dense: true),
          const SizedBox(height: 10),
          Text(
            'Reminders are worked out on this device when you open SaveWise. '
            'There is no server watching your dates and nothing is sent out.',
            style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

Color _urgencyColor(BillUrgency urgency) => switch (urgency) {
      BillUrgency.overdue => AppColors.clay,
      BillUrgency.dueToday => AppColors.clay,
      BillUrgency.dueTomorrow => AppColors.brass,
      BillUrgency.dueThisWeek => AppColors.brass,
      BillUrgency.upcoming => AppColors.vizSteel,
      BillUrgency.paid => AppColors.emerald,
    };

// ----------------------------------------------------------------- sheets

abstract final class BillSheets {
  static Future<void> add(BuildContext context) => AppSheet.show<void>(
        context: context,
        title: 'Add a bill',
        subtitle: 'Recurring or one-off — SaveWise handles the dates.',
        child: const _BillForm(),
      );

  static Future<void> edit(BuildContext context, Bill bill) =>
      AppSheet.show<void>(
        context: context,
        title: 'Edit bill',
        subtitle: bill.name,
        child: _BillForm(existing: bill),
      );
}

class _BillForm extends StatefulWidget {
  const _BillForm({this.existing});

  final Bill? existing;

  @override
  State<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends State<_BillForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money.plain(widget.existing!.amount, decimals: true),
  );

  late String _type = widget.existing?.type ?? AppConstants.billTypes.first;
  late int _dueDay = widget.existing?.dueDay ?? 1;
  late bool _recurring = widget.existing?.recurring ?? true;
  late DateTime _oneOff = widget.existing?.oneOffDate ??
      DateTime.now().add(const Duration(days: 7));
  late bool _autoLog = widget.existing?.autoLogAsExpense ?? true;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final double amount = AmountField.valueOf(_amount) ?? 0;
    if (amount <= 0) return;

    final AppState state = context.read<AppState>();
    final NavigatorState nav = Navigator.of(context);
    final Bill? existing = widget.existing;

    if (existing == null) {
      await state.addBill(
        name: _name.text,
        type: _type,
        amount: amount,
        dueDay: _dueDay,
        recurring: _recurring,
        oneOffDate: _recurring ? null : Dates.dateOnly(_oneOff),
        autoLogAsExpense: _autoLog,
      );
    } else {
      await state.updateBill(
        existing.copyWith(
          name: _name.text.trim().isEmpty ? _type : _name.text.trim(),
          type: _type,
          amount: amount,
          dueDay: _recurring ? _dueDay : _oneOff.day,
          recurring: _recurring,
          oneOffDate: _recurring ? null : Dates.dateOnly(_oneOff),
          autoLogAsExpense: _autoLog,
        ),
      );
    }
    nav.pop();
  }

  Future<void> _delete() async {
    final Bill? existing = widget.existing;
    if (existing == null) return;
    final bool ok = await AppSheet.confirm(
      context: context,
      title: 'Delete ${existing.name}?',
      message:
          'The bill and its payment history are removed. Expenses you already '
          'logged for it stay in the ledger.',
    );
    if (!ok || !mounted) return;
    final AppState state = context.read<AppState>();
    final NavigatorState nav = Navigator.of(context);
    await state.deleteBill(existing.id);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final double salary = state.profile.monthlySalary;
    final double amount = AmountField.valueOf(_amount) ?? 0;
    final double fixedAfter = ReminderEngine.monthlyFixedCost(state.bills) -
        (widget.existing?.amount ?? 0) +
        amount;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ChoiceRow<String>(
            label: 'What is it',
            values: AppConstants.billTypes,
            selected: _type,
            scroll: true,
            labelOf: (String t) => t,
            iconOf: AppConstants.billIcon,
            onChanged: (String t) => setState(() {
              _type = t;
              if (_name.text.trim().isEmpty) _name.text = t;
            }),
          ),
          const SizedBox(height: 16),
          TextInputBox(
            controller: _name,
            label: 'Name',
            hintText: _type,
            maxLength: 40,
            prefixIcon: Icons.label_outline_rounded,
          ),
          const SizedBox(height: 16),
          AmountField(
            controller: _amount,
            label: 'Amount',
            autofocus: widget.existing == null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          ToggleRow(
            title: 'Repeats every month',
            subtitle: _recurring
                ? 'Counts towards your fixed monthly cost'
                : 'A single payment on one date',
            icon: Icons.event_repeat_rounded,
            value: _recurring,
            onChanged: (bool v) => setState(() => _recurring = v),
          ),
          const SizedBox(height: 10),
          if (_recurring)
            DayOfMonthField(
              label: 'Due on',
              day: _dueDay,
              helper: 'Shifts to the last day in shorter months.',
              onChanged: (int d) => setState(() => _dueDay = d),
            )
          else
            DateField(
              label: 'Due date',
              value: _oneOff,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              onChanged: (DateTime d) => setState(() => _oneOff = d),
            ),
          const SizedBox(height: 8),
          ToggleRow(
            title: 'Log as an expense when paid',
            subtitle:
                'Keeps the budget honest — paying here also records the spend.',
            icon: Icons.receipt_rounded,
            value: _autoLog,
            onChanged: (bool v) => setState(() => _autoLog = v),
          ),
          if (amount > 0 && salary > 0) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.slate,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: Border.all(color: AppColors.hairlineSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  KeyValueRow(
                    label: 'Fixed cost after this',
                    value: Money.format(fixedAfter),
                    dense: true,
                  ),
                  KeyValueRow(
                    label: 'Share of salary',
                    value: Money.percent(fixedAfter / salary),
                    valueColor: fixedAfter / salary > 0.5
                        ? AppColors.clay
                        : fixedAfter / salary > 0.35
                            ? AppColors.brass
                            : AppColors.emerald,
                    dense: true,
                  ),
                  KeyValueRow(
                    label: 'Left after fixed bills',
                    value: Money.format(salary - fixedAfter),
                    dense: true,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: widget.existing == null ? 'Add bill' : 'Save changes',
            onPressed: _save,
          ),
          if (widget.existing != null) ...<Widget>[
            const SizedBox(height: 8),
            GhostButton(
              label: 'Delete bill',
              icon: Icons.delete_outline_rounded,
              color: AppColors.clay,
              onPressed: _delete,
            ),
          ],
        ],
      ),
    );
  }
}
