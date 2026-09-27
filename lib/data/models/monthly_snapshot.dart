import '../../core/utils/json.dart';

/// A frozen record of one finished month.
///
/// Written when the app first opens in a new month. Without it, the reports
/// screen could only ever show the present, and a trend line needs a past.
class MonthlySnapshot {
  const MonthlySnapshot({
    required this.monthKey,
    required this.income,
    required this.expenses,
    required this.savings,
    required this.healthScore,
    required this.emergencyFund,
    required this.goalProgress,
  });

  final String monthKey;
  final double income;
  final double expenses;
  final double savings;
  final int healthScore;
  final double emergencyFund;

  /// Average completion across active goals at close of month, 0–1.
  final double goalProgress;

  double get savingsRate => income <= 0 ? 0 : savings / income;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'monthKey': monthKey,
        'income': income,
        'expenses': expenses,
        'savings': savings,
        'healthScore': healthScore,
        'emergencyFund': emergencyFund,
        'goalProgress': goalProgress,
      };

  factory MonthlySnapshot.fromJson(Map<String, dynamic> json) => MonthlySnapshot(
        monthKey: J.asString(json['monthKey']),
        income: J.asDouble(json['income']),
        expenses: J.asDouble(json['expenses']),
        savings: J.asDouble(json['savings']),
        healthScore: J.asInt(json['healthScore']),
        emergencyFund: J.asDouble(json['emergencyFund']),
        goalProgress: J.asDouble(json['goalProgress']),
      );
}
