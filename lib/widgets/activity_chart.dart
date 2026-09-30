import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ActivityChart extends StatelessWidget {
  final Map<String, int> recentSteps;

  const ActivityChart({
    super.key,
    required this.recentSteps,
  });

  @override
  Widget build(BuildContext context) {
    if (recentSteps.isEmpty || recentSteps.values.every((value) => value == 0)) {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 34),
            SizedBox(height: 10),
            Text(
              'No activity history yet',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Connect a steps source and your weekly activity trend will appear here.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final values = recentSteps.values.toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b).toDouble();
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 165,
      child: BarChart(
        BarChartData(
          maxY: maxValue * 1.15,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i].toDouble(),
                    width: 16,
                    borderRadius: BorderRadius.circular(6),
                    color: scheme.primary,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
