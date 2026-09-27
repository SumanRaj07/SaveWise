import '../../core/constants/challenge_pool.dart';
import '../../core/utils/json.dart';

enum ChallengeStatus { pending, completed, skipped }

/// Today's challenge, materialised from a [ChallengeTemplate] with a real
/// amount attached. Stored per day so history and streaks survive a restart.
class DailyChallenge {
  const DailyChallenge({
    required this.dayKey,
    required this.templateId,
    required this.title,
    required this.detail,
    required this.kind,
    required this.coins,
    required this.xp,
    this.amount = 0,
    this.categoryId,
    this.status = ChallengeStatus.pending,
  });

  final String dayKey;
  final String templateId;

  /// Already has its `{amount}` substituted, in the user's currency.
  final String title;
  final String detail;

  final ChallengeKind kind;
  final double amount;
  final String? categoryId;
  final int coins;
  final int xp;
  final ChallengeStatus status;

  bool get isPending => status == ChallengeStatus.pending;
  bool get isCompleted => status == ChallengeStatus.completed;

  /// Whether the app can grade this itself from logged data, or has to ask.
  bool get isSelfReported => kind == ChallengeKind.habit;

  DailyChallenge copyWith({ChallengeStatus? status}) => DailyChallenge(
        dayKey: dayKey,
        templateId: templateId,
        title: title,
        detail: detail,
        kind: kind,
        coins: coins,
        xp: xp,
        amount: amount,
        categoryId: categoryId,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dayKey': dayKey,
        'templateId': templateId,
        'title': title,
        'detail': detail,
        'kind': kind.name,
        'amount': amount,
        'categoryId': categoryId,
        'coins': coins,
        'xp': xp,
        'status': status.name,
      };

  factory DailyChallenge.fromJson(Map<String, dynamic> json) => DailyChallenge(
        dayKey: J.asString(json['dayKey']),
        templateId: J.asString(json['templateId']),
        title: J.asString(json['title']),
        detail: J.asString(json['detail']),
        kind: J.asEnum(json['kind'], ChallengeKind.values, ChallengeKind.habit),
        amount: J.asDouble(json['amount']),
        categoryId:
            json['categoryId'] == null ? null : J.asString(json['categoryId']),
        coins: J.asInt(json['coins'], 10),
        xp: J.asInt(json['xp'], 25),
        status: J.asEnum(
            json['status'], ChallengeStatus.values, ChallengeStatus.pending),
      );
}
