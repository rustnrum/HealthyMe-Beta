import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firmware HRV history retains valid, timestamped index buckets', () {
    final decoder = File('native/android/SalusRingHrvLogDecoder.kt')
        .readAsStringSync();
    final reader = File('native/android/SalusProtocolReader.kt')
        .readAsStringSync();

    // Command-57 packet integrity and page layout: first page has 12 values,
    // continuation pages have 13. Preserve the firmware's true time slots.
    expect(decoder, contains('val checksum ='));
    expect(decoder, contains('if (checksum !='));
    expect(decoder, contains('index != expectedPage'));
    expect(decoder, contains('val valueStart = if (first) 3 else 2'));
    expect(decoder, contains('val count = if (first) 12 else 13'));
    expect(decoder, contains('val minute = slot.toLong() * rangeMinutes'));
    expect(decoder, contains('localMidnightMs + minute * 60_000L'));
    expect(decoder, contains('value == 0 || value == 255'));
    expect(decoder, contains('minute >= 1440'));

    expect(reader, contains('addHistoryMetric('));
    expect(reader, contains('"Ring HRV proxy"'));
    expect(reader, isNot(contains('ringHrvProxySum')));
    expect(reader, contains('ringStepPacketCount'));
    expect(reader, contains('ringStepsComplete'));
  });

  test('experimental index history remains distinct from verified RMSSD', () {
    final screen = File('lib/screens/device_information_screen.dart')
        .readAsStringSync();
    expect(screen, contains('Ring HRV firmware proxy history'));
    expect(screen, contains('NOT validated RMSSD'));

    final decoder = File('native/android/SalusRingHrvLogDecoder.kt')
        .readAsStringSync();
    expect(decoder, contains('NOT verified RMSSD'));
    // Decoding is pure packet parsing, never Bluetooth I/O or settings writes.
    expect(decoder, isNot(contains('BluetoothGatt')));
    expect(decoder, isNot(contains('writeCharacteristic(')));
    expect(decoder, isNot(contains('ringSend(')));
  });
}
