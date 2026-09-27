import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget.dart';
import '../../data/models/expense.dart';
import 'pay_cycle.dart';

enum BudgetStatus { unset, onTrack, watch, over }

extension BudgetStatusX on BudgetStatus {
  String get label => switch (this) {
        BudgetStatus.unset => 'No limit set',
        BudgetStatus.onTrack => 'On track',
        BudgetStatus.watch => 'Watch this',
        BudgetStatus.over => 'Over budget',
      };
}

/// One category's month so far.
class CategoryUsage {
  const CategoryUsage({
    required this.category,
    required this.limit,
    required this.spent,
    required this.expectedByNow,
  });

  final BudgetCategory category;
  final double limit;
  final double spent;

  /// What a steady spender would have used by this point in the cycle.
  final double expectedByNow;

  double get remaining => limit - spent;

  double get utilisation => limit <= 0 ? 0 : spent / limit;

  bool get isOver => limit > 0 && spent > limit;

  double get overspend => math.max(0.0, spent - limit);

  BudgetStatus get status {
    if (limit <= 0) return BudgetStatus.unset;
    if (isOver) return BudgetStatus.over;
    // Ahead of pace by more than 15% of the whole limit is worth flagging.
    if (spent > expectedByNow + limit * 0.15) return BudgetStatus.watch;
    return BudgetStatus.onTrack;
  }
}

/// The whole month at a glance.
class BudgetSummary {
  const BudgetSummary({
    required this.budget,
    required this.usage,
    required this.cycle,
    required this.income,
  });

  final MonthlyBudget budget;
  final List<CategoryUsage> usage;
  final PayCycle cycle;
  final double income;

  CategoryUsage forCategory(BudgetCategory category) => usage.firstWhere(
        (CategoryUsage u) => u.category == category,
        orElse: () => CategoryUsage(
          category: category,
          limit: 0,
          spent: 0,
          expectedByNow: 0,
        ),
      );

  /// Spending only. Savings deposits are tracked separately because putting
  /// money away is not the same as spending it, and mixing them makes the
  /// "budget used" number meaningless.
  double get totalSpent {
    double sum = 0;
    for (final CategoryUsage u in usage) {
      if (u.category == BudgetCategory.savings) continue;
      sum += u.spent;
    }
    return sum;
  }

  double get totalLimit => budget.spendableTotal;

  double get saved => forCategory(BudgetCategory.savings).spent;

  double get savingsTarget => budget.plannedSavings;

  double get remaining => totalLimit - totalSpent;

  double get utilisation => totalLimit <= 0 ? 0 : totalSpent / totalLimit;

  /// What is left of the salary once both spending and saving are counted.
  double get unallocated => income - totalSpent - saved;

  double get savingsRate => income <= 0 ? 0 : saved / income;

  List<CategoryUsage> get overspent =>
      usage.where((CategoryUsage u) => u.isOver).toList();

  List<CategoryUsage> get watchlist =>
      usage.where((CategoryUsage u) => u.status == BudgetStatus.watch).toList();

  double get essentialsSpent {
    double sum = 0;
    for (final CategoryUsage u in usage) {
      if (u.category.isEssential) sum += u.spent;
    }
    return sum;
  }

  double get discretionarySpent {
    double sum = 0;
    for (final CategoryUsage u in usage) {
      if (u.category.isDiscretionary) sum += u.spent;
    }
    return sum;
  }

  /// Safe daily spend for the rest of the cycle.
  double get safeDailySpend {
    if (cycle.daysLeft <= 0) return math.max(0.0, remaining);
    return math.max(0.0, remaining / cycle.daysLeft);
  }

  /// The single biggest category by spend, if there is one.
  CategoryUsage? get largestSpend {
    CategoryUsage? best;
    for (final CategoryUsage u in usage) {
      if (u.category == BudgetCategory.savings) continue;
      if (u.spent <= 0) continue;
      if (best == null || u.spent > best.spent) best = u;
    }
    return best;
  }
}

