import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/budget.dart';
import '../domain/engines/budget_engine.dart';
import '../domain/engines/emergency_fund_engine.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/inputs.dart';

/// First launch.
///
/// Four questions, no account. Two of them are optional. This screen is the
/// entire cost of entry to the app, which is the point — the brief rules out
/// registration, verification, OTPs and passwords, so the only thing standing
/// between install and use is a salary figure.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final PageController _pages = PageController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _salary = TextEditingController();

  int _step = 0;
  int _salaryDay = 1;
  double _savingsRate = AppConstants.targetSavingsRate;
  String _code = 'USD';
  String _symbol = r'$';
  String _localeTag = 'en_US';
  bool _localeResolved = false;
  bool _saving = false;

  static const List<_Currency> _currencies = <_Currency>[
    _Currency('USD', r'$'),
    _Currency('EUR', '€'),
    _Currency('GBP', '£'),
    _Currency('INR', '₹'),
    _Currency('JPY', '¥'),
    _Currency('AUD', r'A$'),
    _Currency('CAD', r'C$'),
    _Currency('AED', 'AED'),
    _Currency('SGD', r'S$'),
    _Currency('ZAR', 'R'),
    _Currency('BRL', r'R$'),
    _Currency('NGN', '₦'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localeResolved) return;
    // The device already knows where it is. Asking the user to pick a currency
    // from a list of 150 when the phone can answer is busywork.
    final Locale locale = Localizations.localeOf(context);
    _localeTag = Money.deviceLocaleTag(locale.languageCode, locale.countryCode);
    final (String code, String symbol) = Money.resolveForLocale(_localeTag);
    _code = code;
    _symbol = symbol;
    Money.configure(
      localeTag: _localeTag,
      currencyCode: _code,
      currencySymbol: _symbol,
    );
    Dates.configure(_localeTag);
    _localeResolved = true;
  }

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    _salary.dispose();
    super.dispose();
  }

  double get _salaryValue => Money.parse(_salary.text) ?? 0;

  void _go(int step) {
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    await context.read<AppState>().completeSetup(
          name: _name.text.trim(),
          monthlySalary: _salaryValue,
          salaryDay: _salaryDay,
          currencyCode: _code,
          currencySymbol: _symbol,
          localeTag: _localeTag,
          savingsRateTarget: _savingsRate,
        );
    // No setState afterwards: AppState flips isSetupComplete and the root
    // swaps this screen out from under us.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 16, AppTheme.gutter, 8),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < 3; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 3,
                        margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? AppColors.emerald
                              : AppColors.hairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  _welcomePage(),
                  _detailsPage(),
                  _planPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter, 24, AppTheme.gutter, 32),
      children: <Widget>[
        Reveal(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.emeraldSweep,
              borderRadius: BorderRadius.circular(22),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.emerald.withValues(alpha: 0.28),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.savings_rounded,
              size: 34,
              color: AppColors.textOnAccent,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Reveal(
          delayMs: 60,
          child: Text(
            'Welcome to ${AppConstants.appName}',
            style: AppTextStyles.moneyLarge.copyWith(fontSize: 30, height: 1.15),
          ),
        ),
        const SizedBox(height: 8),
        Reveal(
          delayMs: 110,
          child: Text(
            AppConstants.tagline,
            style: AppTextStyles.body.copyWith(color: AppColors.emeraldSoft),
          ),
        ),
        const SizedBox(height: 28),
        Reveal(
          delayMs: 160,
          child: const _Promise(
            icon: Icons.person_off_outlined,
            title: 'No account, ever',
            detail:
                'No sign-up, no email, no OTP, no password. You are already in.',
          ),
        ),
        Reveal(
          delayMs: 210,
          child: const _Promise(
            icon: Icons.wifi_off_rounded,
            title: 'Works with no internet',
            detail:
                'Every number, chart and piece of advice is calculated on this device.',
          ),
        ),
        Reveal(
          delayMs: 260,
          child: const _Promise(
            icon: Icons.lock_outline_rounded,
            title: 'Your data never leaves',
            detail:
                'Nothing is uploaded to a server. Clearing the app clears everything.',
          ),
        ),
        const SizedBox(height: 30),
        Reveal(
          delayMs: 320,
          child: PrimaryButton(
            label: 'Set up in 30 seconds',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _go(1),
          ),
        ),
      ],
    );
  }

  Widget _detailsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter, 18, AppTheme.gutter, 32),
      children: <Widget>[
        Text('A few numbers', style: AppTextStyles.screenTitle),
        const SizedBox(height: 6),
        Text(
          'Only the salary is required. Everything else can change later.',
          style: AppTextStyles.small,
        ),
        const SizedBox(height: 24),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextInputBox(
                controller: _name,
                label: 'Your name (optional)',
                hintText: 'What should I call you?',
                prefixIcon: Icons.person_outline_rounded,
                maxLength: 24,
              ),
              const SizedBox(height: 20),
              AmountField(
                controller: _salary,
                label: 'Monthly salary',
                helper: 'Take-home pay, after tax and deductions.',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              DayOfMonthField(
                label: 'Salary credit date',
                day: _salaryDay,
                helper:
                    'Budgets run from payday to payday, not from the 1st.',
                onChanged: (int day) => setState(() => _salaryDay = day),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LabeledField(
                label: 'Currency',
                hint: 'Detected from your device settings.',
                trailing: Text(
                  '$_symbol  $_code',
                  style: AppTextStyles.numericSmall
                      .copyWith(color: AppColors.brass),
                ),
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      for (final _Currency c in _sortedCurrencies())
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: PillButton(
                            label: '${c.symbol} ${c.code}',
                            selected: c.code == _code,
                            accent: AppColors.brass,
                            onTap: () => setState(() {
                              _code = c.code;
                              _symbol = c.symbol;
                              Money.configure(
                                localeTag: _localeTag,
                                currencyCode: _code,
                                currencySymbol: _symbol,
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              RateSlider(
                label: 'Savings target',
                value: _savingsRate,
                min: 0.05,
                max: 0.5,
                divisions: 9,
                helper: _savingsRate >= 0.2
                    ? 'A healthy target. 20% is the benchmark the score uses.'
                    : 'Below the 20% benchmark — fine to start here and raise it.',
                onChanged: (double v) => setState(() => _savingsRate = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        PrimaryButton(
          label: 'Build my plan',
          icon: Icons.auto_awesome_rounded,
          onPressed: _salaryValue > 0 ? () => _go(2) : null,
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => _go(0),
            child: const Text('Back'),
          ),
        ),
      ],
    );
  }

  Widget _planPage() {
    final double salary = _salaryValue;
    final MonthlyBudget budget = BudgetEngine.suggest(
      monthKey: Dates.monthKey(DateTime.now()),
      salary: salary,
      savingsRate: _savingsRate,
    );
    final EmergencyPlan fund = EmergencyFundEngine.plan(
      balance: 0,
      essentialsMonthly: BudgetEngine.essentialsMonthly(budget),
      monthlySalary: salary,
    );
    final double monthlySavings = budget.plannedSavings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter, 18, AppTheme.gutter, 32),
      children: <Widget>[
        Text('Your starting plan', style: AppTextStyles.screenTitle),
        const SizedBox(height: 6),
        Text(
          _name.text.trim().isEmpty
              ? 'Generated from your salary. Adjust anything you like later.'
              : 'Built for you, ${_name.text.trim()}. Adjust anything later.',
          style: AppTextStyles.small,
        ),
        const SizedBox(height: 20),
        GlassCard(
          accent: AppColors.emerald,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('MONTHLY BUDGET', style: AppTextStyles.label),
              const SizedBox(height: 14),
              for (final BudgetCategory c in BudgetCategory.values)
                if (c != BudgetCategory.savings)
                  KeyValueRow(
                    label: c.label,
                    value: Money.format(budget.limitFor(c)),
                    icon: c.icon,
                    dense: true,
                  ),
              const Divider(height: 22),
              KeyValueRow(
                label: 'Savings',
                value: Money.format(monthlySavings),
                icon: BudgetCategory.savings.icon,
                valueColor: AppColors.emerald,
                strong: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: GlassCard(
                child: StatTile(
                  label: 'Save monthly',
                  value: Money.format(monthlySavings),
                  footnote: '${Money.percent(_savingsRate)} of salary',
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
                  label: 'Emergency goal',
                  value: Money.format(fund.idealTarget),
                  footnote:
                      '${AppConstants.emergencyIdealMonths} months of essentials',
                  icon: Icons.health_and_safety_outlined,
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
              Row(
                children: <Widget>[
                  const Icon(Icons.insights_rounded,
                      size: 16, color: AppColors.brass),
                  const SizedBox(width: 8),
                  Text('What happens next', style: AppTextStyles.cardTitle),
                ],
              ),
              const SizedBox(height: 12),
              const _Bullet(
                  text:
                      'Your health score starts low and climbs as you log savings and stay inside the budget.'),
              _Bullet(
                  text:
                      'Put ${Money.format(fund.suggestedMonthly)} a month aside and the emergency fund reaches its minimum in a year.'),
              const _Bullet(
                  text:
                      'A new money challenge appears every day. Streaks earn coins and badges.'),
            ],
          ),
        ),
        const SizedBox(height: 26),
        PrimaryButton(
          label: 'Start using ${AppConstants.appName}',
          icon: Icons.check_rounded,
          busy: _saving,
          onPressed: _finish,
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _saving ? null : () => _go(1),
            child: const Text('Change my numbers'),
          ),
        ),
      ],
    );
  }

  /// Device currency first — it is the one most likely to be right.
  List<_Currency> _sortedCurrencies() {
    final List<_Currency> list = List<_Currency>.of(_currencies);
    final int index = list.indexWhere((_Currency c) => c.code == _code);
    if (index >= 0) {
      final _Currency found = list.removeAt(index);
      list.insert(0, found);
    } else {
      list.insert(0, _Currency(_code, _symbol));
    }
    return list;
  }
}

class _Currency {
  const _Currency(this.code, this.symbol);

  final String code;
  final String symbol;
}

class _Promise extends StatelessWidget {
  const _Promise({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.slateHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Icon(icon, size: 17, color: AppColors.emeraldSoft),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 2),
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 3),
                Text(detail, style: AppTextStyles.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: const BoxDecoration(
              color: AppColors.emerald,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Text(text, style: AppTextStyles.small)),
        ],
      ),
    );
  }
}
