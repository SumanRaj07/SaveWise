import '../../core/utils/formatters.dart';
import '../../core/utils/json.dart';

/// A recurring or one-off bill.
///
/// Recurring bills store a day of the month and a list of months already paid,
/// which means the same record serves every month without duplicating rows.
class Bill {
  const Bill({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.dueDay,
    this.recurring = true,
    this.oneOffDate,
    this.paidMonths = const <String>[],
    this.autoLogAsExpense = true,
  });

  final String id;
  final String name;
  final String type;
  final double amount;

  /// Day of month for recurring bills, 1–31, clamped to short months.
  final int dueDay;

  final bool recurring;

  /// Set only when [recurring] is false.
  final DateTime? oneOffDate;

  /// monthKeys already settled, e.g. ['2026-07', '2026-08'].
  final List<String> paidMonths;

  /// Whether paying it should also log an expense against the budget.
  final bool autoLogAsExpense;

  DateTime dueDateIn(DateTime month) {
    if (!recurring && oneOffDate != null) return oneOffDate!;
    return Dates.dayInMonth(month, dueDay);
  }

  /// The occurrence a user cares about right now: this month's if it is still
  /// unpaid, otherwise next month's.
  DateTime nextDueDate(DateTime now) {
    if (!recurring && oneOffDate != null) return oneOffDate!;
    final DateTime thisMonth = dueDateIn(now);
    if (!isPaidFor(Dates.monthKey(now))) return thisMonth;
    return dueDateIn(DateTime(now.year, now.month + 1));
  }

  bool isPaidFor(String monthKey) => paidMonths.contains(monthKey);

  int daysUntilDue(DateTime now) => Dates.daysBetween(now, nextDueDate(now));

  Bill copyWith({
    String? id,
    String? name,
    String? type,
    double? amount,
    int? dueDay,
    bool? recurring,
    DateTime? oneOffDate,
    List<String>? paidMonths,
    bool? autoLogAsExpense,
  }) =>
      Bill(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        dueDay: dueDay ?? this.dueDay,
        recurring: recurring ?? this.recurring,
        oneOffDate: oneOffDate ?? this.oneOffDate,
        paidMonths: paidMonths ?? this.paidMonths,
        autoLogAsExpense: autoLogAsExpense ?? this.autoLogAsExpense,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type,
        'amount': amount,
        'dueDay': dueDay,
        'recurring': recurring,
        'oneOffDate': oneOffDate?.toIso8601String(),
        'paidMonths': paidMonths,
        'autoLogAsExpense': autoLogAsExpense,
      };

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: J.asString(json['id']),
        name: J.asString(json['name'], 'Bill'),
        type: J.asString(json['type'], 'Other'),
        amount: J.asDouble(json['amount']),
        dueDay: J.asIntClamped(json['dueDay'], 1, 31, 1),
        recurring: J.asBool(json['recurring'], true),
        oneOffDate: J.asDateOrNull(json['oneOffDate']),
        paidMonths: J.asStringList(json['paidMonths']),
        autoLogAsExpense: J.asBool(json['autoLogAsExpense'], true),
      );
}

/// Where a bill sits relative to today. Drives the reminder windows in the
/// brief: 7 days, 3 days, 1 day, due today.
enum BillUrgency { overdue, dueToday, dueTomorrow, dueThisWeek, upcoming, paid }

extension BillUrgencyX on BillUrgency {
  String get label => switch (this) {
        BillUrgency.overdue => 'Overdue',
        BillUrgency.dueToday => 'Due today',
        BillUrgency.dueTomorrow => 'Due tomorrow',
        BillUrgency.dueThisWeek => 'This week',
        BillUrgency.upcoming => 'Upcoming',
        BillUrgency.paid => 'Paid',
      };

  /// True for the states that warrant a notification-style nudge.
  bool get needsAttention =>
      this == BillUrgency.overdue ||
      this == BillUrgency.dueToday ||
      this == BillUrgency.dueTomorrow;
}
