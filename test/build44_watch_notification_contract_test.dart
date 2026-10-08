import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/watch_notification_service.dart';

void main() {
  test('companion relay is not misreported as a direct BLE sender', () {
    final state = WatchNotificationState.fromMap({
      'accessEnabled': true,
      'masterEnabled': true,
      'deliverySupported': false,
      'lastObservedAt': 1000000000000,
      'apps': <Map<String, dynamic>>[{
        'packageName': 'com.google.android.apps.messaging',
        'label': 'Text messages',
        'enabled': true,
      }],
    }, companionRelay: true);
    expect(state.companionRelay, isTrue);
    expect(state.deliverySupported, isFalse);
    expect(state.canAttempt, isTrue);
    expect(state.enabledAppCount, 1);
    expect(state.lastObservedAt, isNotNull);
  });

  test('direct sender remains separate from companion relay', () {
    final state = WatchNotificationState.fromMap({
      'deliverySupported': true,
      'apps': <Map<String, dynamic>>[],
    });
    expect(state.deliverySupported, isTrue);
    expect(state.companionRelay, isFalse);
    expect(state.canAttempt, isTrue);
  });

  test('Android listener routes IDO directly and other watches via phone alerts', () {
    final source = File('native/android/SalusNotificationListenerService.kt')
        .readAsStringSync();
    expect(source, contains('SalusWatchNotificationSender.send(this, target, item)'));
    expect(source, contains('postCompanionAlert(item, label)'));
    expect(source, contains('item.packageName == packageName'));
    expect(source, contains('SalusWatchNotificationStore.isAllowed'));
    expect(source, contains('recordEligibleNotification'));
    expect(source, contains('NotificationManager.IMPORTANCE_DEFAULT'));
    expect(source, contains('POST_NOTIFICATIONS'));
    expect(source, isNot(contains('00002a46')));
  });

  test('watch UI shows transport honestly and retains filters and diagnostics', () {
    final screen = File('lib/screens/watch_device_screen.dart').readAsStringSync();
    final service = File('lib/services/watch_notification_service.dart').readAsStringSync();
    final manifest = File('native/android/AndroidManifest.xml').readAsStringSync();
    expect(screen, contains('Phone notifications on this watch'));
    expect(screen, contains('All Gmail accounts'));
    expect(screen, contains('Android notification access'));
    expect(screen, contains('Permission.notification.request()'));
    expect(screen, contains('Last notification seen:'));
    expect(screen, contains('Last allowed for forwarding:'));
    expect(screen, contains('does not confirm the watch received it'));
    expect(screen, contains('Check Garmin battery'));
    expect(service, contains('companionRelay'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('SalusNotificationListenerService'));
  });
}
