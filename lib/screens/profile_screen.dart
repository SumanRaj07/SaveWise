import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../domain/engines/emergency_fund_engine.dart';
import '../domain/engines/health_score_engine.dart';
import '../domain/engines/reminder_engine.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';
import 'main_shell.dart';

/// Profile: the settings tab, plus the way into every screen that is not on the
/// bottom bar.
///
/// The privacy section is not boilerplate. An account-free, offline finance app
/// is unusual enough that users assume there must be a catch, so the app states
/// plainly what it does and does not do, and backs it up with a delete button
/// that really does erase everything.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();

    return ScreenScaffold(
      title: 'Profile',
      subtitle: '${AppConstants.appName} · ${AppConstants.tagline}',
      children: <Widget>[
        _IdentityCard(state: state),
        const SizedBox(height: 18),
        const SectionHeader(title: 'Your money', icon: Icons.tune_rounded),
        _SettingsCard(state: state),
        const SizedBox(height: 18),
        const SectionHeader(
          title: 'Everything else',
          subtitle: 'The screens that are not on the bar',
          icon: Icons.apps_rounded,
        ),
        _LinksCard(state: state),
        const SizedBox(height: 18),
        const SectionHeader(
            title: 'Your data', icon: Icons.privacy_tip_rounded),
        const _PrivacyCard(),
        const SizedBox(height: 12),
        _DangerCard(state: state),
        const SizedBox(height: 20),
        const _AboutFooter(),
      ],
    );
  }
}

// ------------------------------------------------------------------ identity

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final String name = state.profile.name;
    final String initial =
        name.trim().isEmpty ? '·' : name.trim()[0].toUpperCase();

    return GlassCard(
      accent: AppColors.emerald,
      onTap: () => ProfileSheets.editIdentity(context),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.emeraldSweep,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Text(
                  initial,
                  style: AppTextStyles.moneyMedium
                      .copyWith(color: AppColors.textOnAccent),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name.trim().isEmpty ? 'No name set' : name,
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Level ${state.profile.level} · '
                      '${state.profile.coins} coins · '
                      '${state.profile.streak} day streak',
                      style: AppTextStyles.small,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Using SaveWise since '
                      '${Dates.mediumDate(state.profile.createdAt)}',
                      style: AppTextStyles.small
                          .copyWith(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_rounded, size: 17, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: 'Health score',
                  value: '${state.score.total}',
                  footnote: state.score.grade.label,
                  accent: AppColors.forScore(state.score.total),
                  compact: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Saved so far',
                  value: Money.compact(state.lifetimeSaved),
                  footnote: 'All time',
                  accent: AppColors.emerald,
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ settings

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        children: <Widget>[
          _Row(
            icon: Icons.payments_rounded,
            title: 'Monthly salary',
            value: Money.format(state.profile.monthlySalary),
            onTap: () => ProfileSheets.editIncome(context),
          ),
          _Row(
            icon: Icons.event_rounded,
            title: 'Salary lands on',
            value: DayOfMonthField.ordinal(state.profile.salaryDay),
            subtitle: 'Next: ${Dates.mediumDate(
              Dates.nextSalaryDate(state.now, state.profile.salaryDay),
            )}',
            onTap: () => ProfileSheets.editIncome(context),
          ),
          _Row(
            icon: Icons.flag_circle_rounded,
            title: 'Savings target',
            value: Money.percent(state.profile.savingsRateTarget),
            subtitle:
                '${Money.format(state.profile.monthlySalary * state.profile.savingsRateTarget)} a month',
            onTap: () => ProfileSheets.editIncome(context),
          ),
          _Row(
            icon: Icons.currency_exchange_rounded,
            title: 'Currency',
            value: '${state.profile.currencySymbol} ${state.profile.currencyCode}',
            onTap: () => ProfileSheets.editCurrency(context),
          ),
          _Row(
            icon: Icons.pie_chart_rounded,
            title: 'Category limits',
            value: Money.compact(state.summary.totalLimit),
            subtitle: 'Seven categories, ${Money.percent(state.summary.utilisation)} used',
            onTap: () => ShellNav.planner(context),
            last: true,
          ),
        ],
      ),
    );
  }
}

