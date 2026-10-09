import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Garmin notification subscription preserves watch vs phone state', () {
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    final codec = File('native/android/SalusGarminGfdiCodec.kt').readAsStringSync();
    expect(sender, contains('subscriptionSeen = true'));
    expect(sender, contains('subscribed = enabledOnWatch && hostAllowed'));
    expect(sender, contains('enabledOnWatch, hostAllowed, sequence'));
    expect(sender, contains('subscriptionSeen && !subscribed'));
    expect(sender, contains('!subscriptionSeen'));
    expect(codec, contains('phoneNotificationsAllowed: Boolean'));
    expect(codec, contains('requestedByWatch: Boolean'));
    expect(codec, contains('if (phoneNotificationsAllowed) 0 else 1'));
    expect(codec, contains('if (requestedByWatch) 1 else 0'));
    expect(sender, isNot(contains('sendKeepAlivePing()')));
    expect(sender, isNot(contains('sendAckFrame(handle, rxSeq)')));
  });
}
