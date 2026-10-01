import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class SleepWindowDial extends StatefulWidget {
  final int bedtimeMinutes;
  final int wakeMinutes;
  final String targetLabel;
  final void Function(int bedtimeMinutes, int wakeMinutes) onSaved;

  const SleepWindowDial({
    super.key,
    required this.bedtimeMinutes,
    required this.wakeMinutes,
    required this.targetLabel,
    required this.onSaved,
  });

  @override
  State<SleepWindowDial> createState() => _SleepWindowDialState();
}

class _SleepWindowDialState extends State<SleepWindowDial> {
  late int _bedtime;
  late int _wake;
  _DialHandle? _activeHandle;

  @override
  void initState() {
    super.initState();
    _bedtime = widget.bedtimeMinutes;
    _wake = widget.wakeMinutes;
  }

  @override
  void didUpdateWidget(covariant SleepWindowDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeHandle != null) return;
    if (oldWidget.bedtimeMinutes != widget.bedtimeMinutes) {
      _bedtime = widget.bedtimeMinutes;
    }
    if (oldWidget.wakeMinutes != widget.wakeMinutes) {
      _wake = widget.wakeMinutes;
    }
  }

  int get _plannedMinutes {
    final raw = _wake - _bedtime;
    return raw > 0 ? raw : raw + (24 * 60);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = math.min(constraints.maxWidth, 292.0);
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    _activeHandle = _nearestHandle(details.localPosition, size);
                    _updateFromPosition(details.localPosition, size);
                  },
                  onPanUpdate: (details) =>
                      _updateFromPosition(details.localPosition, size),
                  onPanEnd: (_) {
                    final bed = _bedtime;
                    final wake = _wake;
                    _activeHandle = null;
                    widget.onSaved(bed, wake);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _SleepDialPainter(
                          bedtimeMinutes: _bedtime,
                          wakeMinutes: _wake,
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'PLANNED SLEEP',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _durationLabel(_plannedMinutes),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 31,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.7,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Target ${widget.targetLabel}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _TimeCard(
                icon: Icons.bedtime_rounded,
                color: AppTheme.purple,
                label: 'Bedtime',
                value: _clockLabel(_bedtime),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeCard(
                icon: Icons.wb_sunny_rounded,
                color: AppTheme.amber,
                label: 'Wake',
                value: _clockLabel(_wake),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const Text(
          'Drag either handle around the ring. Times snap to 15-minute increments.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  _DialHandle _nearestHandle(Offset point, double size) {
    final minutes = _minutesFromPosition(point, size);
    final bedDistance = _circularMinuteDistance(minutes, _bedtime);
    final wakeDistance = _circularMinuteDistance(minutes, _wake);
    return bedDistance <= wakeDistance ? _DialHandle.bedtime : _DialHandle.wake;
  }

  void _updateFromPosition(Offset point, double size) {
    if (_activeHandle == null) return;
    final minutes = _minutesFromPosition(point, size);
    setState(() {
      if (_activeHandle == _DialHandle.bedtime) {
        _bedtime = minutes;
      } else {
        _wake = minutes;
      }
    });
  }

  int _minutesFromPosition(Offset point, double size) {
    final center = Offset(size / 2, size / 2);
    final vector = point - center;
    var angle = math.atan2(vector.dy, vector.dx) + (math.pi / 2);
    if (angle < 0) angle += math.pi * 2;
    final raw = angle / (math.pi * 2) * (24 * 60);
    final snapped = (raw / 15).round() * 15;
    return snapped % (24 * 60);
  }

  int _circularMinuteDistance(int a, int b) {
    final diff = (a - b).abs();
    return math.min(diff, (24 * 60) - diff);
  }

  String _durationLabel(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }

  String _clockLabel(int minutes) {
    final hour24 = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }
}

enum _DialHandle { bedtime, wake }

class _SleepDialPainter extends CustomPainter {
  final int bedtimeMinutes;
  final int wakeMinutes;

  const _SleepDialPainter({
    required this.bedtimeMinutes,
    required this.wakeMinutes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 25;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.surfaceHigh;
    canvas.drawCircle(center, radius, basePaint);

    final start = _angleForMinutes(bedtimeMinutes);
    final duration = _plannedMinutes(bedtimeMinutes, wakeMinutes);
    final sweep = duration / (24 * 60) * math.pi * 2;

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          AppTheme.purple,
          AppTheme.cyan,
          AppTheme.mint,
          AppTheme.purple,
        ],
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, activePaint);

    final tickPaint = Paint()
      ..strokeWidth = 1.5
      ..color = AppTheme.textMuted.withValues(alpha: 0.45);
    for (var hour = 0; hour < 24; hour++) {
      final angle = _angleForMinutes(hour * 60);
      final outer = Offset(
        center.dx + math.cos(angle) * (radius + 17),
        center.dy + math.sin(angle) * (radius + 17),
      );
      final innerLength = hour % 6 == 0 ? 9.0 : 5.0;
      final inner = Offset(
        center.dx + math.cos(angle) * (radius + 17 - innerLength),
        center.dy + math.sin(angle) * (radius + 17 - innerLength),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    _drawHandle(canvas, center, radius, bedtimeMinutes, AppTheme.purple);
    _drawHandle(canvas, center, radius, wakeMinutes, AppTheme.amber);
  }

  void _drawHandle(
    Canvas canvas,
    Offset center,
    double radius,
    int minutes,
    Color color,
  ) {
    final angle = _angleForMinutes(minutes);
    final point = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
    canvas.drawCircle(
      point,
      13,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppTheme.background,
    );
    canvas.drawCircle(
      point,
      9,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  double _angleForMinutes(int minutes) =>
      (minutes / (24 * 60) * math.pi * 2) - (math.pi / 2);

  int _plannedMinutes(int bedtime, int wake) {
    final raw = wake - bedtime;
    return raw > 0 ? raw : raw + (24 * 60);
  }

  @override
  bool shouldRepaint(covariant _SleepDialPainter oldDelegate) =>
      oldDelegate.bedtimeMinutes != bedtimeMinutes ||
      oldDelegate.wakeMinutes != wakeMinutes;
}

class _TimeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _TimeCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
