import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';

import '../core/constants/achievement_catalog.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import '../data/models/achievement.dart';
import '../data/models/bill.dart';
import '../data/models/budget.dart';
import '../data/models/challenge.dart';
import '../data/models/emergency_fund.dart';
import '../data/models/expense.dart';
import '../data/models/goal.dart';
import '../data/models/monthly_snapshot.dart';
import '../data/models/savings_challenge.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/finance_repository.dart';
import '../domain/engines/achievement_engine.dart';
import '../domain/engines/advisor_engine.dart';
import '../domain/engines/budget_engine.dart';
import '../domain/engines/challenge_engine.dart';
import '../domain/engines/emergency_fund_engine.dart';
import '../domain/engines/goal_engine.dart';
import '../domain/engines/health_score_engine.dart';
import '../domain/engines/pay_cycle.dart';
import '../domain/engines/reminder_engine.dart';

/// The whole application, in one object.
///
/// Everything the screens read is either stored data or a derived value
/// recomputed here after each change. Nothing is fetched, nothing is uploaded:
/// the repository writes to the device's own storage and that is the only
/// destination that exists.
class AppState extends ChangeNotifier {
  AppState(this._repo) {
    _recompute();
  }

  final FinanceRepository _repo;

  // ------------------------------------------------------------ stored state

  UserProfile _profile = blankProfile();
  Map<String, MonthlyBudget> _budgets = <String, MonthlyBudget>{};
  List<Expense> _expenses = <Expense>[];
  List<Goal> _goals = <Goal>[];
  EmergencyFund _fund = const EmergencyFund();
  List<Bill> _bills = <Bill>[];
  Map<String, DailyChallenge> _daily = <String, DailyChallenge>{};
  List<SavingsChallenge> _savingsChallenges = <SavingsChallenge>[];
  List<UnlockedAchievement> _achievements = <UnlockedAchievement>[];
  List<MonthlySnapshot> _snapshots = <MonthlySnapshot>[];

  // ----------------------------------------------------------- derived state

  late PayCycle _cycle;
  late String _monthKey;
  late BudgetSummary _summary;
  late EmergencyPlan _emergency;
  late HealthScore _score;
  List<GoalPlan> _plans = <GoalPlan>[];
  List<BillReminder> _reminders = <BillReminder>[];

  // -------------------------------------------------------- session-only bits

  final List<ChatMessage> _chat = <ChatMessage>[];
  final List<AchievementDef> _celebrations = <AchievementDef>[];
  final List<String> _flashes = <String>[];

  DateTime _now = DateTime.now();
  Timer? _clock;
  bool _ready = false;
  bool _setupComplete = false;
  int _idSeed = 0;

  // ------------------------------------------------------------------ getters

  bool get ready => _ready;
  bool get isSetupComplete => _setupComplete;
  DateTime get now => _now;

  UserProfile get profile => _profile;
  List<Expense> get expenses => List<Expense>.unmodifiable(_expenses);
  List<Goal> get goals => GoalEngine.sorted(_goals);
  EmergencyFund get fund => _fund;
  List<Bill> get bills => List<Bill>.unmodifiable(_bills);
  List<SavingsChallenge> get savingsChallenges =>
      List<SavingsChallenge>.unmodifiable(_savingsChallenges);
  List<UnlockedAchievement> get achievements =>
      List<UnlockedAchievement>.unmodifiable(_achievements);
  List<MonthlySnapshot> get snapshots =>
      List<MonthlySnapshot>.unmodifiable(_snapshots);
  List<ChatMessage> get chat => List<ChatMessage>.unmodifiable(_chat);

  String get monthKey => _monthKey;
  PayCycle get cycle => _cycle;
  MonthlyBudget get budget =>
      _budgets[_monthKey] ?? MonthlyBudget.empty(_monthKey);
  BudgetSummary get summary => _summary;
  EmergencyPlan get emergency => _emergency;
  HealthScore get score => _score;
  List<GoalPlan> get goalPlans => List<GoalPlan>.unmodifiable(_plans);
  List<BillReminder> get reminders => List<BillReminder>.unmodifiable(_reminders);

  Goal? get activeGoal => GoalEngine.active(_goals);

