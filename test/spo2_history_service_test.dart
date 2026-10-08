import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/direct_metric_service.dart';
import 'package:healthy_me/services/spo2_history_service.dart';

void main() {
  test('SpO₂ history retains different providers and removes same-source duplicates', () {
    final time = DateTime(2026, 10, 8, 9);
    DirectMetricSample sample(String source, double value) => DirectMetricSample(
          sourceId: source,
          deviceId: source,
          deviceName: source,
          metric: 'SpO2',
          value: value,
          unit: '%',
          capturedAt: time,
        );
    final readings = SpO2HistoryService.normalized([
      sample('ble:ring', 97),
      sample('ble:ring', 97),
      sample('com.other.health', 97),
      sample('ble:ring', 105),
      sample('com.android.healthconnect', 99),
    ]);
    expect(readings.length, 2);
    expect(readings.map((r) => r.sourceId).toSet(),
        {'ble:ring', 'com.other.health'});
  });
}
