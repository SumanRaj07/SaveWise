import '../../core/constants/achievement_catalog.dart';

/// A badge with its current standing attached.
class AchievementProgress {
  const AchievementProgress({
    required this.def,
    required this.value,
    required this.unlockedAt,
  });

  final AchievementDef def;

  /// The measured value for this badge's metric.
  final double value;

  /// Null while still locked.
  final DateTime? unlockedAt;

  bool get isUnlocked => unlockedAt != null;

  double get progress {
    if (def.threshold <= 0) return 1;
    return (value / def.threshold).clamp(0.0, 1.0).toDouble();
  }

  int get percent => (progress * 100).round();

  /// What is left to do, in the metric's own units.
  double get remaining {
    final double gap = def.threshold - value;
    return gap < 0 ? 0 : gap;
  }
}

/// The four numbers every badge is judged against.
class AchievementInputs {
  const AchievementInputs({
    required this.monthlySalary,
    required this.lifetimeSaved,
    required this.goalsCompleted,
    required this.emergencyFraction,
    required this.longestStreak,
  });

  final double monthlySalary;

  /// Every unit of money the user has moved into savings, ever.
  final double lifetimeSaved;

  final int goalsCompleted;

  /// Emergency fund as a share of the six-month target, 0–1.
  final double emergencyFraction;

  final int longestStreak;

  /// Savings expressed in months of income, which is what the tiers measure.
  double get savingsMultiple =>
      monthlySalary <= 0 ? 0 : lifetimeSaved / monthlySalary;

  double valueFor(AchievementMetric metric) => switch (metric) {
        AchievementMetric.savingsMultiple => savingsMultiple,
        AchievementMetric.goalsCompleted => goalsCompleted.toDouble(),
        AchievementMetric.streakDays => longestStreak.toDouble(),
        AchievementMetric.emergencyFraction => emergencyFraction,
      };
}

abstract final class AchievementEngine {
  /// Badges whose conditions are met but which have not been recorded yet.
  ///
  /// The caller persists these and shows the celebration; the engine itself
  /// stays pure so it can be tested without touching storage.
  static List<AchievementDef> newlyUnlocked({
    required AchievementInputs inputs,
    required Set<String> alreadyUnlocked,
  }) {
    final List<AchievementDef> out = <AchievementDef>[];
    for (final AchievementDef d in AchievementCatalog.all) {
      if (alreadyUnlocked.contains(d.id)) continue;
      if (inputs.valueFor(d.metric) >= d.threshold) out.add(d);
    }
    return out;
  }

  /// Every badge with progress, unlocked ones first, then closest-to-unlocked.
  static List<AchievementProgress> progressList({
    required AchievementInputs inputs,
    required Map<String, DateTime> unlockedAt,
  }) {
    final List<AchievementProgress> list = <AchievementProgress>[
      for (final AchievementDef d in AchievementCatalog.all)
        AchievementProgress(
          def: d,
          value: inputs.valueFor(d.metric),
          unlockedAt: unlockedAt[d.id],
        ),
    ];
    list.sort((AchievementProgress a, AchievementProgress b) {
      if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? -1 : 1;
      if (a.isUnlocked && b.isUnlocked) {
        return b.unlockedAt!.compareTo(a.unlockedAt!);
      }
      return b.progress.compareTo(a.progress);
    });
    return list;
  }

  static List<AchievementProgress> forGroup({
    required AchievementInputs inputs,
    required Map<String, DateTime> unlockedAt,
    required AchievementGroup group,
  }) =>
      <AchievementProgress>[
        for (final AchievementDef d in AchievementCatalog.forGroup(group))
          AchievementProgress(
            def: d,
            value: inputs.valueFor(d.metric),
            unlockedAt: unlockedAt[d.id],
          ),
      ];

  /// The badge the user is closest to earning. Good dashboard motivation.
  static AchievementProgress? nextUp({
    required AchievementInputs inputs,
    required Map<String, DateTime> unlockedAt,
  }) {
    AchievementProgress? best;
    for (final AchievementDef d in AchievementCatalog.all) {
      if (unlockedAt.containsKey(d.id)) continue;
      final AchievementProgress p = AchievementProgress(
        def: d,
        value: inputs.valueFor(d.metric),
        unlockedAt: null,
      );
      if (best == null || p.progress > best.progress) best = p;
    }
    return best;
  }

  static int unlockedCount(Map<String, DateTime> unlockedAt) => unlockedAt.length;

  static int totalCount() => AchievementCatalog.all.length;
}
