import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Activity refreshes the selected BLE Steps device, not every device', () {
    final activity = File('lib/screens/activity_screen.dart').readAsStringSync();
    final sync = File('lib/state/health_sync_provider.dart').readAsStringSync();
    expect(activity, contains('.refreshSelectedDirectSteps()'));
    expect(activity, contains('onPressed: syncState.isLoading || _refreshingSteps'));
    expect(sync, contains('Future<String> refreshSelectedDirectSteps() async'));
    expect(sync, contains(r"'ble:${device.id}' == source"));
    expect(sync, contains('duration: const Duration(seconds: 23)'));
    expect(sync, contains('reading.metrics[\'Steps\']'));
  });

  test('no received Steps packet cannot be declared a successful refresh', () {
    final sync = File('lib/state/health_sync_provider.dart').readAsStringSync();
    expect(sync, contains('returned no new Steps total'));
    expect(sync, contains('The last saved reading was retained'));
    expect(sync, contains('Steps sync failed:'));
  });

  test('direct device results update before Health Connect, preserving source', () {
    final sync = File('lib/state/health_sync_provider.dart').readAsStringSync();
    expect(sync, contains('final directSnapshot = _directService.mergeIntoSnapshot('));
    expect(sync, contains('setHealthSnapshot(directSnapshot)'));
    expect(sync, contains('metricSources: routedSources'));
    expect(sync, contains('registeredDevices: savedDevices'));
  });

  test('unverified Garmin HRV is not represented as available overnight HRV', () {
    final profile = File('lib/services/ble_protocol_profiles.dart').readAsStringSync();
    final metric = File('lib/screens/metric_detail_screen.dart').readAsStringSync();
    expect(profile, contains("'Steps',\n        'Heart rate',\n        'SpO2',"));
    expect(metric, contains('No validated HRV available yet'));
    expect(metric, contains('Unverified old Garmin HRV samples'));
    expect(metric, contains('ExpansionTile('));
    expect(metric, contains('Recovery will exclude them'));
  });
}
