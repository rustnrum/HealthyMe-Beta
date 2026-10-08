import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/local_device_driver.dart';

class _FakeBleTransport implements SalusBleDriverTransport {
  final calls = <String>[];
  final outputs = <String, Map<dynamic, dynamic>>{};
  @override
  Future<Map<dynamic, dynamic>> invoke(
    String method, Map<String, dynamic> arguments,
  ) async {
    calls.add(method);
    return outputs[method] ?? <dynamic, dynamic>{};
  }
}

void main() {
  test('any unknown standard battery device uses the GATT reader', () async {
    final fake = _FakeBleTransport();
    fake.outputs['readStandardMetrics'] = {'metrics': {'Battery': 43.0}};
    final drivers = SalusLocalDeviceDrivers(transport: fake);
    final decision = drivers.match(
      name: 'Mystery sensor', protocolId: null, services: ['180f']);
    expect(decision.status, SalusDriverStatus.standardOnly);
    final result = await drivers.read(
      deviceId: 'AA', deviceName: 'Mystery sensor', protocolId: null,
      deviceKind: 'Bluetooth device', advertisedServices: ['180f'],
      duration: const Duration(seconds: 3),
    );
    expect(result['metrics']['Battery'], 43.0);
    expect(fake.calls, ['readStandardMetrics']);
  });

  test('built-in protocol uses installed reader rather than guessed values', () async {
    final fake = _FakeBleTransport();
    fake.outputs['readProtocolMetrics'] = {'metrics': {'Battery': 91.0}};
    final drivers = SalusLocalDeviceDrivers(transport: fake);
    final result = await drivers.read(
      deviceId: 'BB', deviceName: 'My ring', protocolId: 'ring-uart-v1',
      deviceKind: 'Ring', duration: const Duration(seconds: 3),
    );
    expect(result['metrics']['Battery'], 91.0);
    expect(fake.calls, ['readProtocolMetrics']);
  });

  test('recognized-only family does not send proprietary commands', () async {
    final fake = _FakeBleTransport();
    final drivers = SalusLocalDeviceDrivers(transport: fake);
    final result = await drivers.read(
      deviceId: 'CC', deviceName: 'Wearable',
      protocolId: 'ido-veryfit-family', deviceKind: 'Watch',
      duration: const Duration(seconds: 2),
    );
    expect(result['metrics'], isEmpty);
    expect(result['driverStatus'], SalusDriverStatus.recognizedOnly.name);
    expect(fake.calls, ['readStandardMetrics']);
  });

  test('no device name heuristic can create fabricated metrics', () async {
    final fake = _FakeBleTransport();
    final drivers = SalusLocalDeviceDrivers(transport: fake);
    final result = await drivers.read(
      deviceId: 'DD', deviceName: 'New Brand Ring', protocolId: null,
      deviceKind: 'Ring', duration: const Duration(seconds: 2),
    );
    expect(result['metrics'], isEmpty);
    expect(fake.calls, ['readStandardMetrics']);
  });

  test('native rejection falls back to standard GATT', () async {
    final fake = _FakeBleTransport();
    fake.outputs['readProtocolMetrics'] = {'fallbackStandard': true};
    fake.outputs['readStandardMetrics'] = {'metrics': {'Battery': 57.0}};
    final drivers = SalusLocalDeviceDrivers(transport: fake);
    final result = await drivers.read(
      deviceId: 'EE', deviceName: 'Ring', protocolId: 'ring-uart-v1',
      deviceKind: 'Ring', duration: const Duration(seconds: 2),
    );
    expect(result['metrics']['Battery'], 57.0);
    expect(fake.calls, ['readProtocolMetrics', 'readStandardMetrics']);
  });
}
