import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/ble_protocol_profiles.dart';
import 'package:healthy_me/services/device_category_service.dart';

void main() {
  test('standard battery is vendor independent', () {
    final report = BleProtocolProfiles.analyze(const ['180f']);
    expect(report.allCapabilities, contains('Battery'));
  });

  test('standard heart rate is vendor independent', () {
    final report = BleProtocolProfiles.analyze(const ['180d']);
    expect(report.allCapabilities, contains('Heart rate'));
  });

  test('hearing does not classify as ring', () {
    final category = DeviceCategoryService.category(
      deviceKind: 'Bluetooth device',
      name: 'Hearing Aid',
    );
    expect(category, isNot('Ring'));
  });

  test('known built-in families advertise readers only when implemented', () {
    expect(BleProtocolProfiles.hasBuiltInReader('garmin-family'), isTrue);
    expect(BleProtocolProfiles.hasBuiltInReader('ring-uart-v1'), isTrue);
    expect(BleProtocolProfiles.hasBuiltInReader('cpap-family'), isTrue);
    expect(BleProtocolProfiles.hasBuiltInReader('ido-veryfit-family'), isFalse);
  });
}
