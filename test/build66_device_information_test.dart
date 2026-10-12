import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/ble_device_information_service.dart';

void main() {
  test('device identity decodes firmware and hardware independently', () {
    final info = BleDeviceInformation.fromJson({
      'deviceId': 'AA:BB', 'deviceName': 'Ring', 'checkedAt': '2026-10-12T00:00:00Z',
      'status': 'complete', 'disAvailable': true,
      'values': {
        'manufacturer': 'Example', 'model': 'R02',
        'hardware': 'RY02', 'firmware': '3.00.33',
      },
      'serviceUuids': ['0000180a-0000-1000-8000-00805f9b34fb'],
      'notes': <String>[], 'firmwareHistory': <String>[],
    });
    expect(info.firmware, '3.00.33');
    expect(info.hardware, 'RY02');
    expect(info.serviceUuids, hasLength(1));
    expect(BleDeviceInformation.fromJson(info.toJson()).firmware, '3.00.33');
  });

  test('firmware change only recorded between confirmed different revisions', () {
    final previous = BleDeviceInformation.fromJson({
      'deviceId': 'A', 'deviceName': 'Ring',
      'checkedAt': '2026-10-11T00:00:00Z', 'status': 'complete',
      'values': {'firmware': '3.00.17'},
      'firmwareHistory': <String>[],
    });
    final now = DateTime.utc(2026, 10, 12);
    expect(BleDeviceInformationService.revisionHistory(previous, null, now), isEmpty);
    expect(BleDeviceInformationService.revisionHistory(previous, '3.00.17', now), isEmpty);
    final history = BleDeviceInformationService.revisionHistory(
        previous, '3.00.33', now);
    expect(history, hasLength(1));
    expect(history.single, contains('3.00.17 → 3.00.33'));
  });

  test('unknown fields stay unavailable rather than fabricated', () {
    final info = BleDeviceInformation.fromJson({
      'deviceId': 'C', 'deviceName': 'Unknown', 'status': 'service-not-exposed',
      'values': <String, String>{},
    });
    expect(info.firmware, isNull);
    expect(info.hardware, isNull);
    expect(info.disAvailable, isFalse);
  });

  test('native device information probe is standard GATT and read-only', () {
    final native = File('native/android/SalusBleDeviceInfoReader.kt').readAsStringSync();
    expect(native, contains('0000180a-0000-1000-8000-00805f9b34fb'));
    expect(native, contains('00002a26-0000-1000-8000-00805f9b34fb'));
    expect(native, contains('00002a27-0000-1000-8000-00805f9b34fb'));
    expect(native, contains('readCharacteristic('));
    expect(native, isNot(contains('writeCharacteristic(')));
    expect(native, isNot(contains('createBond(')));
    expect(native, isNot(contains('00002a25-0000-1000-8000-00805f9b34fb')));
  });

  test('cache keys encode a device id safely and consistently', () {
    expect(BleDeviceInformationService.cacheKey('AA:BB'),
        BleDeviceInformationService.cacheKey('AA:BB'));
    expect(BleDeviceInformationService.cacheKey('AA:BB'),
        isNot(BleDeviceInformationService.cacheKey('CC:DD')));
  });
}
