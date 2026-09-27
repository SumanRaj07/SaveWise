import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

/// Charts are drawn by hand with `CustomPainter` rather than pulled from a
/// charting package. Two reasons: the app must work with no network and a
/// minimal dependency surface, and these five shapes are the only ones it
/// needs. Nothing here allocates per frame beyond the paths it draws.

class ChartSlice {
  const ChartSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class BarDatum {
  const BarDatum({
    required this.label,
    required this.value,
    this.color,
    this.secondary,
  });

  final String label;
  final double value;
  final Color? color;

  /// Drawn as a fainter bar behind the main one — the plan behind the actual.
  final double? secondary;
}

class LineSeries {
  const LineSeries({
    required this.values,
    required this.color,
    this.label = '',
    this.fill = false,
  });

  final List<double> values;
  final Color color;
  final String label;
  final bool fill;
}

/// Budget breakdown. A donut rather than a pie because the hole is useful: it
/// holds the total, which is the number people actually want.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.size = 168,
    this.thickness = 26,
    this.centreLabel,
    this.centreValue,
  });

  final List<ChartSlice> slices;
  final double size;
  final double thickness;
  final String? centreLabel;
  final String? centreValue;

  @override
  Widget build(BuildContext context) {
    final List<ChartSlice> visible = slices
        .where((ChartSlice s) => s.value > 0)
        .toList(growable: false);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(
            slices: visible,
            thickness: thickness,
            progress: t,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (centreValue != null)
                  Text(
                    centreValue!,
                    style: AppTextStyles.moneySmall,
                    textAlign: TextAlign.center,
                  ),
                if (centreLabel != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(centreLabel!, style: AppTextStyles.label),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.thickness,
    required this.progress,
  });

  final List<ChartSlice> slices;
  final double thickness;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) - thickness) / 2;
    final Rect rect = Rect.fromCircle(center: centre, radius: radius);

    double total = 0;
    for (final ChartSlice s in slices) {
      total += s.value;
    }

    if (total <= 0) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = AppColors.hairline
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness,
      );
      return;
    }

    const double gap = 0.03;
    final double usable = math.pi * 2 - gap * slices.length;
    double start = -math.pi / 2;

    for (final ChartSlice s in slices) {
      final double sweep = usable * (s.value / total) * progress;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.thickness != thickness ||
      old.slices.length != slices.length;
}

/// Legend for the donut. Kept separate so it can wrap freely beside or below
/// the chart depending on the width available.
class ChartLegend extends StatelessWidget {
  const ChartLegend({
    super.key,
    required this.slices,
    this.trailingBuilder,
  });