  GoalPlan? planFor(String goalId) {
    for (final GoalPlan p in _plans) {
      if (p.goal.id == goalId) return p;
    }
    return null;
  }

  /// Today's challenge. Created on demand, so it always exists once ready.
  DailyChallenge? get todayChallenge => _daily[Dates.dayKey(_now)];

  ChallengeProgress? get todayProgress {
    final DailyChallenge? c = todayChallenge;
    if (c == null) return null;
    return ChallengeEngine.progressFor(
      challenge: c,
      expenses: _expenses,
      now: _now,
    );
  }

  /// Challenge history, newest first.
  List<DailyChallenge> get challengeHistory {
    final List<DailyChallenge> list = _daily.values.toList()
      ..sort((DailyChallenge a, DailyChallenge b) =>
          b.dayKey.compareTo(a.dayKey));
    return list;
  }

  List<String> get budgetAlerts => BudgetEngine.alerts(_summary);

  List<String> get reminderMessages => ReminderEngine.messages(_reminders);

  double get monthlyCapacity {
    if (_summary.savingsTarget > 0) return _summary.savingsTarget;
    final double byRate = _profile.monthlySalary * _profile.savingsRateTarget;
    return byRate > 0 ? byRate : 0;
  }

  /// Total ever moved into savings. Read from the savings expense ledger only,
  /// so goal and fund contributions are never counted twice.
  double get lifetimeSaved {
    double sum = 0;
    for (final Expense e in _expenses) {
      if (e.categoryId == BudgetCategory.savings.id) sum += e.amount;
    }
    return sum;
  }

  Map<String, DateTime> get unlockedAt => <String, DateTime>{
        for (final UnlockedAchievement a in _achievements) a.id: a.unlockedAt,
      };

  AchievementInputs get achievementInputs => AchievementInputs(
        monthlySalary: _profile.monthlySalary,
        lifetimeSaved: lifetimeSaved,
        goalsCompleted: GoalEngine.completedCount(_goals),
        emergencyFraction: _emergency.progressToIdeal,
        longestStreak: _profile.longestStreak,
      );

  List<AchievementProgress> get achievementProgress =>
      AchievementEngine.progressList(
        inputs: achievementInputs,
        unlockedAt: unlockedAt,
      );

  AdvisorSnapshot get advisorSnapshot => AdvisorSnapshot(
        profile: _profile,
        budget: _summary,
        emergency: _emergency,
        score: _score,
        goals: _goals,
        plans: _plans,
        bills: _reminders,
        challenge: todayChallenge,
        now: _now,
      );

  List<String> get suggestedQuestions =>
      AdvisorEngine.suggestedQuestions(advisorSnapshot);

  List<String> get insights => AdvisorEngine.insights(advisorSnapshot);

  /// Badges unlocked since the UI last looked. Consumed, so a badge only
  /// celebrates once.
  List<AchievementDef> takeCelebrations() {
    if (_celebrations.isEmpty) return const <AchievementDef>[];
    final List<AchievementDef> out =
        List<AchievementDef>.of(_celebrations, growable: false);
    _celebrations.clear();
    return out;
  }

  /// One-off messages (milestones, payouts) for a snackbar.
  String? takeFlash() {
    if (_flashes.isEmpty) return null;
    return _flashes.removeAt(0);
  }

  // -------------------------------------------------------------- lifecycle

