import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// One weighted arc of the score ring.
class RingSegment {
  const RingSegment({
    required this.weight,
    required this.fill,
    required this.color,
  });

  /// Relative length of this arc.
  final double weight;

  /// How much of the arc is earned, 0–1.
  final double fill;

  final Color color;
}

/// The signature element: the financial health score.
///
/// It is drawn as four arcs, not one, so the ring shows *where* the score comes
/// from. Savings rate takes 30% of the circumference, budget discipline 25%,
/// emergency fund 25%, goals 20% — the brief's weights, made visible. Each arc
/// fills independently, so a glance tells you which quarter of the circle is
/// letting you down.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    required this.segments,
    this.label,
    this.caption,
    this.size = 208,
    this.strokeWidth = 15,
    this.color,
    this.animate = true,
  });

  final int score;
  final List<RingSegment> segments;
  final String? label;
  final String? caption;
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? AppColors.forScore(score);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: animate ? 1100 : 0),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ScoreRingPainter(
              segments: segments,
              progress: t,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${(score * t).round()}',
                    style: AppTextStyles.moneyHero.copyWith(
                      color: tint,
                      fontSize: size * 0.24,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('OUT OF 100', style: AppTextStyles.label),
                  if (label != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      label!,
                      style: AppTextStyles.bodyStrong.copyWith(color: tint),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (caption != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(caption!, style: AppTextStyles.small),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter({
    required this.segments,
    required this.progress,
    required this.strokeWidth,
  });

  final List<RingSegment> segments;
  final double progress;
  final double strokeWidth;

  static const double _gap = 0.055;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: centre, radius: radius);

    double totalWeight = 0;
    for (final RingSegment s in segments) {
      totalWeight += s.weight;
    }
    if (totalWeight <= 0) {
      _drawArc(canvas, rect, -math.pi / 2, math.pi * 2, AppColors.hairline);
      return;
    }

    final double usable = math.pi * 2 - _gap * segments.length;
    double start = -math.pi / 2 + _gap / 2;

    for (final RingSegment s in segments) {
      final double sweep = usable * (s.weight / totalWeight);
      // Track first, so an empty arc still shows the space available.
      _drawArc(canvas, rect, start, sweep, AppColors.hairline);
      final double filled = sweep * s.fill.clamp(0.0, 1.0) * progress;
      if (filled > 0.001) {
        _drawArc(canvas, rect, start, filled, s.color, glow: true);
      }
      start += sweep + _gap;
    }
  }

  void _drawArc(
    Canvas canvas,
    Rect rect,
    double start,
    double sweep,
    Color color, {
    bool glow = false,
  }) {
    if (glow) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.segments.length != segments.length ||
      _fillsDiffer(old.segments, segments);

  static bool _fillsDiffer(List<RingSegment> a, List<RingSegment> b) {
    for (int i = 0; i < a.length && i < b.length; i++) {
      if (a[i].fill != b[i].fill || a[i].color != b[i].color) return true;
    }
    return false;
  }
}

/// A single-value ring. Used for goals, the emergency fund and budget usage.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 92,
    this.strokeWidth = 8,
    this.color,
    this.trackColor,
    this.child,
    this.animate = true,
    this.showPercent = false,
  });

  /// 0–1. Values above 1 are clamped, because a ring cannot lap itself.
  final double progress;

  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? child;
  final bool animate;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? AppColors.emerald;
    final double target = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: Duration(milliseconds: animate ? 850 : 0),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ProgressRingPainter(
            progress: value,
            color: tint,
            track: trackColor ?? AppColors.hairline,
            strokeWidth: strokeWidth,
          ),
          child: Center(
            child: child ??
                (showPercent
                    ? Text(
                        '${(value * 100).round()}%',
                        style: AppTextStyles.numericSmall.copyWith(
                          color: tint,
                          fontSize: size * 0.2,
                        ),
                      )
                    : const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: centre, radius: radius);

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: <Color>[color.withValues(alpha: 0.55), color],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}

/// Tiny ring for list rows, where a full progress bar would be too much.
class MiniRing extends StatelessWidget {
  const MiniRing({
    super.key,
    required this.progress,
    this.size = 38,
    this.color,
    this.icon,
  });

  final double progress;
  final double size;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? AppColors.emerald;
    return ProgressRing(
      progress: progress,
      size: size,
      strokeWidth: 3.5,
      color: tint,
      child: icon != null
          ? Icon(icon, size: size * 0.4, color: tint)
          : Text(
              '${(progress.clamp(0.0, 1.0) * 100).round()}',
              style: AppTextStyles.numericSmall.copyWith(
                fontSize: size * 0.28,
                color: tint,
              ),
            ),
    );
  }
}
