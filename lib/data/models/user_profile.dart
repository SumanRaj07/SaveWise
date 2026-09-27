import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/utils/json.dart';

/// Everything the app knows about the person using it.
///
/// There is no account, no email, no id issued by a server. This record lives
/// in the device's own storage and nowhere else.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.monthlySalary,
    required this.salaryDay,
    required this.currencyCode,
    required this.currencySymbol,
    required this.localeTag,
    required this.createdAt,
    this.savingsRateTarget = AppConstants.targetSavingsRate,
    this.coins = 0,
    this.xp = 0,
    this.streak = 0,
    this.longestStreak = 0,
    this.lastChallengeDay,
  });

  /// Optional, per the brief. Empty means "we never asked twice".
  final String name;
  final double monthlySalary;

  /// Day of month salary lands, 1–31, clamped to short months on use.
  final int salaryDay;

  final String currencyCode;
  final String currencySymbol;
  final String localeTag;
  final DateTime createdAt;

  /// Share of income the planner aims to save. Editable in the planner.
  final double savingsRateTarget;

  final int coins;
  final int xp;
  final int streak;
  final int longestStreak;

  /// dayKey of the most recent completed daily challenge, for streak maths.
  final String? lastChallengeDay;

  bool get hasName => name.trim().isNotEmpty;

  /// Used in greetings. Never invents a name.
  String get greetingName => hasName ? name.trim().split(' ').first : '';

  int get level => (xp ~/ AppConstants.xpPerLevel) + 1;

  double get levelProgress {
    final int into = xp % AppConstants.xpPerLevel;
    return (into / AppConstants.xpPerLevel).clamp(0.0, 1.0).toDouble();
  }

  int get xpToNextLevel => AppConstants.xpPerLevel - (xp % AppConstants.xpPerLevel);

  /// Daily discretionary allowance: what one day of non-essential, non-savings
  /// money looks like. Daily challenges scale off this.
  double dailyDiscretionary(int daysInMonth) {
    if (daysInMonth <= 0) return 0;
    final double wants = monthlySalary *
        (BudgetCategory.shopping.defaultShare +
            BudgetCategory.entertainment.defaultShare);
    return math.max(0.0, wants / daysInMonth);
  }

  UserProfile copyWith({
    String? name,
    double? monthlySalary,
    int? salaryDay,
    String? currencyCode,
    String? currencySymbol,
    String? localeTag,
    DateTime? createdAt,
    double? savingsRateTarget,
    int? coins,
    int? xp,
    int? streak,
    int? longestStreak,
    String? lastChallengeDay,
  }) {
    return UserProfile(
      name: name ?? this.name,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      salaryDay: salaryDay ?? this.salaryDay,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      localeTag: localeTag ?? this.localeTag,
      createdAt: createdAt ?? this.createdAt,
      savingsRateTarget: savingsRateTarget ?? this.savingsRateTarget,
      coins: coins ?? this.coins,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastChallengeDay: lastChallengeDay ?? this.lastChallengeDay,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'monthlySalary': monthlySalary,
        'salaryDay': salaryDay,
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'localeTag': localeTag,
        'createdAt': createdAt.toIso8601String(),
        'savingsRateTarget': savingsRateTarget,
        'coins': coins,
        'xp': xp,
        'streak': streak,
        'longestStreak': longestStreak,
        'lastChallengeDay': lastChallengeDay,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: J.asString(json['name']),
        monthlySalary: J.asDouble(json['monthlySalary']),
        salaryDay: J.asIntClamped(json['salaryDay'], 1, 31, 1),
        currencyCode: J.asString(json['currencyCode'], 'USD'),
        currencySymbol: J.asString(json['currencySymbol'], r'$'),
        localeTag: J.asString(json['localeTag'], 'en_US'),
        createdAt: J.asDate(json['createdAt']),
        savingsRateTarget: J.asDoubleClamped(json['savingsRateTarget'], 0.05,
            0.7, AppConstants.targetSavingsRate),
        coins: J.asInt(json['coins']),
        xp: J.asInt(json['xp']),
        streak: J.asInt(json['streak']),
        longestStreak: J.asInt(json['longestStreak']),
        lastChallengeDay: json['lastChallengeDay'] == null
            ? null
            : J.asString(json['lastChallengeDay']),
      );
}
