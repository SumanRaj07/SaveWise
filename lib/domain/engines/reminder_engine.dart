import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/bill.dart';

/// A bill, resolved against today: when it is next due, how urgent that is, and
/// whether this cycle has already been settled.
class BillReminder {
  const BillReminder({
    required this.bill,
    required this.dueDate,
    required this.daysUntil,
    required this.urgency,
    required this.monthKey,
  });

  final Bill bill;
  final DateTime dueDate;

  /// Negative when overdue.
  final int daysUntil;

  final BillUrgency urgency;

  /// The cycle this occurrence belongs to.
  final String monthKey;

  bool get isPaid => urgency == BillUrgency.paid;

  bool get needsAttention => urgency.needsAttention;

  String get dueLabel => isPaid ? 'Paid' : Dates.dueLabel(daysUntil);

  /// True at one of the brief's reminder windows: 7, 3, 1 or 0 days out.
  bool get isReminderDay =>
      !isPaid && AppConstants.reminderDays.contains(daysUntil);

  /// Notification-style copy. Written the way a person would say it.
  String get message {
    if (isPaid) return '${bill.name} is settled for this cycle.';
    if (daysUntil < 0) {
      return '${bill.name} was due ${Dates.shortDate(dueDate)} — '
          '${Money.format(bill.amount)} outstanding.';
    }
    if (daysUntil == 0) {
      return '${bill.name} is due today: ${Money.format(bill.amount)}.';
    }
    if (daysUntil == 1) {
      return '${bill.name} is due tomorrow: ${Money.format(bill.amount)}.';
    }
    return '${bill.name} is due in $daysUntil days: '
        '${Money.format(bill.amount)}.';
  }
}

abstract final class ReminderEngine {
  /// Resolve every bill against today, soonest first.
  ///
  /// Paid bills sink to the bottom and show their *next* occurrence, so the list
  /// answers "what do I owe" without hiding what is coming.
  static List<BillReminder> build({
    required List<Bill> bills,
    required DateTime now,
  }) {
    final String currentMonth = Dates.monthKey(now);
    final List<BillReminder> out = <BillReminder>[];

    for (final Bill b in bills) {
      final bool paidThisCycle = b.isPaidFor(currentMonth);
      final DateTime due = b.nextDueDate(now);
      final int days = Dates.daysBetween(now, due);

      final BillUrgency urgency;
      if (paidThisCycle && b.recurring) {
        urgency = BillUrgency.paid;
      } else if (!b.recurring && paidThisCycle) {
        urgency = BillUrgency.paid;
      } else if (days < 0) {
        urgency = BillUrgency.overdue;
      } else if (days == 0) {
        urgency = BillUrgency.dueToday;
      } else if (days == 1) {
        urgency = BillUrgency.dueTomorrow;
      } else if (days <= 7) {
        urgency = BillUrgency.dueThisWeek;
      } else {
        urgency = BillUrgency.upcoming;
      }

      out.add(BillReminder(
        bill: b,
        dueDate: due,
        daysUntil: days,
        urgency: urgency,
        monthKey: Dates.monthKey(due),
      ));
    }

    out.sort((BillReminder a, BillReminder b) {
      if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
      return a.daysUntil.compareTo(b.daysUntil);
    });
    return out;
  }

  static List<BillReminder> unpaid(List<BillReminder> all) =>
      all.where((BillReminder r) => !r.isPaid).toList(growable: false);

  static List<BillReminder> overdue(List<BillReminder> all) => all
      .where((BillReminder r) => r.urgency == BillUrgency.overdue)
      .toList(growable: false);

  static List<BillReminder> paid(List<BillReminder> all) =>
      all.where((BillReminder r) => r.isPaid).toList(growable: false);

  /// The ones worth interrupting someone for: overdue, today, tomorrow.
  static List<BillReminder> needingAttention(List<BillReminder> all) =>
      all.where((BillReminder r) => r.needsAttention).toList(growable: false);

  /// Everything still owed this cycle. This is the number that should be
  /// subtracted from "remaining balance" before anyone feels rich on payday.
  static double outstanding(List<BillReminder> all) {
    double sum = 0;
    for (final BillReminder r in all) {
      if (r.isPaid) continue;
      sum += r.bill.amount;
    }
    return sum;
  }

  static double paidTotal(List<BillReminder> all) {
    double sum = 0;
    for (final BillReminder r in all) {
      if (r.isPaid) sum += r.bill.amount;
    }
    return sum;
  }

  /// Total of every recurring bill — the fixed cost of a month.
  static double monthlyFixedCost(List<Bill> bills) {
    double sum = 0;
    for (final Bill b in bills) {
      if (b.recurring) sum += b.amount;
    }
    return sum;
  }

  /// The next bill to land, ignoring anything already settled.
  static BillReminder? next(List<BillReminder> all) {
    for (final BillReminder r in all) {
      if (!r.isPaid) return r;
    }
    return null;
  }

  /// Reminder copy for the dashboard, capped so it stays a nudge rather than a
  /// wall of text.
  static List<String> messages(List<BillReminder> all, {int limit = 3}) {
    final List<String> out = <String>[];
    for (final BillReminder r in all) {
      if (out.length >= limit) break;
      if (r.needsAttention || r.isReminderDay) out.add(r.message);
    }
    return out;
  }

  /// Mark a bill settled for the cycle its due date falls in.
  static Bill markPaid(Bill bill, DateTime when) {
    final String key = Dates.monthKey(bill.recurring ? when : (bill.oneOffDate ?? when));
    if (bill.paidMonths.contains(key)) return bill;
    return bill.copyWith(
      paidMonths: <String>[...bill.paidMonths, key],
    );
  }

  static Bill markUnpaid(Bill bill, DateTime when) {
    final String key = Dates.monthKey(bill.recurring ? when : (bill.oneOffDate ?? when));
    if (!bill.paidMonths.contains(key)) return bill;
    return bill.copyWith(
      paidMonths: bill.paidMonths
          .where((String m) => m != key)
          .toList(growable: false),
    );
  }
}
