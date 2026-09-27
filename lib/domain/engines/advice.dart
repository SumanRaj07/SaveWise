import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Where a piece of advice sends you. The UI turns this into a button, so every
/// recommendation the app makes is one tap from being acted on.
enum AdviceAction {
  none,
  openPlanner,
  openEmergency,
  openGoals,
  openChallenges,
  openBills,
  openCalculator,
  logExpense,
}

extension AdviceActionX on AdviceAction {
  String get label => switch (this) {
        AdviceAction.none => '',
        AdviceAction.openPlanner => 'Open planner',
        AdviceAction.openEmergency => 'Open fund',
        AdviceAction.openGoals => 'Open goals',
        AdviceAction.openChallenges => 'Open challenges',
        AdviceAction.openBills => 'Open bills',
        AdviceAction.openCalculator => 'Open calculator',
        AdviceAction.logExpense => 'Log expense',
      };
}

enum AdviceSeverity { urgent, warning, nudge, praise }

extension AdviceSeverityX on AdviceSeverity {
  Color get color => switch (this) {
        AdviceSeverity.urgent => AppColors.clay,
        AdviceSeverity.warning => AppColors.brass,
        AdviceSeverity.nudge => AppColors.emeraldSoft,
        AdviceSeverity.praise => AppColors.emerald,
      };

  IconData get icon => switch (this) {
        AdviceSeverity.urgent => Icons.priority_high_rounded,
        AdviceSeverity.warning => Icons.warning_amber_rounded,
        AdviceSeverity.nudge => Icons.lightbulb_outline_rounded,
        AdviceSeverity.praise => Icons.check_circle_outline_rounded,
      };
}

/// One concrete thing to do, with the reason attached.
class Recommendation {
  const Recommendation({
    required this.title,
    required this.detail,
    required this.severity,
    this.action = AdviceAction.none,
    this.pointsAvailable = 0,
  });

  /// Imperative and specific: "Move 2,000 into your emergency fund".
  final String title;

  /// Why it matters, in one or two sentences.
  final String detail;

  final AdviceSeverity severity;
  final AdviceAction action;

  /// Health-score points this would unlock, when it came from the score.
  final int pointsAvailable;
}
