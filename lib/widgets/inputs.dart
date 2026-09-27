import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

/// Form controls. Every screen that takes a number takes it through
/// [AmountField] so that parsing, keyboards and validation behave identically
/// whether the user is setting a salary, logging a coffee or sizing a loan.

/// A labelled slot. Keeps the label/field spacing consistent everywhere.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.trailing,
  });

  final String label;
  final Widget child;
  final String? hint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: AppTextStyles.labelBright)),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 8),
        child,
        if (hint != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(hint!, style: AppTextStyles.small),
        ],
      ],
    );
  }
}

/// Money input.
///
/// The keyboard is numeric-with-decimal, the currency symbol sits in the
/// prefix rather than in the user's typing, and grouping separators are
/// tolerated on the way in because people paste and type them out of habit.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.autofocus = false,
    this.allowZero = false,
    this.max,
    this.min,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.helper,
    this.enabled = true,
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final bool autofocus;
  final bool allowZero;
  final double? max;
  final double? min;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onSubmitted;
  final String? Function(double? value)? validator;
  final String? helper;
  final bool enabled;
  final TextInputAction textInputAction;

  /// Reads the field. Returns null when it cannot be parsed at all.
  static double? valueOf(TextEditingController controller) =>
      Money.parse(controller.text);

  @override
  Widget build(BuildContext context) {
    final Widget field = TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: textInputAction,
      style: AppTextStyles.moneySmall,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
        LengthLimitingTextInputFormatter(15),
      ],
      decoration: InputDecoration(
        hintText: hintText ?? '0',
        helperText: helper,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Text(
            Money.symbol,
            style: AppTextStyles.moneySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      onChanged: (String raw) => onChanged?.call(Money.parse(raw) ?? 0),
      onFieldSubmitted: (String raw) =>
          onSubmitted?.call(Money.parse(raw) ?? 0),
      validator: (String? raw) {
        final double? parsed = Money.parse(raw ?? '');
        if (validator != null) return validator!(parsed);
        if (parsed == null) return 'Enter an amount';
        if (!allowZero && parsed <= 0) return 'Enter an amount above zero';
        if (parsed < 0) return 'Cannot be negative';
        if (min != null && parsed < min!) {
          return 'Minimum ${Money.format(min!)}';
        }
        if (max != null && parsed > max!) {
          return 'Maximum ${Money.format(max!)}';
        }
        return null;
      },
    );

    if (label == null) return field;
    return LabeledField(label: label!, child: field);
  }
}

/// Plain text input, used for names and notes.
class TextInputBox extends StatelessWidget {
  const TextInputBox({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.maxLength,
    this.autofocus = false,
    this.required = false,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.onSubmitted,
    this.textInputAction = TextInputAction.next,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final int? maxLength;
  final bool autofocus;
  final bool required;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final Widget field = TextFormField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hintText,
        counterText: '',
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 18, color: AppColors.textMuted),
      ),
      onFieldSubmitted: onSubmitted,
      validator: required
          ? (String? raw) =>
              (raw == null || raw.trim().isEmpty) ? 'Required' : null
          : null,
    );

    if (label == null) return field;
    return LabeledField(label: label!, child: field);
  }
}

/// Day-of-month picker for the salary date and bill due dates.
///
/// A calendar would be the wrong control here: these are recurring days, not
/// dates. 29–31 are offered but flagged, since they do not exist every month;
/// the date helpers clamp them, and saying so up front avoids a surprise in
/// February.
class DayOfMonthField extends StatelessWidget {
  const DayOfMonthField({
    super.key,
    required this.day,
    required this.onChanged,
    this.label,
    this.helper,
  });

  final int day;
  final ValueChanged<int> onChanged;
  final String? label;
  final String? helper;