  final List<ChartSlice> slices;
  final String Function(ChartSlice slice)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final ChartSlice s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.label,
                    style: AppTextStyles.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailingBuilder != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    trailingBuilder!(s),
                    style: AppTextStyles.numericSmall,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Vertical bars with labels underneath. Used for monthly trends and the
/// interest-per-year breakdown.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.bars,
    this.height = 150,
    this.color,
    this.valueFormatter,
    this.showValues = true,
  });

  final List<BarDatum> bars;
  final double height;
  final Color? color;
  final String Function(double value)? valueFormatter;
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return SizedBox(height: height);

    double peak = 0;
    for (final BarDatum b in bars) {
      peak = math.max(peak, b.value);
      if (b.secondary != null) peak = math.max(peak, b.secondary!);
    }
    if (peak <= 0) peak = 1;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 820),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? _) => SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            for (final BarDatum b in bars)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      if (showValues && b.value > 0)
                        Text(
                          valueFormatter?.call(b.value) ??
                              b.value.toStringAsFixed(0),
                          style: AppTextStyles.label.copyWith(fontSize: 9),
                          maxLines: 1,
                        ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints c) {
                            final double full = c.maxHeight;
                            final double main = full * (b.value / peak) * t;
                            final double behind = b.secondary == null
                                ? 0
                                : full * (b.secondary! / peak) * t;
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: <Widget>[
                                Container(
                                  height: full,
                                  decoration: BoxDecoration(
                                    color: AppColors.hairlineSoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                if (behind > 0)
                                  Container(
                                    height: behind,
                                    decoration: BoxDecoration(
                                      color: AppColors.hairline,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                Container(
                                  height: main < 2 && b.value > 0 ? 2 : main,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: <Color>[
                                        (b.color ?? color ?? AppColors.emerald)
                                            .withValues(alpha: 0.55),
                                        b.color ?? color ?? AppColors.emerald,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        b.label,
                        style: AppTextStyles.label.copyWith(fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Trend lines: savings, expenses, health score over time.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.series,
    this.labels = const <String>[],
    this.height = 160,
    this.minY,
    this.maxY,
    this.yLabelFormatter,
  });

  final List<LineSeries> series;
  final List<String> labels;
  final double height;
  final double? minY;
  final double? maxY;
  final String Function(double value)? yLabelFormatter;

  @override
  Widget build(BuildContext context) {
    double lo = minY ?? double.infinity;
    double hi = maxY ?? -double.infinity;
    for (final LineSeries s in series) {
      for (final double v in s.values) {
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
    if (!lo.isFinite || !hi.isFinite) {
      lo = 0;
      hi = 1;
    }
    if (hi - lo < 0.0001) {
      hi = lo + 1;
    }
    // A little headroom so the top of the line is not welded to the frame.
    final double pad = (hi - lo) * 0.12;
    final double top = maxY ?? hi + pad;
    final double bottom = minY ?? math.max(0.0, lo - pad);

    return Column(
      children: <Widget>[
        SizedBox(
          height: height,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 44,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      yLabelFormatter?.call(top) ?? top.toStringAsFixed(0),
                      style: AppTextStyles.label.copyWith(fontSize: 9),
                    ),
                    Text(
                      yLabelFormatter?.call((top + bottom) / 2) ??
                          ((top + bottom) / 2).toStringAsFixed(0),
                      style: AppTextStyles.label.copyWith(fontSize: 9),
                    ),
                    Text(
                      yLabelFormatter?.call(bottom) ?? bottom.toStringAsFixed(0),
                      style: AppTextStyles.label.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 950),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double t, Widget? _) =>
                      CustomPaint(
                    painter: _LinePainter(
                      series: series,
                      minY: bottom,
                      maxY: top,
                      progress: t,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (labels.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (final String l in labels)
                  Text(l, style: AppTextStyles.label.copyWith(fontSize: 9)),
              ],
            ),
          ),
        ],
        if (series.any((LineSeries s) => s.label.isNotEmpty)) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: <Widget>[
              for (final LineSeries s in series)
                if (s.label.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 14,
                        height: 3,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(s.label, style: AppTextStyles.small),
                    ],
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.series,
    required this.minY,
    required this.maxY,
    required this.progress,
  });

  final List<LineSeries> series;
  final double minY;
  final double maxY;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = AppColors.hairlineSoft
      ..strokeWidth = 1;
    for (int i = 0; i <= 2; i++) {
      final double y = size.height * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final double span = maxY - minY;
    for (final LineSeries s in series) {
      if (s.values.length < 2) {
        if (s.values.length == 1) {
          final double y =
              size.height - ((s.values.first - minY) / span) * size.height;
          canvas.drawCircle(
            Offset(size.width / 2, y),
            3.5,
            Paint()..color = s.color,
          );
        }
        continue;
      }

      final int count = s.values.length;
      final double step = size.width / (count - 1);
      final Path path = Path();
      final List<Offset> points = <Offset>[];

      for (int i = 0; i < count; i++) {
        final double x = step * i;
        final double norm = ((s.values[i] - minY) / span).clamp(0.0, 1.0);
        final double y = size.height - norm * size.height * progress -
            (1 - progress) * size.height * 0;
        points.add(Offset(x, y));
      }

      path.moveTo(points.first.dx, points.first.dy);
      // Catmull-Rom style smoothing: midpoint control gives a soft curve
      // without the overshoot a naive cubic through every point produces.
      for (int i = 1; i < points.length; i++) {
        final Offset previous = points[i - 1];
        final Offset current = points[i];
        final double midX = (previous.dx + current.dx) / 2;
        path.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
      }

      if (s.fill) {
        final Path area = Path.from(path)
          ..lineTo(points.last.dx, size.height)
          ..lineTo(points.first.dx, size.height)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                s.color.withValues(alpha: 0.26),
                s.color.withValues(alpha: 0.02),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // Mark the latest point: it is the one the user came to see.
      canvas.drawCircle(points.last, 4, Paint()..color = s.color);
      canvas.drawCircle(
        points.last,
        4,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.progress != progress ||
      old.minY != minY ||
      old.maxY != maxY ||
      old.series.length != series.length;
}

/// Horizontal budget bar with an optional pace marker.
///
/// The marker is the point a steady spender would have reached by today. It is
/// the difference between "you have used 70%" and "you have used 70% on day
/// ten", which are not remotely the same situation.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.height = 8,
    this.marker,
    this.overflowColor,
    this.animate = true,
  });

  final double progress;
  final Color? color;
  final double height;
  final double? marker;
  final Color? overflowColor;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final bool over = progress > 1;
    final Color tint = over
        ? (overflowColor ?? AppColors.clay)
        : (color ?? AppColors.emerald);
    final double shown = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double width = c.maxWidth;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: shown),
          duration: Duration(milliseconds: animate ? 700 : 0),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double value, Widget? _) => SizedBox(
            height: height,
            width: width,
            child: Stack(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.hairlineSoft,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[tint.withValues(alpha: 0.65), tint],
                      ),
                      borderRadius: BorderRadius.circular(height),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: tint.withValues(alpha: 0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                if (marker != null && marker! > 0 && marker! < 1)
                  Positioned(
                    left: (width * marker!.clamp(0.0, 1.0)) - 1,
                    top: -2,
                    bottom: -2,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A labelled row with a bar under it. The planner is mostly made of these.
class LabelledBar extends StatelessWidget {
  const LabelledBar({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    this.color,
    this.icon,
    this.marker,
    this.footnote,
    this.onTap,
  });

  final String label;
  final String value;
  final double progress;
  final Color? color;
  final IconData? icon;
  final double? marker;
  final String? footnote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(value, style: AppTextStyles.numericSmall),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(progress: progress, color: color, marker: marker),
          if (footnote != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(footnote!, style: AppTextStyles.small),
          ],
        ],
      ),
    );

    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: body,
    );
  }
}
