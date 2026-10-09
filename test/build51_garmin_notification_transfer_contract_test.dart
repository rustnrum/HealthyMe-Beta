import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Garmin content transfer advances only on actual watch 5035 ACK', () {
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    final model = File('native/android/SalusGarminNotificationTransfer.kt').readAsStringSync();
    expect(sender, contains('notificationTransfer.acknowledge(status, transferStatus)'));
    expect(sender, contains('SalusGarminNotificationTransfer.Ack.Complete'));
    expect(sender, contains('SalusGarminGfdiCodec.notificationDataAck(sequence)'));
    expect(sender, contains('Garmin accepted notification data'));
    expect(sender, contains('Garmin rejected notification data'));
    expect(sender, contains('Garmin notification ACK timeout'));
    expect(sender, isNot(contains('stage("Notification content sent"')));
    expect(model, contains('if (!active || !awaitingAck) return Ack.Unexpected'));
    expect(model, contains('if (offset >= bytes.size)'));
    expect(model, contains('awaitingAck = true'));
  });
}
