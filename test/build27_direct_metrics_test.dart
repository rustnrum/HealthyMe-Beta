import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/direct_metric_service.dart';

void main() {
  test('direct ring sleep and stages populate HealthSnapshot', () {
    final service = DirectMetricService();
    final now = DateTime(2026, 10, 6, 8);
    const source = 'ble:RING';

    final merged = service.mergeIntoSnapshot(
      const HealthSnapshot(),
      metricSources: const {},
      samples: [
        DirectMetricSample(
          sourceId: source,
          deviceId: 'RING',
          deviceName: 'COLMI R02',
          metric: 'Sleep',
          value: 400,
          unit: 'min',
          capturedAt: now,
        ),
        DirectMetricSample(
          sourceId: source,
          deviceId: 'RING',
          deviceName: 'COLMI R02',
          metric: 'Sleep deep',
          value: 80,
          unit: 'min',
          capturedAt: now,
        ),
        DirectMetricSample(
          sourceId: source,
          deviceId: 'RING',
          deviceName: 'COLMI R02',
          metric: 'Sleep REM',
          value: 70,
          unit: 'min',
          capturedAt: now,
        ),
        DirectMetricSample(
          sourceId: source,
          deviceId: 'RING',
          deviceName: 'COLMI R02',
          metric: 'Sleep light',
          value: 250,
          unit: 'min',
          capturedAt: now,
        ),
        DirectMetricSample(
          sourceId: source,
          deviceId: 'RING',
          deviceName: 'COLMI R02',
          metric: 'Sleep awake',
          value: 20,
          unit: 'min',
          capturedAt: now,
        ),
      ],
    );

    expect(merged.sleepMinutes, 400);
    expect(merged.sleepDeepMinutes, 80);
    expect(merged.sleepRemMinutes, 70);
    expect(merged.sleepLightMinutes, 250);
    expect(merged.sleepAwakeMinutes, 20);
    expect(merged.availableSources['Sleep'], contains(source));
    expect(merged.availableSources['Sleep Stages'], contains(source));
  });

  test('Garmin realtime metrics become direct selectable sources', () {
    final service = DirectMetricService();
    final now = DateTime(2026, 10, 6, 16);
    const source = 'ble:GARMIN';

    final samples = <DirectMetricSample>[
      DirectMetricSample(
        sourceId: source,
        deviceId: 'GARMIN',
        deviceName: 'vívoactive 6',
        metric: 'Heart rate',
        value: 76,
        unit: 'bpm',
        capturedAt: now,
      ),
      DirectMetricSample(
        sourceId: source,
        deviceId: 'GARMIN',
        deviceName: 'vívoactive 6',
        metric: 'Resting heart rate',
        value: 55,
        unit: 'bpm',
        capturedAt: now,
      ),
      DirectMetricSample(
        sourceId: source,
        deviceId: 'GARMIN',
        deviceName: 'vívoactive 6',
        metric: 'HRV',
        value: 42,
        unit: 'ms',
        capturedAt: now,
      ),
      DirectMetricSample(
        sourceId: source,
        deviceId: 'GARMIN',
        deviceName: 'vívoactive 6',
        metric: 'SpO2',
        value: 97,
        unit: '%',
        capturedAt: now,
      ),
      DirectMetricSample(
        sourceId: source,
        deviceId: 'GARMIN',
        deviceName: 'vívoactive 6',
        metric: 'Respiratory rate',
        value: 15,
        unit: 'breaths/min',
        capturedAt: now,
      ),
      DirectMetricSample(
        sourceId: source,
        deviceId: 'GARMIN',
        deviceName: 'vívoactive 6',
        metric: 'Steps',
        value: 8123,
        unit: 'count',
        capturedAt: now,
      ),
    ];

    final merged = service.mergeIntoSnapshot(
      const HealthSnapshot(),
      metricSources: const {},
      samples: samples,
    );

    expect(merged.latestHeartRate, 76);
    expect(merged.restingHeartRate, 55);
    expect(merged.hrvMs, 42);
    expect(merged.bloodOxygenPercent, 97);
    expect(merged.respiratoryRate, 15);
    expect(merged.stepsToday, 8123);
    expect(merged.availableSources['HRV'], contains(source));
    expect(merged.availableSources['Steps'], contains(source));
  });

  test('ring firmware HRV proxy does not overwrite Salus HRV', () {
    final service = DirectMetricService();
    final now = DateTime(2026, 10, 6, 16);

    final merged = service.mergeIntoSnapshot(
      const HealthSnapshot(hrvMs: 51),
      metricSources: const {},
      samples: [
        DirectMetricSample(
          sourceId: 'ble:RING',
          deviceId: 'RING',
          deviceName: 'COLMI R02',
          metric: 'Ring HRV proxy',
          value: 88,
          unit: 'relative',
          capturedAt: now,
        ),
      ],
    );

    expect(merged.hrvMs, 51);
    expect(merged.availableSources.containsKey('HRV'), isFalse);
  });

  test('rmssd helper calculates beat interval variability', () {
    final value = DirectMetricService.rmssd([1000, 1010, 990, 1020]);
    expect(value, greaterThan(0));
    expect(value.isFinite, isTrue);
  });
}
