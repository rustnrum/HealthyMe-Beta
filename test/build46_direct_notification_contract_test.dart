import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Garmin and IDO senders are dispatched independently of vendor apps', () {
    final source = File('native/android/SalusNotificationListenerService.kt').readAsStringSync();
    expect(source, contains('SalusGarminNotificationSender.send(this, target, item)'));
    expect(source, contains('SalusWatchNotificationSender.send(this, target, item)'));
    expect(source, isNot(contains('postCompanionAlert')));
  });

  test('watch switch is backed by installed native protocol senders', () {
    final source = File('lib/services/watch_notification_service.dart').readAsStringSync();
    final screen = File('lib/screens/watch_device_screen.dart').readAsStringSync();
    expect(source, contains("protocolId == 'garmin-family'"));
    expect(source, contains("protocolId == 'ido-veryfit-family'"));
    expect(source, contains("'deliverySupported': installed"));
    expect(screen, contains('Garmin GFDI installed (experimental)'));
  });

  test('GFDI stack implements handshake, notification update and attribute response', () {
    final code = File('native/android/SalusGarminGfdiCodec.kt').readAsStringSync();
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    for (final symbol in ['cobsEncode', 'cobsDecode', 'decodeGfdi',
                          'notificationUpdate', 'notificationAttributes',
                          'notificationControlAck', 'notificationSubscriptionResponse']) {
      expect(code, contains(symbol));
    }
    expect(sender, contains('registerGfdi()'));
    expect(sender, contains('sendGfdi('));
    expect(sender, contains('processGfdi('));
    expect(sender, contains('sendNextAttributeChunk()'));
    expect(sender, isNot(contains('postCompanionAlert')));
  });
}
