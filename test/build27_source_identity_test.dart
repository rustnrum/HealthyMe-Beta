import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/ble_discovery_service.dart';
import 'package:healthy_me/services/source_hub_service.dart';

void main() {
  test('Garmin capabilities never relabel a watch as Smart ring', () {
    const device = BleDeviceCandidate(
      id: 'AA:BB',
      name: 'vívoactive 6',
      rssi: -50,
      advertisedServices: [],
      capabilities: [
        'Steps',
        'Sleep',
        'Heart rate',
        'HRV',
        'SpO2',
      ],
      protocolProfile: 'Garmin watch family',
      protocolId: 'garmin-family',
      protocolNote: 'Garmin',
      deviceKind: 'Watch',
      manufacturerDataHex: '',
      bondState: 'bonded',
    );

    final sources = SourceHubService.bluetoothSources(
      devices: const [device],
      inspections: const {},
    );

    expect(sources.single.label, 'vívoactive 6');
  });

  test('named COLMI ring preserves its device name', () {
    const device = BleDeviceCandidate(
      id: 'CC:DD',
      name: 'COLMI R02',
      rssi: -45,
      advertisedServices: [],
      capabilities: ['Steps', 'Sleep', 'Heart rate', 'SpO2'],
      protocolProfile: 'QRing / Yawell ring family',
      protocolId: 'ring-uart-v1',
      protocolNote: 'Ring',
      deviceKind: 'Ring',
      manufacturerDataHex: '',
      bondState: 'bonded',
    );

    final sources = SourceHubService.bluetoothSources(
      devices: const [device],
      inspections: const {},
    );

    expect(sources.single.label, 'COLMI R02');
  });
}
