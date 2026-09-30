import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';

class SimpleBarChart extends StatelessWidget {
  final List<num> values;
  final double height;
  final bool showTarget;
  final double? target;
  final List<String>? labels;

  const SimpleBarChart({
    super.key,
    required this.values,
    this.height = 180,
    this.showTarget = false,
    this.target,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || values.every((v) => v == 0)) {
      return const EmptyChart(
        icon: Icons.bar_chart_rounded,
        label: 'No chart data yet',
      );
    }

    final maxValue = values
        .map((e) => e.toDouble())
        .reduce((a, b) => a > b ? a : b);
    final maxY = target != null
        ? (maxValue > target! ? maxValue : target!) * 1.15
        : maxValue * 1.15;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY <= 0 ? 1 : maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
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
}

class WeightTrendChart extends StatelessWidget {
  final List<WeightPoint> values;

  const WeightTrendChart({
    super.key,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const EmptyChart(
        icon: Icons.show_chart_rounded,
        label: 'Log or connect weight to build a trend',
      );
    }

    final sorted = [...values]..sort((a, b) => a.date.compareTo(b.date));
    final weights = sorted.map((e) => e.pounds).toList();
    var minY = weights.reduce((a, b) => a < b ? a : b) - 4;
    var maxY = weights.reduce((a, b) => a > b ? a : b) + 4;
    if ((maxY - minY) < 5) {
      minY -= 3;
      maxY += 3;
    }

    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: sorted.length == 1 ? 1 : (sorted.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  compactNumber(value),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              barWidth: 3,
              color: AppTheme.mint,
              spots: [
                for (var i = 0; i < sorted.length; i++)
                  FlSpot(i.toDouble(), sorted[i].pounds),
              ],
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.mint.withValues(alpha: 0.12),
              ),
              dotData: FlDotData(show: sorted.length <= 12),
            ),
          ],
        ),
      ),
    );
  }
}

class HeartTrendChart extends StatelessWidget {
  final List<HeartPoint> values;

  const HeartTrendChart({
    super.key,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const EmptyChart(
        icon: Icons.favorite_outline,
        label: 'No recent heart-rate samples',
      );
    }

    final bpm = values.map((e) => e.bpm).toList();
    final minY = (bpm.reduce((a, b) => a < b ? a : b) - 10).clamp(30, 220);
    final maxY = (bpm.reduce((a, b) => a > b ? a : b) + 10).clamp(40, 240);

    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: values.length == 1 ? 1 : (values.length - 1).toDouble(),
          minY: minY.toDouble(),
          maxY: maxY.toDouble(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              barWidth: 2.5,
              color: AppTheme.rose,
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i].bpm),
              ],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class SleepStageBar extends StatelessWidget {
  final int awake;
  final int rem;
  final int light;
  final int deep;

  const SleepStageBar({
    super.key,
    required this.awake,
    required this.rem,
    required this.light,
    required this.deep,
  });

  @override
  Widget build(BuildContext context) {
    final total = awake + rem + light + deep;
    if (total <= 0) {
      return const EmptyChart(
        icon: Icons.bedtime_outlined,
        label: 'No sleep-stage data available',
      );
    }

    Widget segment(int value, Color color) => Expanded(
          flex: value == 0 ? 1 : value,
          child: Container(color: value == 0 ? Colors.transparent : color),
        );

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 18,
            child: Row(
              children: [
                segment(awake, AppTheme.rose),
                segment(rem, AppTheme.purple),
                segment(light, AppTheme.cyan),
                segment(deep, AppTheme.blue),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _Legend('Awake', awake, AppTheme.rose),
            _Legend('REM', rem, AppTheme.purple),
            _Legend('Light', light, AppTheme.cyan),
            _Legend('Deep', deep, AppTheme.blue),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final int minutes;
  final Color color;

  const _Legend(this.label, this.minutes, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text('$label ${minutesLabel(minutes)}'),
      ],
    );
  }
}

class EmptyChart extends StatelessWidget {
  final IconData icon;
  final String label;

  const EmptyChart({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 34),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
