import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/direct_metric_service.dart';
import 'package:healthy_me/services/metric_history_service.dart';

void main() {
  DirectMetricSample step(String source, int value, DateTime when) =>
      DirectMetricSample(
        sourceId: source, deviceId: source, deviceName: 'Test Garmin',
        metric: 'Steps', value: value.toDouble(), unit: 'count',
        capturedAt: when,
      );

  test('Garmin step totals produce daily history, not fabricated hourly data', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final result = const DirectMetricService().mergeIntoSnapshot(
      const HealthSnapshot(authorized: false),
      metricSources: const {'Steps': 'ble:watch'},
      samples: [
        step('ble:watch', 6000, yesterday.add(const Duration(hours: 20))),
        step('ble:watch', 100, today),
        step('ble:watch', 135, today),
        step('ble:other', 9000, today),
      ],
    );
    expect(result.resolvedSources['Steps'], 'ble:watch');
    expect(result.stepsToday, 135);
    expect(result.dailySteps30.length, 30);
    expect(result.dailySteps30.last, 135);
    expect(result.dailySteps30[result.dailySteps30.length - 2], 6000);
    expect(result.hourlySteps, isEmpty);
    expect(result.monthlySteps12, isEmpty);
  });

  test('old daily BLE step polls collapse by provider and date', () {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    final result = MetricHistoryService.normalize('Steps', [
      step('ble:watch', 200, date),
      step('ble:watch', 250, date.add(const Duration(minutes: 5))),
      step('ble:watch', 240, date.add(const Duration(minutes: 6))),
      step('ble:other', 2000, date),
    ]);
    expect(result.length, 2);
    expect(result.firstWhere((e) => e.sourceId == 'ble:watch').value, 250);
    expect(result.firstWhere((e) => e.sourceId == 'ble:other').value, 2000);
  });

  test('a yesterday-only Garmin reading cannot become today steps', () {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final result = const DirectMetricService().mergeIntoSnapshot(
      const HealthSnapshot(),
      metricSources: const {'Steps': 'ble:watch'},
      samples: [step('ble:watch', 7000, yesterday)],
    );
    expect(result.stepsToday, 0);
    expect(result.dailySteps30[result.dailySteps30.length - 2], 7000);
  });

  test('manual Health Connect routing never borrows a Garmin step count', () {
    final now = DateTime.now();
    final base = const HealthSnapshot(
      authorized: true, stepsToday: 444,
      dailySteps30: [111, 444],
      hourlySteps: [22, 33],
      resolvedSources: {'Steps': 'com.test.steps'},
    );
    final result = const DirectMetricService().mergeIntoSnapshot(
      base,
      metricSources: const {'Steps': 'com.test.steps'},
      samples: [step('ble:watch', 1000, now)],
    );
    expect(result.stepsToday, 444);
    expect(result.dailySteps30, [111, 444]);
    expect(result.hourlySteps, [22, 33]);
  });
}
