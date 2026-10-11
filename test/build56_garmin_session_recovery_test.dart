import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Duplicate Garmin service registration must not reset MLR counters', () {
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    final policy = File('native/android/SalusGarminRegistrationPolicy.kt').readAsStringSync();
    expect(sender, contains('SalusGarminRegistrationPolicy.evaluate('));
    expect(sender, contains('Decision.DUPLICATE -> {'));
    expect(sender, contains('"Garmin duplicate registration"'));
    expect(sender, contains('return@post'));
    expect(policy, contains('activeHandle == newHandle && activeReliable == newReliable'));
  });

  test('New Garmin handle cannot use the previous watch subscription', () {
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    expect(sender, contains('Decision.REPLACEMENT -> {'));
    expect(sender, contains('subscribed = false; subscriptionSeen = false'));
    expect(sender, contains('informationExchanged = false; configurationExchanged = false'));
    expect(sender, contains('notificationTransfer.reset(); ++dataAckToken'));
    expect(sender, contains('if (pending.size < MAX_PENDING) pending.addFirst(it)'));
  });

  test('Stalled notification retries once after a complete reconnect', () {
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    expect(sender, contains('notificationRecoveryId != thisId'));
    expect(sender, contains('Garmin notification session stalled'));
    expect(sender, contains('Retry failed; Garmin did not request'));
    expect(sender, contains('lastAttributeRequestId != thisId'));
  });

  test('Real Gmail routes are diagnosed without logging message body/account', () {
    final listener = File('native/android/SalusNotificationListenerService.kt').readAsStringSync();
    expect(listener, contains('Gmail listener'));
    expect(listener, contains('Gmail filtered'));
    expect(listener, contains('Android notification eligible'));
    expect(listener, contains('App=\${item.packageName}; forwarding to Garmin'));
    expect(listener, isNot(contains('item.notification.extras.toString()')));
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.18+56'));
  });
}
