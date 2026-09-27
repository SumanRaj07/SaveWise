import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/setup_screen.dart';
import 'state/app_state.dart';

class SaveWiseApp extends StatelessWidget {
  const SaveWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      // A finance app has a lot of numbers in fixed-width rows. Allowing
      // unlimited system text scaling breaks them; clamping keeps large-text
      // settings working without destroying the layout.
      builder: (BuildContext context, Widget? child) =>
          MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _Root(),
    );
  }
}

/// Decides what the user sees first. There is no login to route around: either
/// the four setup questions have been answered, or they have not.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();

    final Widget child;
    if (!state.ready) {
      child = const _Splash(key: ValueKey<String>('splash'));
    } else if (!state.isSetupComplete) {
      child = const SetupScreen(key: ValueKey<String>('setup'));
    } else {
      child = const MainShell(key: ValueKey<String>('shell'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget widget, Animation<double> animation) =>
          FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: widget,
        ),
      ),
      child: child,
    );
  }
}

/// Shown only if storage is unusually slow. Deliberately quiet — a splash
/// screen that begs for attention on every launch gets old fast.
class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.emeraldSweep),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  size: 34,
                  color: AppColors.textOnAccent,
                ),
              ),
              const SizedBox(height: 20),
              Text(AppConstants.appName, style: AppTextStyles.screenTitle),
              const SizedBox(height: 6),
              Text(
                AppConstants.tagline,
                style: AppTextStyles.small.copyWith(
                  color: AppColors.textOnAccent.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
