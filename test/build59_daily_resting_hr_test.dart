import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/direct_metric_service.dart';
import 'package:healthy_me/services/metric_history_service.dart';

void main() {
  DirectMetricSample sample(String metric, String source, double value,
      DateTime timestamp) => DirectMetricSample(
        sourceId: source,
        deviceId: source,
        deviceName: source,
        metric: metric,
        value: value,
        unit: 'bpm',
        capturedAt: timestamp,
      );

  test('one daily BLE resting-HR value per source, keeping latest poll', () {
    final readings = MetricHistoryService.normalize('Resting heart rate', [
      sample('Resting heart rate', 'ble:watch-a', 63, DateTime(2026, 10, 11, 11, 15)),
      sample('Resting heart rate', 'ble:watch-a', 62, DateTime(2026, 10, 10, 21)),
      sample('Resting heart rate', 'ble:watch-b', 58, DateTime(2026, 10, 11, 11)),
      sample('Resting heart rate', 'ble:watch-a', 63, DateTime(2026, 10, 11, 13, 24)),
      sample('Resting heart rate', 'ble:watch-a', 63, DateTime(2026, 10, 11, 1, 43)),
    ]);
    expect(readings.length, 3);
    final sameWatch = readings.where((e) => e.sourceId == 'ble:watch-a').toList();
    expect(sameWatch.length, 2);
    expect(sameWatch.last.capturedAt, DateTime(2026, 10, 11, 13, 24));
    expect(readings.any((e) => e.sourceId == 'ble:watch-b'), isTrue);
  });

  test('normal live heart rate keeps legitimate within-day time series', () {
    final readings = MetricHistoryService.normalize('Heart rate', [
      sample('Heart rate', 'ble:watch-a', 63, DateTime(2026, 10, 11, 11, 15)),
      sample('Heart rate', 'ble:watch-a', 72, DateTime(2026, 10, 11, 13, 24)),
    ]);
    expect(readings.length, 2);
  });

  test('Health Connect resting-HR records are not rewritten', () {
    final readings = MetricHistoryService.normalize('Resting heart rate', [
      sample('Resting heart rate', 'com.health.provider', 63, DateTime(2026, 10, 11, 11, 15)),
      sample('Resting heart rate', 'com.health.provider', 63, DateTime(2026, 10, 11, 13, 24)),
    ]);
    expect(readings.length, 2);
  });
}
