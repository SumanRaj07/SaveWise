import '../../core/utils/formatters.dart';

/// The window between one salary landing and the next.
///
/// Almost every judgement in the app is fairer against the pay cycle than
/// against the calendar month. Someone paid on the 25th is not "80% through
/// their money" on the 25th — they have just been paid. Grading discipline and
/// savings pace on the cycle is the difference between advice that feels
/// perceptive and advice that feels broken.
class PayCycle {
  const PayCycle({
    required this.start,
    required this.end,
    required this.now,
  });

  final DateTime start;
  final DateTime end;
  final DateTime now;

  factory PayCycle.forDate(DateTime now, int salaryDay) {
    final DateTime start = Dates.currentCycleStart(now, salaryDay);
    final DateTime end = Dates.salaryDateIn(
      DateTime(start.year, start.month + 1),
      salaryDay,
    );
    return PayCycle(start: start, end: end, now: now);
  }

  int get totalDays {
    final int days = Dates.daysBetween(start, end);
    return days <= 0 ? 30 : days;
  }

  int get elapsedDays {
    final int days = Dates.daysBetween(start, now);
    if (days < 0) return 0;
    return days > totalDays ? totalDays : days;
  }

  int get daysLeft {
    final int left = totalDays - elapsedDays;
    return left < 0 ? 0 : left;
  }

  /// 0 on payday, 1 the day before the next one.
  double get progress {
    final double p = elapsedDays / totalDays;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  /// Progress with a floor, for grading. Nobody should be marked down for not
  /// having saved a month's worth on day two.
  double gradingProgress({double floor = 0.34}) =>
      progress < floor ? floor : progress;

  bool contains(DateTime date) {
    final DateTime d = Dates.dateOnly(date);
    return !d.isBefore(Dates.dateOnly(start)) && d.isBefore(Dates.dateOnly(end));
  }

  DateTime get nextPayday => end;

  int get daysToPayday => Dates.daysBetween(now, end);
}
