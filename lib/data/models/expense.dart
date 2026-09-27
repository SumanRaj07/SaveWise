import '../../core/constants/app_constants.dart';
import '../../core/utils/json.dart';

/// A single logged expense.
class Expense {
  const Expense({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.note = '',
  });

  final String id;
  final String categoryId;
  final double amount;
  final DateTime date;
  final String note;

  BudgetCategory get category => BudgetCategoryX.fromId(categoryId);

  /// What to show when the user typed no note.
  String get displayLabel => note.trim().isEmpty ? category.label : note.trim();

  Expense copyWith({
    String? id,
    String? categoryId,
    double? amount,
    DateTime? date,
    String? note,
  }) =>
      Expense(
        id: id ?? this.id,
        categoryId: categoryId ?? this.categoryId,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'categoryId': categoryId,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: J.asString(json['id']),
        categoryId: J.asString(json['categoryId'], 'other'),
        amount: J.asDouble(json['amount']),
        date: J.asDate(json['date']),
        note: J.asString(json['note']),
      );
}
