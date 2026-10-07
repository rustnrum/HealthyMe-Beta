import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/ble_protocol_profiles.dart';

void main() {
  test('ResMed identity wins over ring fingerprint', () {
    final report = BleProtocolProfiles.analyze(
      const [
        BleProtocolProfiles.ringUartService,
        BleProtocolProfiles.ringBigDataService,
      ],
      name: 'ResMed AirSense 11',
    );
    expect(report.protocolProfile?.id, 'cpap-family');
  });

  test('UART alone is not enough to classify a generic device as a ring', () {
    final report = BleProtocolProfiles.analyze(
      const [BleProtocolProfiles.ringUartService],
      name: 'Medical device',
    );
    expect(report.protocolProfile?.id, isNot('ring-uart-v1'));
  });

  test('known COLMI identity still resolves to ring family', () {
    final report = BleProtocolProfiles.analyze(
      const [BleProtocolProfiles.ringUartService],
      name: 'COLMI R02',
    );
    expect(report.protocolProfile?.id, 'ring-uart-v1');
  });
}
