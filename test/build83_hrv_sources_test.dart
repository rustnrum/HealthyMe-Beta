import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/direct_metric_service.dart';
import 'package:healthy_me/services/hrv_source_service.dart';

void main() {
  final now = DateTime(2026, 10, 13, 17);
  DirectMetricSample firmware(String id, int value, int minutesAgo) =>
      DirectMetricSample(
        sourceId: 'ble:$id', deviceId: id, deviceName: 'Smart ring',
        metric: 'Ring HRV proxy', value: value.toDouble(),
        unit: 'firmware-proxy',
        capturedAt: now.subtract(Duration(minutes: minutesAgo)),
      );

  test('Automatic HRV retains qualified measurements from ANY source', () {
    final h = HealthSnapshot(
      hrvMs: 42,
      hrv30: const [44, 43, 42],
      resolvedSources: const {'HRV': 'com.health.provider.one'},
      sourceLabels: const {'com.health.provider.one': 'Health provider'},
    );
    final report = HrvSourceService.resolve(
      health: h, selectedSource: 'Auto', now: now,
      directSamples: [firmware('ring', 51, 10)],
    );
    expect(report.rmssdMs, 42);
    expect(report.rmssdHistory, [44, 43, 42]);
    expect(report.sourceLabel, 'Health provider');
    expect(report.status, contains('RMSSD'));
  });

  test('Manual source never falls back silently to another provider', () {
    final report = HrvSourceService.resolve(
      health: const HealthSnapshot(hrvMs: 51, hrv30: [50, 51],
          resolvedSources: {'HRV': 'com.other.provider'}),
      selectedSource: 'ble:ring1', now: now,
      directSamples: [firmware('ring1', 59, 8), firmware('ring2', 63, 5)],
    );
    expect(report.rmssdMs, isNull);
    expect(report.indexHistory.map((s) => s.value), [59]);
    expect(report.displayedValue, '59 index');
    expect(report.status, contains('not RMSSD'));
  });

  test('Automatic index display uses the latest reporting index provider', () {
    final report = HrvSourceService.resolve(
      health: const HealthSnapshot(),
      selectedSource: null, now: now,
      directSamples: [firmware('older', 62, 60), firmware('newer', 71, 5)],
    );
    expect(report.sourceId, 'ble:newer');
    expect(report.latestIndex?.value, 71);
    expect(report.rmssdMs, isNull);
  });

  test('Invalid and future data are never promoted to a measured HRV', () {
    final report = HrvSourceService.resolve(
      health: const HealthSnapshot(hrvMs: null),
      selectedSource: 'ble:r', now: now,
      directSamples: [firmware('r', 58, -60), firmware('r', 0, 30)],
    );
    expect(report.hasIndex, isFalse);
    expect(report.rmssdMs, isNull);
  });

  test('All modules share one resolver and ring is not hardwired as RMSSD', () {
    final home = File('lib/screens/premium/salus_home_77.dart').readAsStringSync();
    final health = File('lib/screens/premium/salus_health_77.dart').readAsStringSync();
    final detail = File('lib/screens/metric_detail_screen.dart').readAsStringSync();
    final picker = File('lib/screens/sources_screen.dart').readAsStringSync();
    final profile = File('lib/services/ble_protocol_profiles.dart').readAsStringSync();
    expect(home, contains('HrvSourceService.resolve('));
    expect(health, contains('HrvSourceService.resolve('));
    expect(detail, contains('HrvSourceService.resolve('));
    expect(picker, contains('qualifiedChoices'));
    expect(picker, contains("'Ring HRV proxy'"));
    expect(profile, contains("'Ring HRV proxy'"));
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.45+83'));
  });
}
