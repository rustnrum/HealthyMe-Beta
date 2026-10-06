import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/salus_widgets.dart';

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final h = app.health;

    final weights = [...h.weightHistory]
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        children: [
          const SalusSectionTitle(
            title: 'Your trends',
            eyebrow: 'Personal baseline over time',
          ),
          const SizedBox(height: 6),
          const Text(
            'Salus uses the history already available from your connected data. These charts do not invent missing readings.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _TrendCard(
            title: 'HRV',
            rangeLabel: 'Recent history',
            values: h.hrv30,
            current: h.hrvMs,
            accent: AppTheme.mint,
            formatValue: (value) => '${value.round()} ms',
            formatDelta: _signedPercentDelta,
          ),
          _TrendCard(
            title: 'Respiration',
            rangeLabel: 'Recent history',
            values: h.respiratoryRate30,
            current: h.respiratoryRate,
            accent: AppTheme.teal,
            formatValue: (value) => '${value.toStringAsFixed(1)} /min',
            formatDelta: (current, baseline) {
              final delta = current - baseline;
              return '${_signed(delta, 1)} /min vs baseline';
            },
          ),
          _TrendCard(
            title: 'Resting heart rate',
            rangeLabel: 'Recent history',
            values: h.restingHeartRate30,
            current: h.restingHeartRate,
            accent: AppTheme.rose,
            formatValue: (value) => '${value.round()} bpm',
            formatDelta: (current, baseline) {
              final delta = current - baseline;
              return '${_signed(delta, 1)} bpm vs baseline';
            },
          ),
          _TrendCard(
            title: 'Sleep',
            rangeLabel: 'Last 7 nights',
            values: h.sleepMinutes7.map((value) => value.toDouble()).toList(),
            current: h.sleepMinutes > 0 ? h.sleepMinutes.toDouble() : null,
            accent: AppTheme.blue,
            formatValue: _minutes,
            formatDelta: (current, baseline) {
              final delta = current - baseline;
              final sign = delta >= 0 ? '+' : '−';
              return '$sign${delta.abs().round()} min vs baseline';
            },
          ),
          _TrendCard(
            title: 'Steps',
            rangeLabel: 'Last 30 days',
            values: h.dailySteps30.map((value) => value.toDouble()).toList(),
            current: h.stepsToday > 0 ? h.stepsToday.toDouble() : null,
            accent: AppTheme.amber,
            formatValue: (value) => '${value.round()} steps',
            formatDelta: (current, baseline) {
              final delta = current - baseline;
              return '${_signed(delta, 0)} vs baseline';
            },
          ),
          _TrendCard(
            title: 'Weight',
            rangeLabel: 'Recorded history',
            values: weights.map((point) => point.pounds).toList(),
            current: app.currentWeightLb,
            accent: AppTheme.mint,
            formatValue: (value) => '${value.toStringAsFixed(1)} lb',
            formatDelta: (current, baseline) {
              final delta = current - baseline;
              return '${_signed(delta, 1)} lb vs baseline';
            },
          ),
        ],
      ),
    );
  }

  static String _signedPercentDelta(double current, double baseline) {
    if (baseline == 0) return 'Baseline unavailable';
    final pct = (current / baseline - 1) * 100;
    return '${_signed(pct, 0)}% vs baseline';
  }

  static String _signed(double value, int decimals) {
    final prefix = value >= 0 ? '+' : '−';
    return '$prefix${value.abs().toStringAsFixed(decimals)}';
  }

  static String _minutes(double value) {
    final total = value.round();
    return '${total ~/ 60}h ${total % 60}m';
  }
}

class _TrendCard extends StatelessWidget {
  final String title;
  final String rangeLabel;
  final List<double> values;
  final double? current;
  final Color accent;
  final String Function(double value) formatValue;
  final String Function(double current, double baseline) formatDelta;

  const _TrendCard({
    required this.title,
    required this.rangeLabel,
    required this.values,
    required this.current,
    required this.accent,
    required this.formatValue,
    required this.formatDelta,
  });

  @override
  Widget build(BuildContext context) {
    final clean = values.where((value) => value.isFinite && value > 0).toList();
    final latest = current ?? (clean.isEmpty ? null : clean.last);
    final baselineValues = clean.length > 1 ? clean.sublist(0, clean.length - 1) : clean;
    final baseline = baselineValues.isEmpty
        ? null
        : baselineValues.reduce((a, b) => a + b) / baselineValues.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SalusPaper(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rangeLabel,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  latest == null ? '—' : formatValue(latest),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              latest == null || baseline == null
                  ? 'Building your personal baseline'
                  : formatDelta(latest, baseline),
              style: TextStyle(
                color: latest == null || baseline == null
                    ? AppTheme.textMuted
                    : accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              width: double.infinity,
              child: clean.length < 2
                  ? const Center(
                      child: Text(
                        'More history is needed for a trend line.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : CustomPaint(
                      painter: _TrendPainter(values: clean, color: accent),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _TrendPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final rawSpread = maxValue - minValue;
    final spread = rawSpread.abs() < 1.0 ? 1.0 : rawSpread;
    final top = maxValue + spread * 0.12;
    final bottom = minValue - spread * 0.12;
    final rawRange = top - bottom;
    final range = rawRange.abs() < 1.0 ? 1.0 : rawRange;

    final gridPaint = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (final fraction in const [0.25, 0.5, 0.75]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final normalized = (values[i] - bottom) / range;
      final y = size.height - normalized * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final lastX = size.width;
    final lastNormalized = (values.last - bottom) / range;
    final lastY = size.height - lastNormalized * size.height;
    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
