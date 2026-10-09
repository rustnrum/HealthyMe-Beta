import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('One persistent Garmin connection manager is used, not one per notification', () {
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    expect(sender, contains('ConcurrentHashMap<String, Session>()'));
    expect(sender, contains('private val pending = ArrayDeque<Alert>()'));
    expect(sender, contains('fun watch(context: Context, deviceId: String)'));
    expect(sender, contains('fun unwatch(deviceId: String)'));
    expect(sender, contains('private fun fail(code: String, detail: String)'));
    expect(sender, contains('private fun maybeSend()'));
    expect(sender, contains('"Watch requested content"'));
    expect(sender, contains('"Watch subscribed"'));
    expect(sender, isNot(contains('handler.postDelayed({ close() }, TIMEOUT_MS)')));
  });

  test('Native notification listener restores sessions and dispatches the installed senders', () {
    final listener = File('native/android/SalusNotificationListenerService.kt').readAsStringSync();
    expect(listener, contains('override fun onCreate()'));
    expect(listener, contains('SalusGarminNotificationSender.watch(this, it.deviceId)'));
    expect(listener, contains('SalusGarminNotificationSender.send(this, target, item)'));
    expect(listener, contains('SalusWatchNotificationSender.send(this, target, item)'));
    expect(listener, isNot(contains('postCompanionAlert')));
  });

  test('User gets direct protocol test and transport diagnostics', () {
    final screen = File('lib/screens/watch_device_screen.dart').readAsStringSync();
    final service = File('lib/services/watch_notification_service.dart').readAsStringSync();
    final bridge = File('native/android/MainActivity.kt').readAsStringSync();
    expect(screen, contains('Send test notification'));
    expect(screen, contains('Bluetooth transport:'));
    expect(screen, contains('Bluetooth event history'));
    expect(service, contains("sendWatchTestNotification"));
    expect(bridge, contains('"sendWatchTestNotification" ->'));
    expect(bridge, contains('SalusWatchTransportStatus.state(this, deviceId)'));
  });
}
