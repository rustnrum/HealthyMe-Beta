import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/direct_metric_service.dart';
import 'package:healthy_me/widgets/garmin_body_battery_panel.dart';

void main() {
  DirectMetricSample sample(String device, String metric, double value,
      DateTime at) => DirectMetricSample(
        sourceId: 'ble:$device', deviceId: device, deviceName: 'Garmin watch',
        metric: metric, value: value, unit: '', capturedAt: at);

  test('only genuine, plausible, device-matched Body Battery is used', () {
    final now = DateTime(2026, 10, 12, 12);
    final readings = <DirectMetricSample>[
      sample('a', 'Body battery', 65, now.subtract(const Duration(hours: 1))),
      sample('b', 'Body battery', 88, now.subtract(const Duration(hours: 1))),
      sample('a', 'Battery', 98, now.subtract(const Duration(hours: 1))),
      sample('a', 'Body battery', -1, now.subtract(const Duration(hours: 1))),
      sample('a', 'Body battery', 101, now.subtract(const Duration(hours: 1))),
      sample('a', 'Body battery', 44, now.subtract(const Duration(days: 32))),
      sample('a', 'Body battery', 75, now.add(const Duration(hours: 1))),
    ];
    final got = GarminBodyBatteryPanel.validHistory(readings, 'a', now: now);
    expect(got, hasLength(1));
    expect(got.single.value, 65);
  });

  test('different scores are compared, never averaged or added', () {
    expect(GarminBodyBatteryPanel.comparison(
      recovery: 60, confidence: 80, bodyBattery: 90, fresh: true),
      contains('30 points apart'));
    expect(GarminBodyBatteryPanel.comparison(
      recovery: 60, confidence: 80, bodyBattery: 90, fresh: false),
      contains('stale'));
    expect(GarminBodyBatteryPanel.comparison(
      recovery: null, confidence: 0, bodyBattery: 90, fresh: true),
      contains('unavailable'));
  });
}
