import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/ble_discovery_service.dart';
import 'package:healthy_me/services/source_hub_service.dart';
import 'package:healthy_me/services/source_name_service.dart';

void main() {
  test('Health Connect stays transport-only while providers are selectable', () {
    final snapshot = HealthSnapshot(
      detectedSources: const [
        'com.garmin.android.apps.connectmobile',
        'com.google.android.apps.healthdata',
        'Health Connect',
        'com.xs.imoni',
      ],
      availableSources: const {
        'Steps': ['com.garmin.android.apps.connectmobile'],
        'Weight': ['com.xs.imoni'],
      },
      sourceLabels: const {
        'com.garmin.android.apps.connectmobile': 'Garmin Connect',
        'com.google.android.apps.healthdata': 'Health Connect',
        'com.xs.imoni': 'iMoni',
      },
    );

    final sources = SourceHubService.healthSources(snapshot);
    expect(sources.map((source) => source.label), contains('Garmin Connect'));
    expect(sources.map((source) => source.label), contains('iMoni'));
    expect(sources.map((source) => source.label), isNot(contains('Health Connect')));

    final weight = SourceHubService.healthChoicesForMetric(snapshot, 'Weight');
    expect(weight, hasLength(1));
    expect(weight.single.label, 'iMoni');
    expect(weight.single.transportLabel, 'via Health Connect');
  });


  test('Health Connect labels and packages are transport-only', () {
    expect(SourceNameService.isTransportOnly('Health Connect'), isTrue);
    expect(
      SourceNameService.isTransportOnly('com.google.android.apps.healthdata'),
      isTrue,
    );
    expect(
      SourceNameService.isTransportOnly('com.garmin.android.apps.connectmobile'),
      isFalse,
    );
    const phoneSpn =
        'com.android.healthconnect.phone.jd5bdd37e1a8d3667a05d0abebfc4a89e';
    expect(SourceNameService.isTransportOnly(phoneSpn), isFalse);
    expect(SourceNameService.friendly(phoneSpn), 'Your phone');
  });

  test('providers missing a metric remain visible but are not choices', () {
    const snapshot = HealthSnapshot(
      detectedSources: [
        'com.garmin.android.apps.connectmobile',
        'com.xs.imoni',
      ],
      availableSources: {
        'Steps': ['com.garmin.android.apps.connectmobile'],
        'Weight': ['com.xs.imoni'],
      },
    );

    final steps = SourceHubService.healthChoicesForMetric(snapshot, 'Steps');
    final missing = SourceHubService.healthSourcesMissingMetric(
      snapshot,
      'Steps',
    );

    expect(steps.map((source) => source.label), contains('Garmin Connect'));
    expect(missing.map((source) => source.label), contains('iMoni'));
  });

  test('BLE protocol identity does not make direct device selectable', () {
    const device = BleDeviceCandidate(
      id: 'AA:BB:CC:DD:EE:FF',
      name: 'R02_TEST',
      rssi: -50,
      advertisedServices: [],
      capabilities: ['Heart rate', 'SpO2', 'Steps', 'Sleep'],
      protocolProfile: 'Smart ring protocol',
      protocolNote: 'Fingerprint match',
      manufacturerDataHex: '',
    );

    final sources = SourceHubService.bluetoothSources(
      devices: const [device],
      inspections: const {},
    );

    expect(sources, hasLength(1));
    expect(sources.single.label, 'Smart ring');
    expect(sources.single.selectable, isFalse);
    expect(sources.single.transportLabel, 'Direct Bluetooth');
  });
}
