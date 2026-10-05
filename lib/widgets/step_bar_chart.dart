import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class StepBarChart extends StatelessWidget {
  final List<num> values;
  final double height;
  final double? target;
  final bool showTarget;
  final List<String>? labels;

  const StepBarChart({
    super.key,
    required this.values,
    this.height = 180,
    this.target,
    this.showTarget = false,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || values.every((value) => value == 0)) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 34),
            SizedBox(height: 8),
            Text('No chart data yet'),
          ],
        ),
      );
    }

    final maxValue = values
        .map((value) => value.toDouble())
        .reduce((a, b) => a > b ? a : b);
    final targetValue = target ?? 0;
    final rawMax = math.max(maxValue, targetValue);
    final axis = _axisFor(rawMax);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: axis.maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: axis.interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: axis.interval,
                reservedSize: 58,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value > axis.maxY) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      _stepLabel(value),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: labels != null && labels!.isNotEmpty,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  if (labels == null || labels!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final index = value.round();
                  if (index < 0 || index >= labels!.length) {
                    return const SizedBox.shrink();
                  }
                  final label = labels![index];
                  if (label.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: showTarget && target != null
              ? ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: target!,
                      color: AppTheme.mint.withValues(alpha: 0.65),
                      strokeWidth: 1.2,
                      dashArray: [5, 4],
                    ),
                  ],
                )
              : const ExtraLinesData(),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i].toDouble(),
                    width: values.length > 20 ? 7 : 16,
                    color: i == values.length - 1
                        ? AppTheme.mint
                        : AppTheme.cyan,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  _StepAxis _axisFor(double maxValue) {
    if (maxValue <= 0) {
      return const _StepAxis(maxY: 1000, interval: 250);
    }
    final padded = maxValue * 1.08;
    final rough = padded / 5;
    final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final normalized = rough / magnitude;
    final nice = normalized <= 1
        ? 1.0
        : normalized <= 2
            ? 2.0
            : normalized <= 2.5
                ? 2.5
                : normalized <= 5
                    ? 5.0
                    : 10.0;
    final interval = nice * magnitude;
    final maxY = (padded / interval).ceil() * interval;
    return _StepAxis(maxY: maxY, interval: interval);
  }

  String _stepLabel(double value) {
    if (value >= 1000000) {
      final number = value / 1000000;
      return '${number.toStringAsFixed(number >= 10 || number == number.roundToDouble() ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final number = value / 1000;
      return '${number.toStringAsFixed(number >= 10 || number == number.roundToDouble() ? 0 : 1)}K';
    }
    return value.round().toString();
  }
}

class _StepAxis {
  final double maxY;
  final double interval;

  const _StepAxis({required this.maxY, required this.interval});
}
