import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The seven spending categories from the brief.
///
/// Default shares are a decomposed 50/30/20 plan, which is the thing most
/// worth teaching a first-time budgeter:
///   needs 50  = food 25 + transport 12 + medical 5 + other 8
///   wants 30  = shopping 10 + entertainment 8 + other 12
///   savings 20
/// "Other" straddles both, which is exactly why it's the category to interrogate
/// first when someone overspends.
enum BudgetCategory {
  food,
  transport,
  medical,
  shopping,
  entertainment,
  savings,
  other,
}

extension BudgetCategoryX on BudgetCategory {
  /// Stable storage id. Never rename these — they are persisted.
  String get id => switch (this) {
        BudgetCategory.food => 'food',
        BudgetCategory.transport => 'transport',
        BudgetCategory.medical => 'medical',
        BudgetCategory.shopping => 'shopping',
        BudgetCategory.entertainment => 'entertainment',
        BudgetCategory.savings => 'savings',
        BudgetCategory.other => 'other',
      };

  String get label => switch (this) {
        BudgetCategory.food => 'Food',
        BudgetCategory.transport => 'Transport',
        BudgetCategory.medical => 'Medical',
        BudgetCategory.shopping => 'Shopping',
        BudgetCategory.entertainment => 'Entertainment',
        BudgetCategory.savings => 'Savings',
        BudgetCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        BudgetCategory.food => Icons.restaurant_rounded,
        BudgetCategory.transport => Icons.directions_bus_filled_rounded,
        BudgetCategory.medical => Icons.medical_services_rounded,
        BudgetCategory.shopping => Icons.shopping_bag_rounded,
        BudgetCategory.entertainment => Icons.movie_rounded,
        BudgetCategory.savings => Icons.savings_rounded,
        BudgetCategory.other => Icons.more_horiz_rounded,
      };

  Color get color => switch (this) {
        BudgetCategory.food => AppColors.emerald,
        BudgetCategory.transport => AppColors.vizTeal,
        BudgetCategory.medical => AppColors.clay,
        BudgetCategory.shopping => AppColors.brass,
        BudgetCategory.entertainment => AppColors.vizMauve,
        BudgetCategory.savings => AppColors.emeraldDeep,
        BudgetCategory.other => AppColors.vizGrey,
      };

  double get defaultShare => switch (this) {
        BudgetCategory.food => 0.25,
        BudgetCategory.transport => 0.12,
        BudgetCategory.medical => 0.05,
        BudgetCategory.shopping => 0.10,
        BudgetCategory.entertainment => 0.08,
        BudgetCategory.savings => 0.20,
        BudgetCategory.other => 0.20,
      };

  /// Essentials drive the emergency fund target: you need to cover the things
  /// you cannot stop paying for, not your whole lifestyle.
  bool get isEssential => switch (this) {
        BudgetCategory.food => true,
        BudgetCategory.transport => true,
        BudgetCategory.medical => true,
        BudgetCategory.other => true,
        BudgetCategory.shopping => false,
        BudgetCategory.entertainment => false,
        BudgetCategory.savings => false,
      };

  /// Discretionary categories are where "spend less" advice can actually land.
  bool get isDiscretionary =>
      this == BudgetCategory.shopping || this == BudgetCategory.entertainment;

  static BudgetCategory fromId(String id) {
    for (final BudgetCategory c in BudgetCategory.values) {
      if (c.id == id) return c;
    }
    return BudgetCategory.other;
  }
}

abstract final class AppConstants {
  static const String appName = 'SaveWise';
  static const String tagline = 'Spend Smart. Save Better. Achieve More.';

  /// Emergency fund horizons, in months of essential spending.
  static const int emergencyMinMonths = 3;
  static const int emergencyIdealMonths = 6;

  /// Health score weights. Must total 100.
  static const int weightSavingsRate = 30;
  static const int weightDiscipline = 25;
  static const int weightEmergency = 25;
  static const int weightGoals = 20;

  /// A savings rate at or above this earns full marks on factor one.
  static const double targetSavingsRate = 0.20;

  /// Goal milestone thresholds, as percentages.
  static const List<int> goalMilestones = <int>[25, 50, 75, 100];

  /// Rewards economy. Small numbers, frequent wins.
  static const int coinsPerChallenge = 10;
  static const int xpPerChallenge = 25;
  static const int xpPerLevel = 250;
  static const int streakBonusCoins = 25;
  static const int streakBonusEvery = 7;

  /// How many months of history the reports screen charts.
  static const int reportMonths = 6;

  static const List<String> billTypes = <String>[
    'Rent',
    'Electricity',
    'Water',
    'Internet',
    'Mobile',
    'Credit card',
    'Insurance',
    'Subscription',
    'Loan EMI',
    'Other',
  ];

  static IconData billIcon(String type) => switch (type) {
        'Rent' => Icons.home_rounded,
        'Electricity' => Icons.bolt_rounded,
        'Water' => Icons.water_drop_rounded,
        'Internet' => Icons.wifi_rounded,
        'Mobile' => Icons.smartphone_rounded,
        'Credit card' => Icons.credit_card_rounded,
        'Insurance' => Icons.shield_rounded,
        'Subscription' => Icons.subscriptions_rounded,
        'Loan EMI' => Icons.account_balance_rounded,
        _ => Icons.receipt_long_rounded,
      };

  /// Reminder windows from the brief, in days before due date.
  static const List<int> reminderDays = <int>[7, 3, 1, 0];
}