  Future<void> bootstrap() async {
    _now = DateTime.now();

    // Storage is the only thing here that can fail. If a stored record is
    // corrupt, the app still has to open — losing one value is survivable,
    // refusing to start is not.
    try {
      await _repo.init();

      _profile = _repo.loadProfile() ?? blankProfile();
      _applyLocale();

      _budgets = _repo.loadBudgets();
      _expenses = _repo.loadExpenses();
      _goals = _repo.loadGoals();
      _fund = _repo.loadEmergencyFund();
      _bills = _repo.loadBills();
      _daily = _repo.loadDailyChallenges();
      _savingsChallenges = _repo.loadSavingsChallenges();
      _achievements = _repo.loadAchievements();
      _snapshots = _repo.loadSnapshots();

      _setupComplete = _repo.isSetupComplete && _profile.monthlySalary > 0;

      final UserProfile trimmed =
          ChallengeEngine.resetStaleStreak(_profile, _now);
      if (trimmed.streak != _profile.streak) {
        _profile = trimmed;
        await _repo.saveProfile(_profile);
      }

      if (_setupComplete) {
        await _rollMonthIfNeeded();
        await _ensureTodayChallenge();
        await _autoResolveChallenges();
      }
    } catch (error, stack) {
      debugPrint('SaveWise: recovered from a storage error — $error');
      debugPrintStack(stackTrace: stack);
    }

    _recompute();
    if (_setupComplete && _chat.isEmpty) _seedChat();
    await _syncAchievements();

    _ready = true;
    _startClock();
    notifyListeners();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// A blank profile in the device's own currency and locale, so the very first
  /// screen already speaks the user's language without asking.
  static UserProfile blankProfile() {
    final Locale locale = PlatformDispatcher.instance.locale;
    final String tag =
        Money.deviceLocaleTag(locale.languageCode, locale.countryCode);
    final (String code, String symbol) = Money.resolveForLocale(tag);
    return UserProfile(
      name: '',
      monthlySalary: 0,
      salaryDay: 1,
      currencyCode: code,
      currencySymbol: symbol,
      localeTag: tag,
      createdAt: DateTime.now(),
    );
  }

  void _applyLocale() {
    Money.configure(
      localeTag: _profile.localeTag,
      currencyCode: _profile.currencyCode,
      currencySymbol: _profile.currencySymbol,
    );
    Dates.configure(_profile.localeTag);
  }

  /// One tick a second. The clock field is updated silently — the dashboard's
  /// clock widget repaints itself — and listeners are only told when the day
  /// turns over, which is the only thing that changes the numbers.
  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      final DateTime next = DateTime.now();
      final bool newDay = Dates.dayKey(next) != Dates.dayKey(_now);
      _now = next;
      if (newDay) _onNewDay();
    });
  }

  Future<void> _onNewDay() async {
    if (!_setupComplete) return;
    _profile = ChallengeEngine.resetStaleStreak(_profile, _now);
    await _repo.saveProfile(_profile);
    await _autoResolveChallenges();
    await _rollMonthIfNeeded();
    await _ensureTodayChallenge();
    _recompute();
    await _syncAchievements();
    notifyListeners();
  }

  void _recompute() {
    _cycle = PayCycle.forDate(_now, _profile.salaryDay);
    _monthKey = Dates.monthKey(_now);

    final MonthlyBudget current =
        _budgets[_monthKey] ?? MonthlyBudget.empty(_monthKey);

    _summary = BudgetEngine.summarise(
      budget: current,
      expenses: _expenses,
      cycle: _cycle,
      income: _profile.monthlySalary,
    );

    _emergency = EmergencyFundEngine.plan(
      balance: _fund.balance,
      essentialsMonthly: BudgetEngine.essentialsMonthly(current),
      monthlySalary: _profile.monthlySalary,
    );

    _score = HealthScoreEngine.evaluate(
      profile: _profile,
      summary: _summary,
      emergency: _emergency,
      goals: _goals,
      now: _now,
    );

    final double capacity = _summary.savingsTarget > 0
        ? _summary.savingsTarget
        : _profile.monthlySalary * _profile.savingsRateTarget;
    final Map<String, double> allocation = GoalEngine.allocate(
      goals: _goals,
      monthlyCapacity: capacity,
    );

    _plans = <GoalPlan>[
      for (final Goal g in GoalEngine.sorted(_goals))
        GoalEngine.plan(
          goal: g,
          now: _now,
          allocatedMonthly: allocation[g.id] ?? 0,
        ),
    ];

    _reminders = ReminderEngine.build(bills: _bills, now: _now);
  }

  Future<void> _settle() async {
    _recompute();
    await _syncAchievements();
    notifyListeners();
  }

  String _newId() {
    _idSeed++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idSeed';
  }

  // ------------------------------------------------------------------- setup

  Future<void> completeSetup({
    required String name,
    required double monthlySalary,
    required int salaryDay,
    required String currencyCode,
    required String currencySymbol,
    required String localeTag,
    double savingsRateTarget = AppConstants.targetSavingsRate,
  }) async {
    _now = DateTime.now();
    _profile = UserProfile(
      name: name.trim(),
      monthlySalary: monthlySalary,
      salaryDay: salaryDay < 1 ? 1 : (salaryDay > 31 ? 31 : salaryDay),
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      localeTag: localeTag,
      createdAt: _now,
      savingsRateTarget: savingsRateTarget,
    );
    _applyLocale();

    final String key = Dates.monthKey(_now);
    _budgets = <String, MonthlyBudget>{
      key: BudgetEngine.suggest(
        monthKey: key,
        salary: monthlySalary,
        savingsRate: savingsRateTarget,
      ),
    };

    await _repo.saveProfile(_profile);
    await _repo.saveBudgets(_budgets);
    await _repo.setLastOpenedMonth(key);
    await _repo.markSetupComplete();
    _setupComplete = true;

    await _ensureTodayChallenge();
    _recompute();
    _chat.clear();
    _seedChat();
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    double? monthlySalary,
    int? salaryDay,
    double? savingsRateTarget,
    String? currencyCode,
    String? currencySymbol,
    String? localeTag,
  }) async {
    _profile = _profile.copyWith(
      name: name?.trim(),
      monthlySalary: monthlySalary,
      salaryDay: salaryDay,
      savingsRateTarget: savingsRateTarget,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      localeTag: localeTag,
    );
    if (currencyCode != null || currencySymbol != null || localeTag != null) {
      _applyLocale();
    }
    await _repo.saveProfile(_profile);
    await _settle();
  }

  // ------------------------------------------------------------------ budget

  /// Rebuild this month's plan from the salary, discarding manual edits.
  Future<void> regenerateBudget() async {
    _budgets[_monthKey] = BudgetEngine.suggest(
      monthKey: _monthKey,
      salary: _profile.monthlySalary,
      savingsRate: _profile.savingsRateTarget,
    );
    await _repo.saveBudgets(_budgets);
    _flashes.add('Plan rebuilt from your salary.');
    await _settle();
  }

  Future<void> setLimit(BudgetCategory category, double value) async {
    final MonthlyBudget current =
        _budgets[_monthKey] ?? MonthlyBudget.empty(_monthKey);
    _budgets[_monthKey] = current.withLimit(category, value < 0 ? 0 : value);
    await _repo.saveBudgets(_budgets);
    await _settle();
  }

  Future<void> setLimits(Map<BudgetCategory, double> limits) async {
    MonthlyBudget current =
        _budgets[_monthKey] ?? MonthlyBudget.empty(_monthKey);
    for (final MapEntry<BudgetCategory, double> e in limits.entries) {
      current = current.withLimit(e.key, e.value < 0 ? 0 : e.value);
    }
    _budgets[_monthKey] = current;
    await _repo.saveBudgets(_budgets);
    await _settle();
  }

  // ---------------------------------------------------------------- expenses

  Future<void> addExpense({
    required BudgetCategory category,
    required double amount,
    DateTime? date,
    String note = '',
  }) async {
    if (amount <= 0) return;
    _expenses = <Expense>[
      ..._expenses,
      Expense(
        id: _newId(),
        categoryId: category.id,
        amount: amount,
        date: date ?? _now,
        note: note.trim(),
      ),
    ];
    await _repo.saveExpenses(_expenses);
    await _autoResolveChallenges();
    await _settle();
  }

  Future<void> deleteExpense(String id) async {
    _expenses = _expenses
        .where((Expense e) => e.id != id)
        .toList(growable: false);
    await _repo.saveExpenses(_expenses);
    await _settle();
  }

  /// Expenses inside the current pay cycle, newest first.
  List<Expense> get cycleExpenses {
    final List<Expense> list = _expenses
        .where((Expense e) => _cycle.contains(e.date))
        .toList()
      ..sort((Expense a, Expense b) => b.date.compareTo(a.date));
    return list;
  }

  List<Expense> expensesForCategory(BudgetCategory category) => cycleExpenses
      .where((Expense e) => e.categoryId == category.id)
      .toList(growable: false);

  // ------------------------------------------------------------------- goals

  Future<Goal> addGoal({
    required String name,
    required double cost,
    required DateTime targetDate,
    GoalPriority priority = GoalPriority.medium,
    String note = '',
  }) async {
    final Goal goal = Goal(
      id: _newId(),
      name: name.trim().isEmpty ? 'New goal' : name.trim(),
      cost: cost,
      saved: 0,
      targetDate: targetDate,
      createdAt: _now,
      priority: priority,
      note: note.trim(),
    );
    _goals = <Goal>[..._goals, goal];
    await _repo.saveGoals(_goals);
    await _settle();
    return goal;
  }

  Future<void> updateGoal(Goal goal) async {
    _goals = _goals
        .map((Goal g) => g.id == goal.id ? goal : g)
        .toList(growable: false);
    await _repo.saveGoals(_goals);
    await _settle();
  }

  Future<void> deleteGoal(String id) async {
    _goals = _goals.where((Goal g) => g.id != id).toList(growable: false);
    await _repo.saveGoals(_goals);
    await _settle();
  }

  Goal? goalById(String id) {
    for (final Goal g in _goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Put money into a goal. Also logged as a savings expense so the budget,
  /// the health score and the achievements all see the same single truth.
  Future<void> contributeToGoal({
    required String goalId,
    required double amount,
    bool logAsSavings = true,
  }) async {
    if (amount <= 0) return;
    final Goal? existing = goalById(goalId);
    if (existing == null) return;

    final Goal updated = existing.copyWith(
      saved: existing.saved + amount,
    );
    final List<int> crossed = GoalEngine.newMilestones(existing, updated);
    final bool justFinished = !existing.isComplete && updated.isComplete;

    Goal finished = updated.copyWith(
      milestonesUnlocked: <int>[...updated.milestonesUnlocked, ...crossed],
    );
    if (justFinished) {
      finished = finished.copyWith(completedAt: _now);
    }

    _goals = _goals
        .map((Goal g) => g.id == goalId ? finished : g)
        .toList(growable: false);
    await _repo.saveGoals(_goals);

    if (logAsSavings) {
      _expenses = <Expense>[
        ..._expenses,
        Expense(
          id: _newId(),
          categoryId: BudgetCategory.savings.id,
          amount: amount,
          date: _now,
          note: existing.name,
        ),
      ];
      await _repo.saveExpenses(_expenses);
    }

    if (justFinished) {
      _flashes.add('${finished.name} is fully funded. Go and get it.');
    } else if (crossed.isNotEmpty) {
      _flashes.add('${crossed.last}% of ${finished.name} saved.');
    }

    await _settle();
  }

  Future<void> withdrawFromGoal({
    required String goalId,
    required double amount,
  }) async {
    if (amount <= 0) return;
    final Goal? existing = goalById(goalId);
    if (existing == null) return;
    final double next = existing.saved - amount;
    _goals = _goals
        .map((Goal g) => g.id == goalId
            ? g.copyWith(saved: next < 0 ? 0 : next, clearCompletedAt: true)
            : g)
        .toList(growable: false);
    await _repo.saveGoals(_goals);
    await _settle();
  }

  // ---------------------------------------------------------- emergency fund

  Future<void> addToEmergencyFund({
    required double amount,
    String note = '',
    bool logAsSavings = true,
  }) async {
    if (amount <= 0) return;
    _fund = _fund.copyWith(
      entries: <FundEntry>[
        ..._fund.entries,
        FundEntry(id: _newId(), amount: amount, date: _now, note: note.trim()),
      ],
    );
    await _repo.saveEmergencyFund(_fund);

    if (logAsSavings) {
      _expenses = <Expense>[
        ..._expenses,
        Expense(
          id: _newId(),
          categoryId: BudgetCategory.savings.id,
          amount: amount,
          date: _now,
          note: 'Emergency fund',
        ),
      ];
      await _repo.saveExpenses(_expenses);
    }

    final bool hadMinimum = _emergency.hasMinimum;
    await _settle();
    if (!hadMinimum && _emergency.hasMinimum) {
      _flashes.add('Three months of essentials covered. That is the floor '
          'most people never reach.');
      notifyListeners();
    }
  }

  Future<void> withdrawFromEmergencyFund({
    required double amount,
    String note = '',
  }) async {
    if (amount <= 0) return;
    _fund = _fund.copyWith(
      entries: <FundEntry>[
        ..._fund.entries,
        FundEntry(
          id: _newId(),
          amount: -amount,
          date: _now,
          note: note.trim().isEmpty ? 'Withdrawal' : note.trim(),
        ),
      ],
    );
    await _repo.saveEmergencyFund(_fund);
    await _settle();
  }

  Future<void> deleteFundEntry(String id) async {
    _fund = _fund.copyWith(
      entries: _fund.entries
          .where((FundEntry e) => e.id != id)
          .toList(growable: false),
    );
    await _repo.saveEmergencyFund(_fund);
    await _settle();
  }

  // ------------------------------------------------------------------- bills

  Future<void> addBill({
    required String name,
    required String type,
    required double amount,
    required int dueDay,
    bool recurring = true,
    DateTime? oneOffDate,
    bool autoLogAsExpense = true,
  }) async {
    _bills = <Bill>[
      ..._bills,
      Bill(
        id: _newId(),
        name: name.trim().isEmpty ? type : name.trim(),
        type: type,
        amount: amount,
        dueDay: dueDay < 1 ? 1 : (dueDay > 31 ? 31 : dueDay),
        recurring: recurring,
        oneOffDate: oneOffDate,
        autoLogAsExpense: autoLogAsExpense,
      ),
    ];
    await _repo.saveBills(_bills);
    await _settle();
  }

  Future<void> updateBill(Bill bill) async {
    _bills = _bills
        .map((Bill b) => b.id == bill.id ? bill : b)
        .toList(growable: false);
    await _repo.saveBills(_bills);
    await _settle();
  }

  Future<void> deleteBill(String id) async {
    _bills = _bills.where((Bill b) => b.id != id).toList(growable: false);
    await _repo.saveBills(_bills);
    await _settle();
  }

  Future<void> payBill(String id) async {
    Bill? target;
    for (final Bill b in _bills) {
      if (b.id == id) target = b;
    }
    if (target == null) return;

    final Bill paid = ReminderEngine.markPaid(target, _now);
    _bills = _bills
        .map((Bill b) => b.id == id ? paid : b)
        .toList(growable: false);
    await _repo.saveBills(_bills);

    if (target.autoLogAsExpense) {
      _expenses = <Expense>[
        ..._expenses,
        Expense(
          id: _newId(),
          categoryId: BudgetCategory.other.id,
          amount: target.amount,
          date: _now,
          note: target.name,
        ),
      ];
      await _repo.saveExpenses(_expenses);
    }
    await _settle();
  }

  Future<void> unpayBill(String id) async {
    _bills = _bills
        .map((Bill b) => b.id == id ? ReminderEngine.markUnpaid(b, _now) : b)
        .toList(growable: false);
    await _repo.saveBills(_bills);
    await _settle();
  }

  // -------------------------------------------------------- daily challenges

  Future<void> _ensureTodayChallenge() async {
    final String key = Dates.dayKey(_now);
    if (_daily.containsKey(key)) return;

    final String yesterday =
        Dates.dayKey(_now.subtract(const Duration(days: 1)));
    _daily[key] = ChallengeEngine.forDay(
      day: _now,
      profile: _profile,
      previousTemplateId: _daily[yesterday]?.templateId,
    );
    await _repo.saveDailyChallenges(_daily);
  }

  /// Grade every pending challenge the app can grade on its own. Habits are
  /// left alone on purpose — only the user knows whether they cooked.
  Future<void> _autoResolveChallenges() async {
    bool changed = false;
    for (final String key in _daily.keys.toList(growable: false)) {
      final DailyChallenge c = _daily[key]!;
      final DailyChallenge? resolved = ChallengeEngine.autoResolve(
        challenge: c,
        expenses: _expenses,
        now: _now,
      );
      if (resolved == null) continue;
      _daily[key] = resolved;
      changed = true;
      if (resolved.isCompleted) {
        _profile = ChallengeEngine.award(profile: _profile, challenge: resolved);
      }
    }
    if (changed) {
      await _repo.saveDailyChallenges(_daily);
      await _repo.saveProfile(_profile);
    }
  }

  /// Mark today's challenge done. Used by habit challenges, which cannot be
  /// graded from the expense ledger.
  Future<void> completeChallenge() async {
    final String key = Dates.dayKey(_now);
    final DailyChallenge? c = _daily[key];
    if (c == null || !c.isPending) return;

    final DailyChallenge done = c.copyWith(status: ChallengeStatus.completed);
    _daily[key] = done;
    final int beforeCoins = _profile.coins;
    _profile = ChallengeEngine.award(profile: _profile, challenge: done);

    await _repo.saveDailyChallenges(_daily);
    await _repo.saveProfile(_profile);

    final int gained = _profile.coins - beforeCoins;
    if (gained > 0) {
      _flashes.add('+$gained coins, +${done.xp} XP. '
          'Streak: ${_profile.streak} '
          '${_profile.streak == 1 ? 'day' : 'days'}.');
    }
    await _settle();
  }

  Future<void> skipChallenge() async {
    final String key = Dates.dayKey(_now);
    final DailyChallenge? c = _daily[key];
    if (c == null || !c.isPending) return;
    _daily[key] = c.copyWith(status: ChallengeStatus.skipped);
    await _repo.saveDailyChallenges(_daily);
    await _settle();
  }

  // ------------------------------------------------------ savings challenges

  Future<void> startSavingsChallenge({
    required SavingsChallengeType type,
    required double baseAmount,
  }) async {
    _savingsChallenges = <SavingsChallenge>[
      ..._savingsChallenges,
      SavingsChallenge(
        id: _newId(),
        type: type,
        startDate: Dates.dateOnly(_now),
        baseAmount: baseAmount,
      ),
    ];
    await _repo.saveSavingsChallenges(_savingsChallenges);
    await _settle();
  }

  /// Tick a step off, or untick it. The money it represents is logged as
  /// savings, so a challenge actually moves the score.
  Future<void> toggleSavingsStep({
    required String challengeId,
    required int step,
  }) async {
    SavingsChallenge? target;
    for (final SavingsChallenge c in _savingsChallenges) {
      if (c.id == challengeId) target = c;
    }
    if (target == null) return;

    final bool wasDone = target.completedSteps.contains(step);
    final List<int> next = wasDone
        ? target.completedSteps.where((int s) => s != step).toList()
        : <int>[...target.completedSteps, step];

    SavingsChallenge updated = target.copyWith(completedSteps: next);
    if (updated.isFinished && target.completedAt == null) {
      updated = updated.copyWith(completedAt: _now, active: false);
      _flashes.add('${target.type.label} finished — '
          '${Money.format(updated.totalSaved)} saved.');
    } else if (!updated.isFinished && target.completedAt != null) {
      updated = updated.copyWith(clearCompletedAt: true, active: true);
    }

    _savingsChallenges = _savingsChallenges
        .map((SavingsChallenge c) => c.id == challengeId ? updated : c)
        .toList(growable: false);
    await _repo.saveSavingsChallenges(_savingsChallenges);

    final double amount = target.amountForStep(step);
    if (!wasDone && amount > 0) {
      _expenses = <Expense>[
        ..._expenses,
        Expense(
          id: _newId(),
          categoryId: BudgetCategory.savings.id,
          amount: amount,
          date: _now,
          note: target.type.label,
        ),
      ];
      await _repo.saveExpenses(_expenses);
    }
    await _settle();
  }

  Future<void> endSavingsChallenge(String id) async {
    _savingsChallenges = _savingsChallenges
        .where((SavingsChallenge c) => c.id != id)
        .toList(growable: false);
    await _repo.saveSavingsChallenges(_savingsChallenges);
    await _settle();
  }

  // ----------------------------------------------------------------- advisor

  void _seedChat() {
    _chat.add(AdvisorEngine.greeting(advisorSnapshot));
  }

  void ask(String question) {
    final String text = question.trim();
    if (text.isEmpty) return;
    _chat.add(AdvisorEngine.userMessage(text, _now));
    _chat.add(AdvisorEngine.answer(text, advisorSnapshot));
    notifyListeners();
  }

  void resetChat() {
    _chat.clear();
    _seedChat();
    notifyListeners();
  }

  // -------------------------------------------------------------- month roll

  /// Freeze the month that just ended and open a plan for the new one.
  Future<void> _rollMonthIfNeeded() async {
    final String key = Dates.monthKey(_now);
    final String? last = _repo.lastOpenedMonth;

    if (last != null && last.isNotEmpty && last != key) {
      final bool already =
          _snapshots.any((MonthlySnapshot s) => s.monthKey == last);
      if (!already) {
        _snapshots = <MonthlySnapshot>[..._snapshots, _snapshotFor(last)];
        if (_snapshots.length > 24) {
          _snapshots = _snapshots.sublist(_snapshots.length - 24);
        }
        await _repo.saveSnapshots(_snapshots);
      }
    }

    if (!_budgets.containsKey(key)) {
      final MonthlyBudget? previous =
          last == null ? null : _budgets[last];
      _budgets[key] = previous != null
          ? BudgetEngine.rollForward(previous: previous, monthKey: key)
          : BudgetEngine.suggest(
              monthKey: key,
              salary: _profile.monthlySalary,
              savingsRate: _profile.savingsRateTarget,
            );
      await _repo.saveBudgets(_budgets);
    }

    if (last != key) await _repo.setLastOpenedMonth(key);
  }

  /// Close out a calendar month from the ledger. The health score is the one
  /// value that cannot be recomputed after the fact, so the score at the time
  /// of writing is what gets recorded.
  MonthlySnapshot _snapshotFor(String monthKey) {
    final DateTime month = Dates.monthFromKey(monthKey);
    double spent = 0;
    double saved = 0;
    for (final Expense e in _expenses) {
      if (e.date.year != month.year || e.date.month != month.month) continue;
      if (e.categoryId == BudgetCategory.savings.id) {
        saved += e.amount;
      } else {
        spent += e.amount;
      }
    }
    return MonthlySnapshot(
      monthKey: monthKey,
      income: _profile.monthlySalary,
      expenses: spent,
      savings: saved,
      healthScore: _score.total,
      emergencyFund: _fund.balance,
      goalProgress: GoalEngine.averageProgress(_goals),
    );
  }

  /// The reports screen's series: closed months plus the month in progress, so
  /// a chart is never empty on a first run.
  List<MonthlySnapshot> get reportSeries {
    final List<MonthlySnapshot> out = <MonthlySnapshot>[
      ..._snapshots.where((MonthlySnapshot s) => s.monthKey != _monthKey),
      _snapshotFor(_monthKey),
    ]..sort((MonthlySnapshot a, MonthlySnapshot b) =>
        a.monthKey.compareTo(b.monthKey));
    if (out.length <= AppConstants.reportMonths) return out;
    return out.sublist(out.length - AppConstants.reportMonths);
  }

  // ------------------------------------------------------------ achievements

  Future<void> _syncAchievements() async {
    final Set<String> already = <String>{
      for (final UnlockedAchievement a in _achievements) a.id,
    };
    final List<AchievementDef> fresh = AchievementEngine.newlyUnlocked(
      inputs: achievementInputs,
      alreadyUnlocked: already,
    );
    if (fresh.isEmpty) return;

    _achievements = <UnlockedAchievement>[
      ..._achievements,
      for (final AchievementDef d in fresh)
        UnlockedAchievement(id: d.id, unlockedAt: _now),
    ];
    _celebrations.addAll(fresh);
    await _repo.saveAchievements(_achievements);
  }

  // -------------------------------------------------------------------- wipe

  /// The only delete button the app needs, because there is no account to
  /// delete. It really does erase everything.
  Future<void> wipeEverything() async {
    await _repo.wipe();
    _profile = blankProfile();
    _applyLocale();
    _budgets = <String, MonthlyBudget>{};
    _expenses = <Expense>[];
    _goals = <Goal>[];
    _fund = const EmergencyFund();
    _bills = <Bill>[];
    _daily = <String, DailyChallenge>{};
    _savingsChallenges = <SavingsChallenge>[];
    _achievements = <UnlockedAchievement>[];
    _snapshots = <MonthlySnapshot>[];
    _chat.clear();
    _celebrations.clear();
    _flashes.clear();
    _setupComplete = false;
    _recompute();
    notifyListeners();
  }
}
