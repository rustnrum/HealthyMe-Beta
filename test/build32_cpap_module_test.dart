import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/ble_protocol_profiles.dart';
import 'package:healthy_me/services/cpap_therapy_service.dart';
import 'package:healthy_me/services/direct_metric_service.dart';

void main() {
  test('strong ResMed identity wins over generic ring UART fingerprint', () {
    final report = BleProtocolProfiles.analyze(
      const [
        BleProtocolProfiles.ringUartService,
        BleProtocolProfiles.ringBigDataService,
      ],
      name: 'ResMed AirSense 11',
    );

    expect(report.protocolProfile?.id, 'cpap-family');
    expect(report.deviceKind, 'CPAP / respiratory');
    expect(report.allCapabilities, contains('AHI'));
    expect(report.allCapabilities, isNot(contains('Heart rate')));
  });

  test('generic Nordic UART by itself is not enough to call a device a ring', () {
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
    expect(report.deviceKind, 'Ring');
  });

  test('CPAP service builds nightly summaries from real therapy metrics', () {
    final service = CpapTherapyService();
    final captured = DateTime(2026, 10, 6, 7, 30);
    final samples = [
      DirectMetricSample(
        sourceId: 'ble:test',
        deviceId: 'test',
        deviceName: 'ResMed',
        metric: 'Usage time',
        value: 420,
        unit: 'min',
        capturedAt: captured,
      ),
      DirectMetricSample(
        sourceId: 'ble:test',
        deviceId: 'test',
        deviceName: 'ResMed',
        metric: 'AHI',
        value: 2.4,
        unit: 'events/hour',
        capturedAt: captured,
      ),
      DirectMetricSample(
        sourceId: 'ble:test',
        deviceId: 'test',
        deviceName: 'ResMed',
        metric: 'Leak rate',
        value: 8.5,
        unit: 'L/min',
        capturedAt: captured,
      ),
    ];

    final nights = service.nightsFromSamples(samples, deviceId: 'test');
    expect(nights, hasLength(1));
    expect(nights.single.usageMinutes, 420);
    expect(nights.single.ahi, 2.4);
    expect(nights.single.leakRate, 8.5);
  });
}
