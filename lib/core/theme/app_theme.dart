import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  /// Corner radii. Cards are generously rounded; controls follow at 2/3.
  static const double radiusCard = 24;
  static const double radiusControl = 16;
  static const double radiusPill = 999;

  static const double gutter = 18;
  static const double cardPad = 18;

  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.ink,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData dark() {
    const ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.emerald,
      onPrimary: AppColors.textOnAccent,
      secondary: AppColors.brass,
      onSecondary: AppColors.textOnAccent,
      error: AppColors.clay,
      onError: AppColors.textPrimary,
      surface: AppColors.slate,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ink,
      canvasColor: AppColors.ink,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        headlineMedium: AppTextStyles.screenTitle,
        titleMedium: AppTextStyles.cardTitle,
        bodyMedium: AppTextStyles.body,
        labelSmall: AppTextStyles.label,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlay,
        titleTextStyle: AppTextStyles.cardTitle,
        iconTheme: IconThemeData(color: AppColors.textSecondary, size: 22),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.slateHigh,
        contentTextStyle: AppTextStyles.bodyStrong,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.inkLift,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0xB3000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slateHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        labelStyle: AppTextStyles.body,
        floatingLabelStyle:
            AppTextStyles.labelBright.copyWith(color: AppColors.emerald),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: AppColors.emerald, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: AppColors.clay),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: AppColors.clay, width: 1.4),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.emerald,
        inactiveTrackColor: AppColors.hairline,
        thumbColor: AppColors.emerald,
        overlayColor: Color(0x2218C07A),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
            s.contains(WidgetState.selected)
                ? AppColors.emerald
                : AppColors.textMuted),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) =>
            s.contains(WidgetState.selected)
                ? AppColors.emeraldDeep.withValues(alpha: 0.5)
                : AppColors.slateHigh),
        trackOutlineColor:
            const WidgetStatePropertyAll<Color>(AppColors.hairline),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.emerald,
        selectionColor: Color(0x4418C07A),
        selectionHandleColor: AppColors.emerald,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.emerald,
          textStyle: AppTextStyles.button,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
