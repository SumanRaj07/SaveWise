import '../local/local_store.dart';
import '../local/storage_keys.dart';
import '../models/achievement.dart';
import '../models/bill.dart';
import '../models/budget.dart';
import '../models/challenge.dart';
import '../models/emergency_fund.dart';
import '../models/expense.dart';
import '../models/goal.dart';
import '../models/monthly_snapshot.dart';
import '../models/savings_challenge.dart';
import '../models/user_profile.dart';

/// Typed façade over [LocalStore]. Screens never see JSON; state never sees
/// storage keys.
class FinanceRepository {
  FinanceRepository(this._store);

  final LocalStore _store;

  Future<void> init() => _store.init();

  // ---- setup ----

  bool get isSetupComplete => _store.getBool(StorageKeys.setupComplete);

  Future<void> markSetupComplete() =>
      _store.setBool(StorageKeys.setupComplete, true);

  String? get lastOpenedMonth => _store.getString(StorageKeys.lastOpenedMonth);

  Future<void> setLastOpenedMonth(String monthKey) =>
      _store.setString(StorageKeys.lastOpenedMonth, monthKey);

  // ---- profile ----

  UserProfile? loadProfile() {
    final Map<String, dynamic>? raw = _store.getMap(StorageKeys.profile);
    if (raw == null) return null;
    return UserProfile.fromJson(raw);
  }

  Future<void> saveProfile(UserProfile profile) =>
      _store.setMap(StorageKeys.profile, profile.toJson());

  // ---- budgets, keyed by month ----

  Map<String, MonthlyBudget> loadBudgets() {
    final List<Map<String, dynamic>> raw =
        _store.getMapList(StorageKeys.budgets);
    final Map<String, MonthlyBudget> out = <String, MonthlyBudget>{};
    for (final Map<String, dynamic> item in raw) {
      final MonthlyBudget b = MonthlyBudget.fromJson(item);
      if (b.monthKey.isNotEmpty) out[b.monthKey] = b;
    }
    return out;
  }

  Future<void> saveBudgets(Map<String, MonthlyBudget> budgets) =>
      _store.setMapList(
        StorageKeys.budgets,
        budgets.values
            .map((MonthlyBudget b) => b.toJson())
            .toList(growable: false),
      );

  // ---- expenses ----

  List<Expense> loadExpenses() => _store
      .getMapList(StorageKeys.expenses)
      .map(Expense.fromJson)
      .toList();

  Future<void> saveExpenses(List<Expense> expenses) => _store.setMapList(
        StorageKeys.expenses,
        expenses.map((Expense e) => e.toJson()).toList(growable: false),
      );

  // ---- goals ----

  List<Goal> loadGoals() =>
      _store.getMapList(StorageKeys.goals).map(Goal.fromJson).toList();

  Future<void> saveGoals(List<Goal> goals) => _store.setMapList(
        StorageKeys.goals,
        goals.map((Goal g) => g.toJson()).toList(growable: false),
      );

  // ---- emergency fund ----

  EmergencyFund loadEmergencyFund() {
    final Map<String, dynamic>? raw = _store.getMap(StorageKeys.emergencyFund);
    if (raw == null) return const EmergencyFund();
    return EmergencyFund.fromJson(raw);
  }

  Future<void> saveEmergencyFund(EmergencyFund fund) =>
      _store.setMap(StorageKeys.emergencyFund, fund.toJson());

  // ---- bills ----

  List<Bill> loadBills() =>
      _store.getMapList(StorageKeys.bills).map(Bill.fromJson).toList();

  Future<void> saveBills(List<Bill> bills) => _store.setMapList(
        StorageKeys.bills,
        bills.map((Bill b) => b.toJson()).toList(growable: false),
      );

  // ---- daily challenges, keyed by day ----

  Map<String, DailyChallenge> loadDailyChallenges() {
    final Map<String, DailyChallenge> out = <String, DailyChallenge>{};
    for (final Map<String, dynamic> item
        in _store.getMapList(StorageKeys.dailyChallenges)) {
      final DailyChallenge c = DailyChallenge.fromJson(item);
      if (c.dayKey.isNotEmpty) out[c.dayKey] = c;
    }
    return out;
  }

  Future<void> saveDailyChallenges(Map<String, DailyChallenge> challenges) =>
      _store.setMapList(
        StorageKeys.dailyChallenges,
        challenges.values
            .map((DailyChallenge c) => c.toJson())
            .toList(growable: false),
      );

  // ---- savings challenges ----

  List<SavingsChallenge> loadSavingsChallenges() => _store
      .getMapList(StorageKeys.savingsChallenges)
      .map(SavingsChallenge.fromJson)
      .toList();

  Future<void> saveSavingsChallenges(List<SavingsChallenge> challenges) =>
      _store.setMapList(
        StorageKeys.savingsChallenges,
        challenges
            .map((SavingsChallenge c) => c.toJson())
            .toList(growable: false),
      );

  // ---- achievements ----

  List<UnlockedAchievement> loadAchievements() => _store
      .getMapList(StorageKeys.achievements)
      .map(UnlockedAchievement.fromJson)
      .toList();

  Future<void> saveAchievements(List<UnlockedAchievement> unlocked) =>
      _store.setMapList(
        StorageKeys.achievements,
        unlocked
            .map((UnlockedAchievement a) => a.toJson())
            .toList(growable: false),
      );

  // ---- monthly snapshots ----

  List<MonthlySnapshot> loadSnapshots() => _store
      .getMapList(StorageKeys.snapshots)
      .map(MonthlySnapshot.fromJson)
      .toList();

  Future<void> saveSnapshots(List<MonthlySnapshot> snapshots) =>
      _store.setMapList(
        StorageKeys.snapshots,
        snapshots
            .map((MonthlySnapshot s) => s.toJson())
            .toList(growable: false),
      );

  /// Erase everything. Offered in the profile screen: with no account to
  /// delete, this is the user's only delete button, so it has to actually work.
  Future<void> wipe() => _store.wipe();
}
