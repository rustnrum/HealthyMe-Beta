import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/ble_discovery_service.dart';
import 'package:healthy_me/services/ble_protocol_profiles.dart';
import 'package:healthy_me/services/source_hub_service.dart';

void main() {
  test('ordinary nearby Bluetooth hardware is not called a health device', () {
    final report = BleProtocolProfiles.analyze(
      const [],
      name: 'Echo Dot-J62',
    );

    expect(report.deviceKind, 'Bluetooth device');
  });

  test('unknown Bluetooth source is separated from health candidates', () {
    const device = BleDeviceCandidate(
      id: '11:22:33:44:55:66',
      name: 'Echo Dot-J62',
      rssi: -45,
      advertisedServices: [],
      capabilities: [],
      protocolProfile: null,
      protocolNote: null,
      deviceKind: 'Bluetooth device',
      manufacturerDataHex: '',
    );

    final source = SourceHubService.bluetoothSources(
      devices: const [device],
      inspections: const {},
    ).single;

    expect(source.label, 'Echo Dot-J62');
    expect(SourceHubService.isBluetoothHealthCandidate(source), isFalse);
  });

  test('real standard heart-rate sensor remains a health candidate', () {
    const device = BleDeviceCandidate(
      id: 'AA:BB:CC:DD:EE:01',
      name: 'HRM',
      rssi: -45,
      advertisedServices: ['0000180d-0000-1000-8000-00805f9b34fb'],
      capabilities: ['Heart rate'],
      protocolProfile: null,
      protocolNote: null,
      deviceKind: 'Heart-rate sensor',
      manufacturerDataHex: '',
    );

    final source = SourceHubService.bluetoothSources(
      devices: const [device],
      inspections: const {},
    ).single;

    expect(SourceHubService.isBluetoothHealthCandidate(source), isTrue);
  });

  test('identified unnamed protocol uses family label instead of health device', () {
    const device = BleDeviceCandidate(
      id: 'AA:00:00:00:00:02',
      name: 'Unnamed BLE device',
      rssi: -50,
      advertisedServices: [],
      capabilities: ['Steps', 'Heart rate'],
      protocolProfile: 'Garmin watch family',
      protocolNote: 'Fingerprint match',
      deviceKind: 'Watch',
      manufacturerDataHex: '',
    );

    final source = SourceHubService.bluetoothSources(
      devices: const [device],
      inspections: const {},
    ).single;

    expect(source.label, 'Garmin watch family');
  });

}
