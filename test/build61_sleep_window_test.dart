import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/direct_metric_service.dart';
import 'package:healthy_me/services/sleep_window_service.dart';

void main() {
  DirectMetricSample marker(String kind, DateTime time, {String source = 'ble:ring'}) =>
      DirectMetricSample(sourceId: source, deviceId: source, deviceName: 'COLMI',
          metric: kind, value: 1.0, unit: '', capturedAt: time);

  test('sleep starts before midnight, wake the next day; same source only', () {
    final now = DateTime(2026, 10, 11, 18);
    final samples = [
      marker('Sleep start', DateTime(2026, 10, 10, 23, 40)),
      marker('Sleep end', DateTime(2026, 10, 11, 6, 50)),
      marker('Sleep start', DateTime(2026, 10, 11, 12), source: 'ble:other'),
    ];
    final session = SleepWindowService.latest(samples, 'ble:ring', now: now);
    expect(session?.start, DateTime(2026, 10, 10, 23, 40));
    expect(session?.end, DateTime(2026, 10, 11, 6, 50));
  });

  test('old duration-only ring records cannot manufacture a sleep window', () {
    final now = DateTime(2026, 10, 11, 18);
    final samples = [
      DirectMetricSample(sourceId: 'ble:ring', deviceId: 'ring',
        deviceName: 'COLMI', metric: 'Sleep', value: 282, unit: 'min',
        capturedAt: DateTime(2026, 10, 11, 12)),
    ];
    expect(SleepWindowService.latest(samples, 'ble:ring', now: now), isNull);
  });

  test('never pair future timestamps or impossible session lengths', () {
    final now = DateTime(2026, 10, 11, 18);
    final samples = [
      marker('Sleep start', DateTime(2026, 10, 9, 1)),
      marker('Sleep end', DateTime(2026, 10, 11, 7)),
      marker('Sleep end', DateTime(2026, 10, 12, 7)),
    ];
    expect(SleepWindowService.latest(samples, 'ble:ring', now: now), isNull);
  });
}
