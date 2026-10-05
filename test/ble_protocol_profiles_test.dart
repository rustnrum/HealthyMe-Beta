import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/ble_protocol_profiles.dart';

void main() {
  test('normalizes standard 16-bit service UUIDs', () {
    expect(
      BleProtocolProfiles.normalizeUuid('180D'),
      '0000180d-0000-1000-8000-00805f9b34fb',
    );
  });

  test('recognizes standard health GATT capabilities', () {
    final report = BleProtocolProfiles.analyze([
      '0000180d-0000-1000-8000-00805f9b34fb',
      '00001822-0000-1000-8000-00805f9b34fb',
      '0000181b-0000-1000-8000-00805f9b34fb',
    ]);

    expect(report.standardCapabilities, contains('Heart rate'));
    expect(report.standardCapabilities, contains('SpO₂'));
    expect(report.standardCapabilities, contains('Body fat'));
  });

  test('matches proprietary ring protocol by service fingerprint', () {
    final report = BleProtocolProfiles.analyze([
      BleProtocolProfiles.ringUartService,
    ]);

    expect(report.protocolProfile?.id, 'ring-uart-v1');
    expect(report.allCapabilities, contains('SpO₂'));
    expect(report.allCapabilities, contains('Sleep'));
  });

  test('does not assign proprietary profile to unrelated device', () {
    final report = BleProtocolProfiles.analyze([
      '0000180f-0000-1000-8000-00805f9b34fb',
    ]);

    expect(report.protocolProfile, isNull);
    expect(report.standardCapabilities, contains('Battery'));
  });
}
