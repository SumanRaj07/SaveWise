import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/json.dart';

enum GoalPriority { high, medium, low }

extension GoalPriorityX on GoalPriority {
  String get label => switch (this) {
        GoalPriority.high => 'High',
        GoalPriority.medium => 'Medium',
        GoalPriority.low => 'Low',
      };

  Color get color => switch (this) {
        GoalPriority.high => AppColors.clay,
        GoalPriority.medium => AppColors.brass,
        GoalPriority.low => AppColors.vizTeal,
      };

  /// Used to split spare savings capacity across goals.
  double get weight => switch (this) {
        GoalPriority.high => 3,
        GoalPriority.medium => 2,
        GoalPriority.low => 1,
      };
}

/// A thing the user is saving towards.
class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.cost,
    required this.saved,
    required this.targetDate,
    required this.createdAt,
    this.priority = GoalPriority.medium,
    this.milestonesUnlocked = const <int>[],
    this.completedAt,
    this.note = '',
  });

  final String id;
  final String name;
  final double cost;
  final double saved;
  final DateTime targetDate;
  final DateTime createdAt;
  final GoalPriority priority;

  /// Percentages already celebrated, so a milestone only fires once.
  final List<int> milestonesUnlocked;

  final DateTime? completedAt;
  final String note;

  double get progress =>
      cost <= 0 ? 0 : (saved / cost).clamp(0.0, 1.0).toDouble();

  int get progressPercent => (progress * 100).round();

  double get remaining => math.max(0.0, cost - saved);

  bool get isComplete => cost > 0 && saved >= cost;

  /// Days left until the target date. Negative once the date has passed.
  int daysRemaining(DateTime now) => Dates.daysBetween(now, targetDate);

  bool isOverdue(DateTime now) => !isComplete && daysRemaining(now) < 0;

  Goal copyWith({
    String? id,
    String? name,
    double? cost,
    double? saved,
    DateTime? targetDate,
    DateTime? createdAt,
    GoalPriority? priority,
    List<int>? milestonesUnlocked,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? note,
  }) =>
      Goal(
        id: id ?? this.id,
        name: name ?? this.name,
        cost: cost ?? this.cost,
        saved: saved ?? this.saved,
        targetDate: targetDate ?? this.targetDate,
        createdAt: createdAt ?? this.createdAt,
        priority: priority ?? this.priority,
        milestonesUnlocked: milestonesUnlocked ?? this.milestonesUnlocked,
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'cost': cost,
        'saved': saved,
        'targetDate': targetDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'priority': priority.name,
        'milestonesUnlocked': milestonesUnlocked,
        'completedAt': completedAt?.toIso8601String(),
        'note': note,
      };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: J.asString(json['id']),
        name: J.asString(json['name'], 'Goal'),
        cost: J.asDouble(json['cost']),
        saved: J.asDouble(json['saved']),
        targetDate: J.asDate(json['targetDate']),
        createdAt: J.asDate(json['createdAt']),
        priority:
            J.asEnum(json['priority'], GoalPriority.values, GoalPriority.medium),
        milestonesUnlocked: J.asIntList(json['milestonesUnlocked']),
        completedAt: J.asDateOrNull(json['completedAt']),
        note: J.asString(json['note']),
      );
}