class _LinksCard extends StatelessWidget {
  const _LinksCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final int unpaid = ReminderEngine.unpaid(state.reminders).length;
    final double outstanding = ReminderEngine.outstanding(state.reminders);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        children: <Widget>[
          _Row(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Salary planner',
            subtitle: 'Budgets, spending and category analytics',
            onTap: () => ShellNav.planner(context),
          ),
          _Row(
            icon: Icons.shield_rounded,
            title: 'Emergency fund',
            value: '${state.emergency.percentOfIdeal}%',
            subtitle: state.emergency.readiness.label,
            onTap: () => ShellNav.emergency(context),
          ),
          _Row(
            icon: Icons.receipt_long_rounded,
            title: 'Bills and reminders',
            value: unpaid == 0 ? null : '$unpaid due',
            subtitle: state.bills.isEmpty
                ? 'Nothing tracked yet'
                : unpaid == 0
                    ? '${state.bills.length} tracked · all settled'
                    : '${state.bills.length} tracked · '
                        '${Money.compact(outstanding)} outstanding',
            onTap: () => ShellNav.bills(context),
          ),
          _Row(
            icon: Icons.auto_awesome_rounded,
            title: 'SaveWise advisor',
            subtitle: 'Ask about your own numbers',
            onTap: () => ShellNav.advisor(context),
          ),
          _Row(
            icon: Icons.insights_rounded,
            title: 'Reports and analytics',
            subtitle: 'Monthly report and six-month trends',
            onTap: () => ShellNav.reports(context),
          ),
          _Row(
            icon: Icons.workspace_premium_rounded,
            title: 'Achievements',
            value: '${state.unlockedAt.length}',
            subtitle: 'Badges earned',
            onTap: () => ShellNav.achievements(context),
            last: true,
          ),
        ],
      ),
    );
  }
}

