import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Garmin negative-action label attribute 7 has no requested length', () {
    final attrs = File('native/android/SalusGarminNotificationAttributes.kt').readAsStringSync();
    expect(attrs, contains('if (kind in listOf(1, 2, 3)) {'));
    expect(attrs, isNot(contains('listOf(1, 2, 3, 7)')));
    expect(attrs, contains('7 -> byteArrayOf()'));
  });

  test('Out-of-window MLR ACK does not discard an independently valid inbound fragment', () {
    final mlr = File('native/android/SalusGarminMlrTransport.kt').readAsStringSync();
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    expect(mlr, isNot(contains('return Result(null, emptyList(), "invalid cumulative ACK")')));
    expect(mlr, contains(r'ignoredAck = "req=$request peerAck=$lastPeerAck sent=$nextSend seq=$sequence"'));
    expect(mlr, contains('return Result(data, emitted, ignoredAck)'));
    expect(sender, contains('Garmin MLR out-of-window ACK'));
    expect(sender, contains('incoming payload processed separately'));
  });

  test('Raw notification content is not logged when investigating 5034 selectors', () {
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    expect(sender, contains('val selectorHex = request.take(40).joinToString(" ")'));
    expect(sender, contains('Malformed/unknown 5034 attribute selectors (hex)='));
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.17+55'));
  });
}
