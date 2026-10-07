import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Build 36 keeps Today, watch settings and history contracts', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    final watch = File('lib/screens/watch_device_screen.dart').readAsStringSync();
    final direct =
        File('lib/services/direct_metric_service.dart').readAsStringSync();
    final native =
        File('scripts/SalusProtocolReader.kt.template').readAsStringSync();

    expect(home, contains('Device batteries'));
    expect(home, contains('plannedWorkouts'));
    expect(home, contains('salusMealSlots'));
    expect(watch, contains('Android notification access'));
    expect(watch, contains('Text messages'));
    expect(direct, contains('final List<DirectMetricSample> history'));
    expect(native, contains('SALUS_PROTOCOL_METRICS_V036'));
    expect(native, contains('StartSpool'));
    expect(native, contains('PullSpoolFragments'));
    expect(native, contains('parseCpapSummaryPayload'));
  });
}
