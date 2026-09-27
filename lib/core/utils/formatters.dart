import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Currency formatting, driven entirely by the device locale.
///
/// The device tells us the locale at first launch; we resolve a currency from
/// it, store the resolution in the profile so it stays stable, and let the
/// user override it later. Every intl call is guarded — an unusual locale
/// falls back to `en_US` rather than crashing the app on the setup screen.
abstract final class Money {
  static String _locale = 'en_US';
  static String _code = 'USD';
  static String _symbol = r'$';

  static String get locale => _locale;
  static String get code => _code;
  static String get symbol => _symbol;

  /// Best-effort locale tag for the current device, in intl's underscore form.
  static String deviceLocaleTag(String languageCode, String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return languageCode;
    return '${languageCode}_$countryCode';
  }

  /// Resolve the currency the device locale implies. Returns code + symbol.
  static (String code, String symbol) resolveForLocale(String localeTag) {
    try {
      final NumberFormat f = NumberFormat.simpleCurrency(locale: localeTag);
      final String code = f.currencyName ?? 'USD';
      final String symbol =
          f.currencySymbol.isEmpty ? code : f.currencySymbol;
      return (code, symbol);
    } catch (_) {
      return ('USD', r'$');
    }
  }

  static void configure({
    required String localeTag,
    required String currencyCode,
    required String currencySymbol,
  }) {
    _locale = localeTag.isEmpty ? 'en_US' : localeTag;
    _code = currencyCode.isEmpty ? 'USD' : currencyCode;
    _symbol = currencySymbol.isEmpty ? _code : currencySymbol;
  }

  static NumberFormat _currencyFormat(int decimals) {
    try {
      return NumberFormat.currency(
        locale: _locale,
        symbol: _symbol,
        decimalDigits: decimals,
      );
    } catch (_) {
      return NumberFormat.currency(
        locale: 'en_US',
        symbol: _symbol,
        decimalDigits: decimals,
      );
    }
  }

  /// Money for display. Budgeting amounts read cleaner without minor units,
  /// so decimals are opt-in.
  static String format(num value, {bool decimals = false}) {
    final int digits = decimals ? 2 : 0;
    try {
      return _currencyFormat(digits).format(value);
    } catch (_) {
      return '$_symbol${value.toStringAsFixed(digits)}';
    }
  }

  /// Signed money, used in ledgers where direction matters.
  static String formatSigned(num value, {bool decimals = false}) {
    final String base = format(value.abs(), decimals: decimals);
    if (value > 0) return '+$base';
    if (value < 0) return '-$base';
    return base;
  }

  /// Short money for chart axes and dense chips: "$12.4K".
  static String compact(num value) {
    try {
      return NumberFormat.compactCurrency(
        locale: _locale,
        symbol: _symbol,
        decimalDigits: value.abs() >= 1000 ? 1 : 0,
      ).format(value);
    } catch (_) {
      return format(value);
    }
  }

  /// Digits only, for prefilling editable fields.
  static String plain(num value, {bool decimals = false}) {
    try {
      return NumberFormat.decimalPatternDigits(
        locale: _locale,
        decimalDigits: decimals ? 2 : 0,
      ).format(value);
    } catch (_) {
      return value.toStringAsFixed(decimals ? 2 : 0);
    }
  }

  /// Tolerant parser: accepts grouped digits, stray symbols, spaces.
  static double? parse(String raw) {
    if (raw.trim().isEmpty) return null;
    final String cleaned =
        raw.replaceAll(RegExp(r'[^0-9.\-]'), '').replaceAll(RegExp(r'(?!^)-'), '');
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return null;
    return double.tryParse(cleaned);
  }

  /// Round to a number a human would actually say out loud.
  ///
  /// Milestones and daily challenges are derived from a share of income, which
  /// produces values like 1,873. Nobody sets a goal of 1,873 — they set 2,000.
  /// This is what keeps the app currency-neutral without hard-coding amounts.
  static double niceRound(double value) {
    if (value <= 0) return 0;
    if (value < 10) return value.roundToDouble();
    final double magnitude =
        math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    final double normalised = value / magnitude;
    const List<double> steps = <double>[1, 1.5, 2, 2.5, 3, 4, 5, 7.5, 10];
    double best = steps.first;
    double bestGap = (normalised - best).abs();
    for (final double s in steps) {
      final double gap = (normalised - s).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = s;
      }
    }
    return best * magnitude;
  }

  static String percent(double fraction, {int decimals = 0}) {
    final double pct = (fraction * 100).clamp(-999.0, 999.0).toDouble();
    return '${pct.toStringAsFixed(decimals)}%';
  }
}

/// Date and time formatting. Same guarded approach as [Money].
///
/// Deliberately avoids English ordinals ("17th") anywhere, because the app is
/// locale-driven — salary day renders as a bare number with a label instead.
abstract final class Dates {
  static String _locale = 'en_US';