/// A settings/navigation row. Kept local to this screen because nowhere else
/// needs a list row this plain.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.subtitle,
    this.last = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? value;
  final String? subtitle;
  final VoidCallback onTap;
  final bool last;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color tint = danger ? AppColors.clay : AppColors.textSecondary;

    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 19, color: tint),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: AppTextStyles.body.copyWith(
                          color: danger
                              ? AppColors.clay
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(subtitle!, style: AppTextStyles.small),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...<Widget>[
                  const SizedBox(width: 10),
                  Text(
                    value!,
                    style: AppTextStyles.numericSmall.copyWith(
                      color: danger ? AppColors.clay : AppColors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 19, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Divider(color: AppColors.hairlineSoft, height: 1),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------- privacy

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (IconData icon, String title, String detail)
              in const <(IconData, String, String)>[
            (
              Icons.wifi_off_rounded,
              'Works with no internet',
              'Every screen, every calculation and every piece of advice is '
                  'produced on this device. Turn off your connection and '
                  'nothing changes.',
            ),
            (
              Icons.cloud_off_rounded,
              'Nothing is uploaded',
              'SaveWise has no server, no analytics and no account. Your salary, '
                  'spending, goals and chat history never leave this phone.',
            ),
            (
              Icons.no_accounts_rounded,
              'No sign-in, ever',
              'No registration, no email, no phone number, no OTP, no password. '
                  'The app was usable the moment you installed it.',
            ),
            (
              Icons.storage_rounded,
              'Stored on this device only',
              'Data lives in this app\'s private storage. Uninstalling SaveWise '
                  'removes all of it.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 16, color: AppColors.emerald),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: AppTextStyles.bodyStrong),
                        const SizedBox(height: 4),
                        Text(detail,
                            style: AppTextStyles.small.copyWith(height: 1.45)),
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

class _DangerCard extends StatelessWidget {
  const _DangerCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: _Row(
        icon: Icons.delete_forever_rounded,
        title: 'Erase everything',
        subtitle: 'Profile, budgets, goals, fund, bills, badges and history',
        danger: true,
        last: true,
        onTap: () => ProfileSheets.wipe(context),
      ),
    );
  }
}

class _AboutFooter extends StatelessWidget {
  const _AboutFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(AppConstants.appName,
            style: AppTextStyles.cardTitle
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          AppConstants.tagline,
          style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        Text(
          'Offline personal finance, built for one phone and one person.',
          textAlign: TextAlign.center,
          style: AppTextStyles.small
              .copyWith(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- sheets

abstract final class ProfileSheets {
  static Future<void> editIdentity(BuildContext context) => AppSheet.show<void>(
        context: context,
        title: 'Your name',
        subtitle: 'Only used to greet you. It stays on this device.',
        child: const _NameForm(),
      );

  static Future<void> editIncome(BuildContext context) => AppSheet.show<void>(
        context: context,
        title: 'Income and target',
        subtitle: 'Changing salary re-scales the suggested plan, not your '
            'existing limits.',
        child: const _IncomeForm(),
      );

  static Future<void> editCurrency(BuildContext context) => AppSheet.show<void>(
        context: context,
        title: 'Currency',
        subtitle: 'Amounts are relabelled, not converted.',
        child: const _CurrencyForm(),
      );

  static Future<void> wipe(BuildContext context) async {
    final AppState state = context.read<AppState>();
    final bool ok = await AppSheet.confirm(
      context: context,
      title: 'Erase everything?',
      message:
          'This deletes your profile, budgets, expenses, goals, emergency fund, '
          'bills, challenges, badges and month history from this device. There '
          'is no backup anywhere, so this cannot be undone.',
      confirmLabel: 'Erase everything',
    );
    if (!ok) return;
    await state.wipeEverything();
  }
}

class _NameForm extends StatefulWidget {
  const _NameForm();

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  late final TextEditingController _name = TextEditingController(
    text: context.read<AppState>().profile.name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextInputBox(
          controller: _name,
          label: 'Name',
          hintText: 'Leave blank to skip',
          maxLength: 24,
          autofocus: true,
          prefixIcon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Save',
          onPressed: () async {
            final AppState state = context.read<AppState>();
            final NavigatorState nav = Navigator.of(context);
            await state.updateProfile(name: _name.text);
            nav.pop();
          },
        ),
      ],
    );
  }
}

class _IncomeForm extends StatefulWidget {
  const _IncomeForm();

  @override
  State<_IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends State<_IncomeForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final AppState _initial = context.read<AppState>();
  late final TextEditingController _salary = TextEditingController(
    text: _initial.profile.monthlySalary <= 0
        ? ''
        : Money.plain(_initial.profile.monthlySalary),
  );
  late int _day = _initial.profile.salaryDay;
  late double _rate = _initial.profile.savingsRateTarget;

  @override
  void dispose() {
    _salary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double salary = AmountField.valueOf(_salary) ?? 0;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AmountField(
            controller: _salary,
            label: 'Monthly salary',
            helper: 'Take-home pay, after tax and deductions.',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          DayOfMonthField(
            label: 'Salary lands on',
            day: _day,
            helper: 'Budgets run payday to payday, not from the 1st.',
            onChanged: (int d) => setState(() => _day = d),
          ),
          const SizedBox(height: 16),
          RateSlider(
            label: 'Savings target',
            value: _rate,
            min: 0.05,
            max: 0.5,
            divisions: 9,
            helper: _rate >= AppConstants.targetSavingsRate
                ? 'At or above the 20% benchmark the health score uses.'
                : 'Below the 20% benchmark — a fine place to start.',
            onChanged: (double v) => setState(() => _rate = v),
          ),
          if (salary > 0) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.slate,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: Border.all(color: AppColors.hairlineSoft),
              ),
              child: Column(
                children: <Widget>[
                  KeyValueRow(
                    label: 'Target saving',
                    value: '${Money.format(salary * _rate)} a month',
                    dense: true,
                  ),
                  KeyValueRow(
                    label: 'Left to live on',
                    value: Money.format(salary * (1 - _rate)),
                    dense: true,
                  ),
                  KeyValueRow(
                    label: 'A year of saving',
                    value: Money.format(salary * _rate * 12),
                    valueColor: AppColors.emerald,
                    dense: true,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Save',
            onPressed: () async {
              if (!(_form.currentState?.validate() ?? false)) return;
              final double value = AmountField.valueOf(_salary) ?? 0;
              if (value <= 0) return;
              final AppState state = context.read<AppState>();
              final NavigatorState nav = Navigator.of(context);
              await state.updateProfile(
                monthlySalary: value,
                salaryDay: _day,
                savingsRateTarget: _rate,
              );
              nav.pop();
            },
          ),
          const SizedBox(height: 8),
          GhostButton(
            label: 'Rebuild plan from salary',
            icon: Icons.refresh_rounded,
            expand: true,
            onPressed: () async {
              final AppState state = context.read<AppState>();
              final NavigatorState nav = Navigator.of(context);
              await state.regenerateBudget();
              nav.pop();
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Rebuilding discards limits you edited by hand and returns the seven '
            'categories to the suggested split.',
            style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CurrencyForm extends StatefulWidget {
  const _CurrencyForm();

  @override
  State<_CurrencyForm> createState() => _CurrencyFormState();
}

class _CurrencyFormState extends State<_CurrencyForm> {
  static const List<(String code, String symbol)> _options =
      <(String, String)>[
    ('USD', r'$'),
    ('EUR', '€'),
    ('GBP', '£'),
    ('INR', '₹'),
    ('JPY', '¥'),
    ('AUD', r'A$'),
    ('CAD', r'C$'),
    ('AED', 'AED'),
    ('SGD', r'S$'),
    ('ZAR', 'R'),
    ('BRL', r'R$'),
    ('NGN', '₦'),
  ];

  late String _code = context.read<AppState>().profile.currencyCode;
  late String _symbol = context.read<AppState>().profile.currencySymbol;

  List<(String, String)> get _sorted {
    final List<(String, String)> list = List<(String, String)>.of(_options);
    final int index = list.indexWhere(((String, String) c) => c.$1 == _code);
    if (index > 0) {
      final (String, String) found = list.removeAt(index);
      list.insert(0, found);
    } else if (index < 0) {
      list.insert(0, (_code, _symbol));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final (String code, String symbol) in _sorted)
              PillButton(
                label: '$symbol $code',
                selected: code == _code,
                accent: AppColors.brass,
                onTap: () => setState(() {
                  _code = code;
                  _symbol = symbol;
                }),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.slate,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(color: AppColors.hairlineSoft),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.info_outline_rounded,
                  size: 15, color: AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This changes the symbol and number formatting only. Existing '
                  'amounts keep their value — SaveWise has no exchange rates '
                  'because it never goes online.',
                  style: AppTextStyles.small
                      .copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Use $_symbol $_code',
          onPressed: () async {
            final AppState state = context.read<AppState>();
            final NavigatorState nav = Navigator.of(context);
            await state.updateProfile(
              currencyCode: _code,
              currencySymbol: _symbol,
            );
            nav.pop();
          },
        ),
      ],
    );
  }
}
