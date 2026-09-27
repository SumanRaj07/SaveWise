import '../../core/constants/app_constants.dart';
import '../../core/utils/json.dart';

/// One month's spending plan. Budgets are per-month so history stays honest
/// when someone raises a limit — last month's report still shows the limit that
/// was actually in force.
class MonthlyBudget {
  const MonthlyBudget({required this.monthKey, required this.limits});

  final String monthKey;

  /// categoryId → limit for the month.
  final Map<String, double> limits;

  double limitFor(BudgetCategory category) => limits[category.id] ?? 0;

  /// Total planned outgoings *excluding* savings, because savings is not a
  /// spend. Budget utilisation compares real spending against this.
  double get spendableTotal {
    double sum = 0;
    for (final BudgetCategory c in BudgetCategory.values) {
      if (c == BudgetCategory.savings) continue;
      sum += limitFor(c);
    }
    return sum;
  }

  double get plannedSavings => limitFor(BudgetCategory.savings);

  double get total => spendableTotal + plannedSavings;

  MonthlyBudget withLimit(BudgetCategory category, double value) {
    final Map<String, double> next = Map<String, double>.of(limits);
    next[category.id] = value < 0 ? 0 : value;
    return MonthlyBudget(monthKey: monthKey, limits: next);
  }

  MonthlyBudget copyWith({String? monthKey, Map<String, double>? limits}) =>
      MonthlyBudget(
        monthKey: monthKey ?? this.monthKey,
        limits: limits ?? this.limits,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'monthKey': monthKey,
        'limits': limits,
      };

  factory MonthlyBudget.fromJson(Map<String, dynamic> json) => MonthlyBudget(
        monthKey: J.asString(json['monthKey']),
        limits: J.asDoubleMap(json['limits']),
      );

  factory MonthlyBudget.empty(String monthKey) => MonthlyBudget(
        monthKey: monthKey,
        limits: <String, double>{
          for (final BudgetCategory c in BudgetCategory.values) c.id: 0,
        },
      );
}