abstract final class BudgetEngine {
  /// Build a starting plan from a salary.
  ///
  /// This is a decomposed 50/30/20: the savings share is whatever the user
  /// targets, and the rest is split across the other six categories in the
  /// proportions they hold within a standard needs/wants split. Amounts are
  /// rounded to a tidy unit derived from the salary's own magnitude, then the
  /// largest category absorbs the rounding drift so the plan still totals the
  /// salary exactly.
  static MonthlyBudget suggest({
    required String monthKey,
    required double salary,
    required double savingsRate,
  }) {
    if (salary <= 0) return MonthlyBudget.empty(monthKey);

    final double rate = savingsRate.clamp(0.05, 0.7).toDouble();
    final double savings = salary * rate;
    final double spendable = salary - savings;

    double nonSavingsShare = 0;
    for (final BudgetCategory c in BudgetCategory.values) {
      if (c == BudgetCategory.savings) continue;
      nonSavingsShare += c.defaultShare;
    }
    if (nonSavingsShare <= 0) nonSavingsShare = 1;

    final double unit = _roundingUnit(salary);
    final Map<String, double> limits = <String, double>{};
    double assigned = 0;
    BudgetCategory largest = BudgetCategory.food;
    double largestValue = -1;

    for (final BudgetCategory c in BudgetCategory.values) {
      if (c == BudgetCategory.savings) continue;
      final double raw = spendable * (c.defaultShare / nonSavingsShare);
      final double rounded = (raw / unit).round() * unit;
      limits[c.id] = rounded;
      assigned += rounded;
      if (rounded > largestValue) {
        largestValue = rounded;
        largest = c;
      }
    }

    final double savingsRounded = (savings / unit).round() * unit;
    limits[BudgetCategory.savings.id] = savingsRounded;

    // Push the rounding difference into the biggest spending category.
    final double drift = salary - (assigned + savingsRounded);
    limits[largest.id] = math.max(0.0, (limits[largest.id] ?? 0) + drift);

    return MonthlyBudget(monthKey: monthKey, limits: limits);
  }

  /// A tidy step size for this income: roughly 1% of salary, snapped to a
  /// power of ten. A salary of 48,000 rounds limits to the nearest 100.
  static double _roundingUnit(double salary) {
    if (salary <= 0) return 1;
    final double hundredth = salary / 100;
    if (hundredth < 1) return 1;
    final double magnitude =
        math.pow(10, (math.log(hundredth) / math.ln10).floor()).toDouble();
    return magnitude < 1 ? 1 : magnitude;
  }

  /// Fold expenses into per-category usage for the given cycle.
  static BudgetSummary summarise({
    required MonthlyBudget budget,
    required List<Expense> expenses,
    required PayCycle cycle,
    required double income,
  }) {
    final Map<String, double> spent = <String, double>{};
    for (final Expense e in expenses) {
      if (!cycle.contains(e.date)) continue;
      spent[e.categoryId] = (spent[e.categoryId] ?? 0) + e.amount;
    }

    final double progress = cycle.progress;
    final List<CategoryUsage> usage = <CategoryUsage>[
      for (final BudgetCategory c in BudgetCategory.values)
        CategoryUsage(
          category: c,
          limit: budget.limitFor(c),
          spent: spent[c.id] ?? 0,
          expectedByNow: budget.limitFor(c) * progress,
        ),
    ];

    return BudgetSummary(
      budget: budget,
      usage: usage,
      cycle: cycle,
      income: income,
    );
  }

  /// Monthly cost of the things you cannot stop paying for. Feeds the
  /// emergency fund target.
  static double essentialsMonthly(MonthlyBudget budget) {
    double sum = 0;
    for (final BudgetCategory c in BudgetCategory.values) {
      if (c.isEssential) sum += budget.limitFor(c);
    }
    return sum;
  }

  /// Overspending alerts, most severe first. Written to be read out loud.
  static List<String> alerts(BudgetSummary summary) {
    final List<String> out = <String>[];

    for (final CategoryUsage u in summary.overspent) {
      out.add('${u.category.label} is over by '
          '${Money.format(u.overspend)}.');
    }

    for (final CategoryUsage u in summary.watchlist) {
      out.add('${u.category.label} is running ahead of pace — '
          '${Money.format(u.spent)} of ${Money.format(u.limit)} with '
          '${summary.cycle.daysLeft} days to payday.');
    }

    if (summary.totalLimit > 0 && summary.remaining < 0) {
      out.add('You are ${Money.format(-summary.remaining)} past your total '
          'spending plan for this cycle.');
    } else if (summary.cycle.daysLeft > 0 &&
        summary.totalLimit > 0 &&
        summary.safeDailySpend < summary.totalLimit / summary.cycle.totalDays * 0.5) {
      out.add('Slow down: ${Money.format(summary.safeDailySpend)} a day keeps '
          'you inside the plan until payday.');
    }

    if (summary.savingsTarget > 0 &&
        summary.saved < summary.savingsTarget &&
        summary.cycle.progress > 0.6) {
      out.add('Savings is behind: ${Money.format(summary.saved)} of '
          '${Money.format(summary.savingsTarget)} with '
          '${summary.cycle.daysLeft} days left.');
    }

    return out;
  }

  /// Roll a plan into a new month, keeping any edits the user made.
  static MonthlyBudget rollForward({
    required MonthlyBudget previous,
    required String monthKey,
  }) =>
      MonthlyBudget(
        monthKey: monthKey,
        limits: Map<String, double>.of(previous.limits),
      );
}
