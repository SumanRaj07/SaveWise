import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/achievement_catalog.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../domain/engines/advice.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'achievements_screen.dart';
import 'advisor_screen.dart';
import 'bills_screen.dart';
import 'calculator_screen.dart';
import 'challenges_screen.dart';
import 'dashboard_screen.dart';
import 'emergency_screen.dart';
import 'goals_screen.dart';
import 'planner_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';

/// The five-tab frame the brief specifies: Home, Goals, Challenges, Calculator,
/// Profile. Everything else — planner, emergency fund, bills, advisor, reports,
/// achievements — is pushed on top, reached from the dashboard or the profile.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  AppState? _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _state!.addListener(_onStateChanged);
    // Screens pushed on top of the shell sit outside ShellScope's subtree, so
    // they cannot reach it through the element tree. Hand ShellNav a direct way
    // in for those cases.
    ShellNav.tabSwitcher = _select;
    // Anything queued during bootstrap (a rolled-over month, a backfilled
    // challenge) is waiting to be shown.
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainQueues());
  }

  @override
  void dispose() {
    ShellNav.tabSwitcher = null;
    _state?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainQueues());
  }

  /// Celebrations and one-line notices are pulled out of [AppState] rather than
  /// pushed by it. State should not know what a snackbar is.
  void _drainQueues() {
    if (!mounted) return;
    final AppState state = context.read<AppState>();

    final String? flash = state.takeFlash();
    if (flash != null && flash.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(flash, style: AppTextStyles.body),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 96),
          ),
        );
    }

    final List<AchievementDef> unlocked = state.takeCelebrations();
    if (unlocked.isNotEmpty) {
      HapticFeedback.mediumImpact();
      _celebrate(unlocked);
    }
  }

  Future<void> _celebrate(List<AchievementDef> badges) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (BuildContext context) => _BadgeDialog(badges: badges),
    );
  }

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return ShellScope(
      goToTab: _select,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: const <Widget>[
            DashboardScreen(),
            GoalsScreen(),
            ChallengesScreen(),
            CalculatorScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: _BottomBar(index: _index, onSelect: _select),
      ),
    );
  }
}

/// Lets any descendant switch tabs without a global navigator key.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.goToTab,
    required super.child,
  });

  final void Function(int index) goToTab;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// Tab indices, named so call sites read as intent rather than as magic numbers.
abstract final class ShellTab {
  static const int home = 0;
  static const int goals = 1;
  static const int challenges = 2;
  static const int calculator = 3;
  static const int profile = 4;
}

/// Turns an [AdviceAction] from the engines into actual navigation. The engines
/// decide *what* should happen next; this is the only place that knows how.
abstract final class ShellNav {
  /// Set by [MainShell] while it is mounted. Screens pushed above the shell are
  /// outside [ShellScope]'s subtree, so this is the only route back to the tabs.
  static void Function(int index)? tabSwitcher;

  static void go(BuildContext context, AdviceAction action) {
    switch (action) {
      case AdviceAction.none:
        return;
      case AdviceAction.openGoals:
        tab(context, ShellTab.goals);
      case AdviceAction.openChallenges:
        tab(context, ShellTab.challenges);
      case AdviceAction.openCalculator:
        tab(context, ShellTab.calculator);
      case AdviceAction.openPlanner:
        push(context, const PlannerScreen());
      case AdviceAction.logExpense:
        push(context, const PlannerScreen(openLogSheet: true));
      case AdviceAction.openEmergency:
        push(context, const EmergencyScreen());
      case AdviceAction.openBills:
        push(context, const BillsScreen());
    }
  }

  /// Switch to a bottom-bar tab from anywhere. If the caller is a pushed screen
  /// we unwind back to the shell first, otherwise the tab would change behind a
  /// full-screen route and nothing would appear to happen.
  static void tab(BuildContext context, int index) {
    final ShellScope? scope = ShellScope.maybeOf(context);
    if (scope != null) {
      scope.goToTab(index);
      return;
    }
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    tabSwitcher?.call(index);
  }

  static Future<void> push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (BuildContext context) => screen),
      );

  static Future<void> planner(BuildContext context) =>
      push(context, const PlannerScreen());

  static Future<void> emergency(BuildContext context) =>
      push(context, const EmergencyScreen());

  static Future<void> bills(BuildContext context) =>
      push(context, const BillsScreen());

  static Future<void> advisor(BuildContext context) =>
      push(context, const AdvisorScreen());

  static Future<void> reports(BuildContext context) =>
      push(context, const ReportsScreen());

  static Future<void> achievements(BuildContext context) =>
      push(context, const AchievementsScreen());
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect});

  final int index;
  final void Function(int index) onSelect;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem('Home', Icons.dashboard_rounded, Icons.dashboard_outlined),
    _NavItem('Goals', Icons.flag_rounded, Icons.flag_outlined),
    _NavItem('Streaks', Icons.bolt_rounded, Icons.bolt_outlined),
    _NavItem('Tools', Icons.calculate_rounded, Icons.calculate_outlined),
    _NavItem('Profile', Icons.person_rounded, Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 10,
      ),
      decoration: const BoxDecoration(
        // A solid top edge instead of a blur: the bar sits over a dark
        // scrolling list, and a hairline reads more cleanly than frosted glass.
        color: AppColors.inkLift,
        border: Border(top: BorderSide(color: AppColors.hairlineSoft)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, -6)),
        ],
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _items.length; i++)
            Expanded(
              child: _NavButton(
                item: _items[i],
                selected: i == index,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.active, this.inactive);

  final String label;
  final IconData active;
  final IconData inactive;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.emerald.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Icon(
                selected ? item.active : item.inactive,
                size: 21,
                color: selected ? AppColors.emerald : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: AppTextStyles.label.copyWith(
                fontSize: 9.5,
                color: selected ? AppColors.emeraldSoft : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge unlock celebration. Loud on purpose — it is the only moment in the app
/// that interrupts the user, and it only fires on something they earned.
class _BadgeDialog extends StatelessWidget {
  const _BadgeDialog({required this.badges});

  final List<AchievementDef> badges;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        accent: AppColors.brass,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF16211C), Color(0xFF0C1114)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              badges.length == 1 ? 'Badge unlocked' : '${badges.length} badges unlocked',
              style: AppTextStyles.label.copyWith(color: AppColors.brass),
            ),
            const SizedBox(height: 18),
            for (final AchievementDef badge in badges)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        gradient: AppColors.brassSweep,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: badge.accent.withValues(alpha: 0.34),
                            blurRadius: 26,
                          ),
                        ],
                      ),
                      child: Icon(
                        badge.icon,
                        size: 30,
                        color: AppColors.textOnAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      badge.title,
                      style: AppTextStyles.cardTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      badge.detail,
                      style: AppTextStyles.small,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            PrimaryButton(
              label: 'Nice',
              gradient: AppColors.brassSweep,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
