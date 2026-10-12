import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firmware HRV history retains buckets without treating them as RMSSD', () {
    final decoder = File('native/android/SalusRingHrvLogDecoder.kt')
        .readAsStringSync();
    final reader = File('native/android/SalusProtocolReader.kt')
        .readAsStringSync();
    expect(decoder, contains('slot.toLong() * rangeMinutes * 60_000L'));
    expect(decoder, contains('raw == 0 || raw == 255'));
    expect(decoder, contains('index != expectedPage'));
    expect(reader, contains('addHistoryMetric('));
    expect(reader, contains('"Ring HRV proxy"'));
    expect(reader, isNot(contains('ringHrvProxySum')));
    expect(reader, contains('ringStepsComplete'));
    expect(reader, contains('ringStepPacketCount'));
  });

  test('experimental history remains separate from clinically validated HRV', () {
    final screen = File('lib/screens/device_information_screen.dart')
        .readAsStringSync();
    expect(screen, contains('Ring HRV firmware proxy history'));
    expect(screen, contains('NOT validated RMSSD'));
    final decoder = File('native/android/SalusRingHrvLogDecoder.kt')
        .readAsStringSync();
    expect(decoder, contains('No Bluetooth I/O or writes take place'));
  });
}
