import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/direct_metric_service.dart';
import 'package:healthy_me/services/metric_history_service.dart';

void main() {
  DirectMetricSample reading(String metric, String source, double value,
          DateTime time) => DirectMetricSample(
        sourceId: source,
        deviceId: source,
        deviceName: source,
        metric: metric,
        value: value,
        unit: MetricHistoryService.unitFor(metric),
        capturedAt: time,
      );

  test('history retains distinct providers and real timestamps', () {
    final when = DateTime(2026, 10, 8, 7);
    final result = MetricHistoryService.normalize('HRV', [
      reading('HRV', 'ble:ring', 30, when),
      reading('HRV', 'com.example.watch', 30, when),
    ]);
    expect(result.length, 2);
    expect(result.map((e) => e.sourceId).toSet(),
        {'ble:ring', 'com.example.watch'});
  });

  test('same source duplicate is removed', () {
    final when = DateTime(2026, 10, 8, 7);
    final p = reading('HRV', 'ble:ring', 30, when);
    expect(MetricHistoryService.normalize('HRV', [p, p]).length, 1);
  });

  test('different metrics never enter the wrong detail page', () {
    final when = DateTime(2026, 10, 8, 7);
    expect(MetricHistoryService.normalize('HRV', [
      reading('SpO2', 'ble:ring', 97, when),
    ]), isEmpty);
  });

  test('invalid oxygen and HRV samples never enter a chart', () {
    final when = DateTime(2026, 10, 8, 7);
    expect(MetricHistoryService.normalize('SpO2', [
      reading('SpO2', 'ble:ring', 120, when),
      reading('SpO2', 'ble:ring', 97, when),
    ]).single.value, 97);
    expect(MetricHistoryService.validValue('HRV', -1), isFalse);
  });
}
