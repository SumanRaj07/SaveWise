import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';

/// The dashboard clock, with running seconds as the brief asks for.
///
/// It keeps its own one-second timer instead of driving the whole app from a
/// global tick. Only this widget repaints each second; the dashboard's cards,
/// charts and rings are left alone, which is the difference between a smooth
/// screen and a stuttering one.
class LiveClock extends StatefulWidget {
  const LiveClock({
    super.key,
    this.style,
    this.showDate = false,
    this.alignment = CrossAxisAlignment.end,
  });

  final TextStyle? style;
  final bool showDate;
  final CrossAxisAlignment alignment;

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> with WidgetsBindingObserver {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No point counting seconds nobody can see.
    if (state == AppLifecycleState.resumed) {
      setState(() => _now = DateTime.now());
      _start();
    } else {
      _timer?.cancel();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: widget.alignment,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          Dates.clock(_now),
          style: widget.style ?? AppTextStyles.clock,
        ),
        if (widget.showDate) ...<Widget>[
          const SizedBox(height: 2),
          Text(Dates.longDate(_now), style: AppTextStyles.small),
        ],
      ],
    );
  }
}

/// Date and time on one line, for headers where vertical space is tight.
class DateTimeStrip extends StatelessWidget {
  const DateTimeStrip({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.calendar_today_rounded,
            size: 13, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(Dates.longDate(date), style: AppTextStyles.small),
        const SizedBox(width: 10),
        Container(width: 3, height: 3,
            decoration: const BoxDecoration(
              color: AppColors.textMuted,
              shape: BoxShape.circle,
            )),
        const SizedBox(width: 10),
        const LiveClock(alignment: CrossAxisAlignment.start),
      ],
    );
  }
}
