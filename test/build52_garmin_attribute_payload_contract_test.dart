import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Garmin attribute data follows Gadgetbridge ordering and empty actions', () {
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    final payload = File('native/android/SalusGarminNotificationAttributes.kt').readAsStringSync();
    final codec = File('native/android/SalusGarminGfdiCodec.kt').readAsStringSync();
    expect(sender, contains('SalusGarminNotificationAttributes.build('));
    expect(payload, contains('if (kind == 4) messageSize = item'));
    expect(payload, contains('byteArrayOf(0, 0, 0, 0)'));
    expect(payload, contains('if (messageSize != null) attributes.add(messageSize)'));
    expect(payload, contains('else -> return null'));
    expect(codec, contains('fun notificationAttributesRaw('));
    expect(sender, contains('Requested attribute IDs='));
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.17+55'));
  });
}
