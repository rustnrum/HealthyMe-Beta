import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/ble_protocol_profiles.dart';
import 'package:healthy_me/services/source_hub_service.dart';

void main() {
  test('stale provider with no readable metric disappears', () {
    const snapshot = HealthSnapshot(
      detectedSources: ['com.garmin.android.apps.connectmobile'],
      sourceLabels: {
        'com.garmin.android.apps.connectmobile': 'Garmin Connect',
      },
    );

    expect(SourceHubService.healthSources(snapshot), isEmpty);
  });

  test('direct BLE sample is selectable and labeled direct transport', () {
    const snapshot = HealthSnapshot(
      detectedSources: ['ble:AA:BB:CC:DD:EE:FF'],
      availableSources: {
        'Heart rate': ['ble:AA:BB:CC:DD:EE:FF'],
      },
      sourceLabels: {
        'ble:AA:BB:CC:DD:EE:FF': 'vívoactive 6',
      },
      sourceRecordCounts: {
        'Heart rate': {'ble:AA:BB:CC:DD:EE:FF': 1},
      },
    );

    final sources = SourceHubService.healthSources(snapshot);
    expect(sources, hasLength(1));
    expect(sources.single.selectable, isTrue);
    expect(sources.single.transport, SourceTransport.directBluetooth);
    expect(sources.single.transportLabel, 'Direct Bluetooth');
  });

  test('accented vivoactive name maps to Garmin family', () {
    final report = BleProtocolProfiles.analyze(
      const ['180d'],
      name: 'vívoactive 6',
    );

    expect(report.protocolProfile?.id, 'garmin-family');
    expect(report.deviceKind, 'Watch');
  });
}
