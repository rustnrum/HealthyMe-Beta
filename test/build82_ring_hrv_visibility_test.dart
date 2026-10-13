import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/direct_metric_service.dart';
import 'package:healthy_me/services/metric_history_service.dart';

void main() {
  DirectMetricSample ring(String ringId, int value, DateTime at) => DirectMetricSample(
    sourceId: 'ble:$ringId', deviceId: ringId, deviceName: 'COLMI R02',
    metric: 'Ring HRV proxy', value: value.toDouble(), unit: 'firmware-proxy', capturedAt: at);

  test('Recorded ring firmware index cannot be silently treated as RMSSD', () {
    final t = DateTime(2026, 10, 12, 9);
    final records = [ring('a', 57, t), ring('a', 59, t.add(const Duration(minutes: 10))),
      ring('b', 42, t)];
    expect(MetricHistoryService.normalize('HRV', records), isEmpty);
    expect(MetricHistoryService.normalize('Ring HRV proxy', records), hasLength(3));
    final selected = MetricHistoryService.normalize('Ring HRV proxy', records)
      .where((s) => s.sourceId == 'ble:a').toList();
    expect(selected.map((s) => s.value), [57, 59]);
    expect(MetricHistoryService.healthTypes.containsKey('Ring HRV proxy'), isFalse);
  });

  test('History screen displays source-matched ring-index readings and record counts', () {
    final metric = File('lib/screens/metric_detail_screen.dart').readAsStringSync();
    final service = File('lib/services/metric_history_service.dart').readAsStringSync();
    expect(metric, contains('Ring HRV firmware history'));
    expect(metric, contains('saved index readings from the selected ring'));
    expect(metric, contains('selectedRingHistory'));
    expect(metric, contains('Refresh ring history'));
    expect(metric, contains('not verified RMSSD'));
    expect(metric, contains('Recovery will exclude them'));
    expect(service, contains("normalize('Ring HRV proxy'"));
    expect(service, contains('ringHrvProxy: ringHrvProxy'));
  });

  test('Home shows the recorded ring index trend without affecting Recovery', () {
    final home = File('lib/screens/premium/salus_home_77.dart').readAsStringSync();
    final recovery = File('lib/services/recovery_service.dart').readAsStringSync();
    expect(home, contains('Ring HRV index'));
    expect(home, contains("s.metric == 'Ring HRV proxy'"));
    expect(home, contains("app.metricSources['HRV']"));
    expect(home, contains('_ringIndexTrend('));
    expect(recovery, contains("_hrvContributor(app.health)"));
    expect(recovery.contains('Ring HRV proxy'), isFalse);
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.44+82'));
  });
}