  static String ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  Future<void> _pick(BuildContext context) async {
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.inkLift,
      isScrollControlled: true,
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Pick a day', style: AppTextStyles.cardTitle),
              const SizedBox(height: 4),
              Text(
                'Repeats on this day every month.',
                style: AppTextStyles.small,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (int d = 1; d <= 31; d++)
                        _DayChip(
                          day: d,
                          selected: d == day,
                          onTap: () => Navigator.of(context).pop(d),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Days 29 to 31 shift to the last day in shorter months.',
                style: AppTextStyles.small,
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final Widget field = InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.slateHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.event_repeat_rounded,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${ordinal(day)} of every month',
                style: AppTextStyles.body,
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );

    if (label == null) return field;
    return LabeledField(label: label!, hint: helper, child: field);
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool risky = day > 28;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald : AppColors.slateHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.emerald : AppColors.hairline,
          ),
        ),
        child: Text(
          '$day',
          style: AppTextStyles.numericSmall.copyWith(
            color: selected
                ? AppColors.textOnAccent
                : risky
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Date field for goal target dates and one-off bills.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.helper,
    this.firstDate,
    this.lastDate,
    this.icon = Icons.calendar_month_rounded,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String? label;
  final String? helper;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final IconData icon;

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: firstDate ?? DateTime(now.year - 1),
      lastDate: lastDate ?? DateTime(now.year + 25),
      builder: (BuildContext context, Widget? child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                surface: AppColors.inkLift,
                onSurface: AppColors.textPrimary,
              ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final Widget field = InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.slateHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(Dates.longDate(value), style: AppTextStyles.body),
            ),
            const Icon(Icons.expand_more_rounded,
                size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );

    if (label == null) return field;
    return LabeledField(label: label!, hint: helper, child: field);
  }
}

/// Generic single-choice chip row. Used for goal priority, bill type,
/// calculator mode, report range — anywhere a dropdown would be heavier than
/// the choice deserves.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.label,
    this.iconOf,
    this.colorOf,
    this.scroll = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;
  final String? label;
  final IconData? Function(T value)? iconOf;
  final Color? Function(T value)? colorOf;

  /// Horizontal scroll instead of wrapping. Better for long lists like bill
  /// types, where wrapping produces a tall block of chips.
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[
      for (final T v in values)
        _Chip(
          label: labelOf(v),
          icon: iconOf?.call(v),
          accent: colorOf?.call(v) ?? AppColors.emerald,
          selected: v == selected,
          onTap: () => onChanged(v),
        ),
    ];

    final Widget body = scroll
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < chips.length; i++)
                  Padding(
                    padding: EdgeInsets.only(right: i == chips.length - 1 ? 0 : 8),
                    child: chips[i],
                  ),
              ],
            ),
          )
        : Wrap(spacing: 8, runSpacing: 8, children: chips);

    if (label == null) return body;
    return LabeledField(label: label!, child: body);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: icon == null ? 16 : 13,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : AppColors.slate,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: selected ? accent : AppColors.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 15,
                color: selected ? accent : AppColors.textMuted,
              ),
              const SizedBox(width: 7),
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
    );
  }
}

/// Percentage slider, used for the savings-rate target and calculator rates.
class RateSlider extends StatelessWidget {
  const RateSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.valueLabel,
    this.helper,
    this.accent,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String? label;
  final double min;
  final double max;
  final int? divisions;
  final String? valueLabel;
  final String? helper;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final double safe = value.isFinite ? value.clamp(min, max) : min;
    final Widget slider = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accent ?? AppColors.emerald,
            thumbColor: accent ?? AppColors.emerald,
          ),
          child: Slider(
            value: safe,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );

    if (label == null) return slider;
    return LabeledField(
      label: label!,
      hint: helper,
      trailing: Text(
        valueLabel ?? Money.percent(safe),
        style: AppTextStyles.numericSmall.copyWith(
          color: accent ?? AppColors.emerald,
        ),
      ),
      child: slider,
    );
  }
}

/// Two-line switch row, for the handful of on/off settings the app has.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppTextStyles.body),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: AppTextStyles.small),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Quick-amount buttons. Sits under an [AmountField] so a common figure is one
/// tap rather than six keystrokes.
class QuickAmounts extends StatelessWidget {
  const QuickAmounts({
    super.key,
    required this.amounts,
    required this.onPick,
  });

  final List<double> amounts;
  final ValueChanged<double> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final double a in amounts)
          InkWell(
            onTap: () => onPick(a),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.slate,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text(
                Money.compact(a),
                style: AppTextStyles.numericSmall,
              ),
            ),
          ),
      ],
    );
  }
}
