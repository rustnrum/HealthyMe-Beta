import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/ble_protocol_profiles.dart';

void main() {
  test('QRing UART fingerprint identifies ring capabilities', () {
    final report = BleProtocolProfiles.analyze(
      const [BleProtocolProfiles.ringUartService],
      name: 'R02',
    );
    expect(report.protocolProfile?.id, 'ring-uart-v1');
    expect(report.deviceKind, 'Ring');
    expect(report.allCapabilities, contains('HRV'));
    expect(report.allCapabilities, contains('Raw motion'));
  });

  test('standard Bluetooth body-composition service identifies scale', () {
    final report = BleProtocolProfiles.analyze(
      const ['0000181b-0000-1000-8000-00805f9b34fb'],
      name: 'Body Scale',
    );
    expect(report.deviceKind, 'Scale');
    expect(report.allCapabilities, contains('Weight'));
    expect(report.allCapabilities, contains('Body composition'));
  });

  test('Garmin advertised identity is treated as protocol candidate', () {
    final report = BleProtocolProfiles.analyze(
      const [],
      name: 'Garmin Venu',
    );
    expect(report.protocolProfile?.id, 'garmin-family');
    expect(report.deviceKind, 'Watch');
    expect(report.allCapabilities, contains('Respiratory rate'));
  });

  test('standard heart-rate service remains manufacturer independent', () {
    final report = BleProtocolProfiles.analyze(
      const ['180d'],
      name: 'Chest sensor',
    );
    expect(report.protocolProfile, isNull);
    expect(report.allCapabilities, contains('Heart rate'));
    expect(report.deviceKind, 'Heart-rate sensor');
  });

  test('ResMed name is classified as CPAP health hardware', () {
    final report = BleProtocolProfiles.analyze(
      const [],
      name: 'ResMed 681683',
    );
    expect(report.protocolProfile?.id, 'cpap-family');
    expect(report.deviceKind, 'CPAP / respiratory');
    expect(report.allCapabilities, contains('Therapy data'));
  });

  test('ResMed advertised service identifies CPAP', () {
    final report = BleProtocolProfiles.analyze(
      const [BleProtocolProfiles.resMedAdvertisedService],
      name: 'Unnamed BLE device',
    );
    expect(report.protocolProfile?.id, 'cpap-family');
    expect(report.deviceKind, 'CPAP / respiratory');
  });

  test('ResMed proprietary GATT service identifies CPAP', () {
    final report = BleProtocolProfiles.analyze(
      const [BleProtocolProfiles.resMedDeviceService],
      name: 'Unnamed BLE device',
    );
    expect(report.protocolProfile?.id, 'cpap-family');
    expect(report.deviceKind, 'CPAP / respiratory');
  });

}
