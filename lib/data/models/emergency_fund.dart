import '../../core/utils/json.dart';

/// One movement into or out of the emergency fund. Withdrawals are stored as
/// negative amounts so the ledger always explains the balance.
class FundEntry {
  const FundEntry({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
  });

  final String id;
  final double amount;
  final DateTime date;
  final String note;

  bool get isWithdrawal => amount < 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory FundEntry.fromJson(Map<String, dynamic> json) => FundEntry(
        id: J.asString(json['id']),
        amount: J.asDouble(json['amount']),
        date: J.asDate(json['date']),
        note: J.asString(json['note']),
      );
}

/// The emergency fund is just a ledger; the balance is always derived, never
/// stored. That way a wrong entry can be deleted and the balance self-corrects.
class EmergencyFund {
  const EmergencyFund({this.entries = const <FundEntry>[]});

  final List<FundEntry> entries;

  double get balance {
    double sum = 0;
    for (final FundEntry e in entries) {
      sum += e.amount;
    }
    return sum < 0 ? 0 : sum;
  }

  bool get isStarted => entries.any((FundEntry e) => e.amount > 0);

  double get contributedThisMonth {
    final DateTime now = DateTime.now();
    double sum = 0;
    for (final FundEntry e in entries) {
      if (e.date.year == now.year && e.date.month == now.month && e.amount > 0) {
        sum += e.amount;
      }
    }
    return sum;
  }

  /// Newest first, for the ledger list.
  List<FundEntry> get recent {
    final List<FundEntry> sorted = List<FundEntry>.of(entries)
      ..sort((FundEntry a, FundEntry b) => b.date.compareTo(a.date));
    return sorted;
  }

  EmergencyFund copyWith({List<FundEntry>? entries}) =>
      EmergencyFund(entries: entries ?? this.entries);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'entries':
            entries.map((FundEntry e) => e.toJson()).toList(growable: false),
      };

  factory EmergencyFund.fromJson(Map<String, dynamic> json) => EmergencyFund(
        entries: J
            .asMapList(json['entries'])
            .map(FundEntry.fromJson)
            .toList(),
      );
}
