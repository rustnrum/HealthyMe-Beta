import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/direct_metric_service.dart';
import 'package:healthy_me/services/metric_history_service.dart';
import 'package:healthy_me/services/recovery_service.dart';
import 'package:healthy_me/state/app_state.dart';

void main() {
  DirectMetricSample oldReading(double value, DateTime at) => DirectMetricSample(
        sourceId: 'ble:GARMIN', deviceId: 'GARMIN',
        deviceName: 'vívoactive 6', metric: 'HRV', value: value,
        unit: 'ms', capturedAt: at,
      );

  test('Garmin short-BLE HRV is flagged without deleting prior values', () async {
    final low = oldReading(2.2, DateTime(2026, 10, 11, 11));
    final high = oldReading(132, DateTime(2026, 10, 11, 12));
    SharedPreferences.setMockInitialValues({
      'salus_direct_metric_samples_v1': jsonEncode([low.toJson(), high.toJson()]),
    });
    final stored = await const DirectMetricService().loadSamples();
    expect(stored.length, 2);
    expect(stored.map((r) => r.value).toList(), [2.2, 132]);
    expect(stored.every((s) =>
        s.metric == DirectMetricService.experimentalGarminHrv), isTrue);
    expect(MetricHistoryService.normalize('HRV', stored), isEmpty);
  });

  test('current and baseline HRV from old Garmin BLE are excluded from Recovery', () {
    final now = DateTime.now();
    final legacy = oldReading(132, now.subtract(const Duration(minutes: 1)));
    const prior = HealthSnapshot(
      hrvMs: 132, hrv30: [2.2, 19, 33, 132],
      resolvedSources: {'HRV': 'ble:GARMIN'},
      sourceLabels: {'ble:GARMIN': 'vívoactive 6'},
    );
    final merged = const DirectMetricService().mergeIntoSnapshot(
      prior, metricSources: const {'HRV': 'ble:GARMIN'}, samples: [legacy]);
    expect(merged.hrvMs, isNull);
    expect(merged.hrv30, isEmpty);
    final report = RecoveryService.build(HealthyMeState(health: merged));
    final hrv = report.contributors.firstWhere((c) => c.name == 'HRV');
    expect(hrv.score, isNull);
  });

  test('cached short Garmin HRV is removed upon restored app state', () {
    final prior = const HealthSnapshot(
      hrvMs: 132, hrv30: [2.2, 132],
      resolvedSources: {'HRV': 'ble:GARMIN'},
      sourceLabels: {'ble:GARMIN': 'vívoactive 6'},
    );
    final state = HealthyMeState.fromJson({'health': prior.toJson()});
    expect(state.health.hrvMs, isNull);
    expect(state.health.hrv30, isEmpty);
    expect(state.health.resolvedSources.containsKey('HRV'), isFalse);
  });

  test('Health Connect HRV from another provider remains untouched', () {
    const trusted = HealthSnapshot(
      hrvMs: 27, hrv30: [25, 26, 27, 28],
      resolvedSources: {'HRV': 'com.example.provider'},
    );
    final merged = const DirectMetricService().mergeIntoSnapshot(
      trusted, metricSources: const {'HRV': 'com.example.provider'},
      samples: [oldReading(132, DateTime.now())]);
    expect(merged.hrvMs, 27);
    expect(merged.hrv30, [25, 26, 27, 28]);
  });
}