  static void configure(String localeTag) {
    try {
      _locale = Intl.verifiedLocale(
            localeTag,
            DateFormat.localeExists,
            onFailure: (String _) => 'en_US',
          ) ??
          'en_US';
    } catch (_) {
      _locale = 'en_US';
    }
  }

  static String _fmt(String pattern, DateTime when) {
    try {
      return DateFormat(pattern, _locale).format(when);
    } catch (_) {
      return DateFormat(pattern, 'en_US').format(when);
    }
  }

  /// "17 August 2026" — the dashboard date line.
  static String longDate(DateTime when) => _fmt('d MMMM y', when);

  /// "17 Aug 2026"
  static String mediumDate(DateTime when) => _fmt('d MMM y', when);

  /// "17 Aug"
  static String shortDate(DateTime when) => _fmt('d MMM', when);

  /// "August 2026"
  static String monthLabel(DateTime when) => _fmt('MMMM y', when);

  /// "Aug"
  static String monthShort(DateTime when) => _fmt('MMM', when);

  /// "Mon"
  static String weekdayShort(DateTime when) => _fmt('EEE', when);

  /// "04:30:15 PM" — with running seconds, per the dashboard spec.
  static String clock(DateTime when) => _fmt('hh:mm:ss a', when);

  /// Stable storage keys. Never localised: these are data, not display.
  static String monthKey(DateTime when) =>
      '${when.year.toString().padLeft(4, '0')}-${when.month.toString().padLeft(2, '0')}';

  static String dayKey(DateTime when) =>
      '${monthKey(when)}-${when.day.toString().padLeft(2, '0')}';

  static DateTime monthFromKey(String key) {
    final List<String> parts = key.split('-');
    if (parts.length < 2) return startOfMonth(DateTime.now());
    return DateTime(int.tryParse(parts[0]) ?? DateTime.now().year,
        int.tryParse(parts[1]) ?? 1);
  }

  static DateTime dateOnly(DateTime when) =>
      DateTime(when.year, when.month, when.day);

  static DateTime startOfMonth(DateTime when) =>
      DateTime(when.year, when.month);

  static DateTime endOfMonth(DateTime when) =>
      DateTime(when.year, when.month + 1, 0);

  static int daysInMonth(DateTime when) => endOfMonth(when).day;

  static int daysBetween(DateTime from, DateTime to) =>
      dateOnly(to).difference(dateOnly(from)).inDays;

  /// Whole days left in the current month, including today.
  static int daysLeftInMonth(DateTime when) =>
      daysInMonth(when) - when.day + 1;

  /// Clamp a day number (1–31) onto a month that may be shorter. Used for
  /// salary dates and recurring bill dates alike.
  static DateTime dayInMonth(DateTime month, int day) {
    final int last = daysInMonth(month);
    final int safe = day < 1 ? 1 : (day > last ? last : day);
    return DateTime(month.year, month.month, safe);
  }

  /// Clamp a salary day (1–31) onto a month that may be shorter.
  static DateTime salaryDateIn(DateTime month, int salaryDay) =>
      dayInMonth(month, salaryDay);

  /// The next time salary lands, given today.
  static DateTime nextSalaryDate(DateTime now, int salaryDay) {
    final DateTime thisMonth = salaryDateIn(now, salaryDay);
    if (!dateOnly(thisMonth).isBefore(dateOnly(now))) return thisMonth;
    return salaryDateIn(DateTime(now.year, now.month + 1), salaryDay);
  }

  /// The salary date that opened the current pay cycle.
  static DateTime currentCycleStart(DateTime now, int salaryDay) {
    final DateTime thisMonth = salaryDateIn(now, salaryDay);
    if (!dateOnly(thisMonth).isAfter(dateOnly(now))) return thisMonth;
    return salaryDateIn(DateTime(now.year, now.month - 1), salaryDay);
  }

  /// Plain-language distance in days. Used by bills and goals.
  static String dueLabel(int days) {
    if (days < -1) return 'Overdue by ${-days} days';
    if (days == -1) return 'Overdue by 1 day';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days < 7) return 'Due in $days days';
    if (days < 14) return 'Due next week';
    return 'Due in $days days';
  }

  static String durationLabel(int days) {
    if (days <= 0) return 'Today';
    if (days == 1) return '1 day';
    if (days < 30) return '$days days';
    final int months = (days / 30.44).round();
    if (months < 12) return months == 1 ? '1 month' : '$months months';
    final int years = (days / 365.25).floor();
    final int rem = ((days - years * 365.25) / 30.44).round();
    if (rem == 0) return years == 1 ? '1 year' : '$years years';
    return '${years}y ${rem}m';
  }
}
