import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

/// The app's one container. Everything sits on one of these.
///
/// Glass here is a translucent gradient over a dark background plus a hairline
/// edge, not a `BackdropFilter`. Real blur costs a full-screen texture read per
/// card per frame, which on a mid-range phone shows up as dropped frames while
/// scrolling — and against a near-black background the two are visually
/// indistinguishable.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.accent,
    this.gradient,
    this.borderRadius,
    this.dim = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// Tints the edge and adds a soft glow. Used to mark state, never decoration.
  final Color? accent;

  final Gradient? gradient;
  final BorderRadius? borderRadius;

  /// Recedes the card, for anything complete or inactive.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(AppTheme.radiusCard);
    final Color edge = accent?.withValues(alpha: 0.34) ?? AppColors.hairline;

    final Widget body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.glassFill,
        borderRadius: radius,
        border: Border.all(color: edge),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          if (accent != null)
            BoxShadow(
              color: accent!.withValues(alpha: 0.10),
              blurRadius: 26,
              spreadRadius: -6,
            ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppTheme.cardPad),
        child: child,
      ),
    );

    final Widget content = dim ? Opacity(opacity: 0.62, child: body) : body;

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        borderRadius: radius,
        splashColor: (accent ?? AppColors.emerald).withValues(alpha: 0.08),
        highlightColor: (accent ?? AppColors.emerald).withValues(alpha: 0.04),
        child: content,
      ),
    );
  }
}

/// Title above a group of cards, with an optional action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.cardTitle),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTextStyles.small),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// A label, a number, and optionally one line of context under it.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.footnote,
    this.icon,
    this.accent,
    this.valueStyle,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? footnote;
  final IconData? icon;
  final Color? accent;
  final TextStyle? valueStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 13, color: accent ?? AppColors.textMuted),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: AppTextStyles.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          value,
          style: (valueStyle ??
                  (compact
                      ? AppTextStyles.moneySmall
                      : AppTextStyles.moneyMedium))
              .copyWith(color: accent),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (footnote != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            footnote!,
            style: AppTextStyles.small,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Small coloured capsule for a status word.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.filled = false,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.9 : 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: filled ? 0.9 : 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: 12,
              color: filled ? AppColors.textOnAccent : color,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: AppTextStyles.label.copyWith(
              color: filled ? AppColors.textOnAccent : color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// The main action. Gradient fill, pill shape, optional leading icon.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.gradient,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final Gradient? gradient;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !busy;

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (busy)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textOnAccent,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: AppColors.textOnAccent),
        if (busy || icon != null) const SizedBox(width: 9),
        Text(
          label,
          style: AppTextStyles.button.copyWith(color: AppColors.textOnAccent),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradient ?? AppColors.emeraldSweep,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.emerald.withValues(alpha: enabled ? 0.26 : 0.0),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 15,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary action.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: tint.withValues(alpha: 0.36)),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 16, color: tint),
                const SizedBox(width: 8),
              ],
              Text(label, style: AppTextStyles.button.copyWith(color: tint)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable capsule, used for categories, priorities and tabs.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? AppColors.emerald;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? tint.withValues(alpha: 0.16) : AppColors.slateHigh,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: selected ? tint.withValues(alpha: 0.7) : AppColors.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? tint : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.small.copyWith(
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown wherever a list is empty. Always says what to do next, because an
/// empty screen with no instruction is where people give up.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      child: Column(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.slateHigh,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.hairline),
            ),
            child: Icon(icon, color: AppColors.textMuted, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 20),
            PrimaryButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// A label on the left, a value on the right. The most common row in the app.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.strong = false,
    this.dense = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final bool strong;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 4 : 7),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: strong ? AppTextStyles.bodyStrong : AppTextStyles.body,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: (strong
                    ? AppTextStyles.moneySmall
                    : AppTextStyles.numericSmall)
                .copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

/// A short piece of advice with an icon and, sometimes, a button.
class AdviceTile extends StatelessWidget {
  const AdviceTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 4),
                Text(detail, style: AppTextStyles.small),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: 10),
                  GhostButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    color: color,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen frame: title, optional subtitle and actions, scrolling body with the
/// bottom bar's height accounted for.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions,
    this.showBack = false,
    this.floating,
    this.bottomInset = 96,
    this.header,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? floating;
  final double bottomInset;

  /// Rendered under the title, outside the scroll padding.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      floatingActionButton: floating,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                10,
              ),
              child: Row(
                children: <Widget>[
                  if (showBack) ...<Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: AppTextStyles.screenTitle),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(subtitle!, style: AppTextStyles.small),
                        ],
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            if (header != null) header!,
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  6,
                  AppTheme.gutter,
                  bottomInset,
                ),
                physics: const BouncingScrollPhysics(),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet used for every add and edit form in the app.
abstract final class AppSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.inkLift,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          left: AppTheme.gutter,
          right: AppTheme.gutter,
          top: 10,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(title, style: AppTextStyles.cardTitle),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.small),
              ],
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }

  /// Yes/no question with a destructive option.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    bool destructive = true,
  }) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.slateHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          side: const BorderSide(color: AppColors.hairline),
        ),
        title: Text(title, style: AppTextStyles.cardTitle),
        content: Text(message, style: AppTextStyles.body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor:
                  destructive ? AppColors.clay : AppColors.emerald,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return answer ?? false;
  }
}

/// Fades and lifts a child as a screen appears. Staggering the delay across a
/// column is what makes the dashboard feel assembled rather than dumped.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delayMs = 0,
  });

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final int total = 380 + delayMs;
    final double start = delayMs == 0 ? 0 : (delayMs / total).clamp(0.0, 0.9);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (BuildContext context, double t, Widget? _) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}
