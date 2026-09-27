import '../../core/utils/json.dart';

/// A badge the user has earned. The definition lives in the catalogue; this is
/// only the record that it happened, and when.
class UnlockedAchievement {
  const UnlockedAchievement({required this.id, required this.unlockedAt});

  final String id;
  final DateTime unlockedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'unlockedAt': unlockedAt.toIso8601String(),
      };

  factory UnlockedAchievement.fromJson(Map<String, dynamic> json) =>
      UnlockedAchievement(
        id: J.asString(json['id']),
        unlockedAt: J.asDate(json['unlockedAt']),
      );
}
