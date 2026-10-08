import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/watch_notification_service.dart';

void main() {
  test('companion relay does not count as independent watch delivery', () {
    final state = WatchNotificationState.fromMap({
      'accessEnabled': true,
      'masterEnabled': true,
      'deliverySupported': false,
    }, companionRelay: true);
    expect(state.deliverySupported, isFalse);
    expect(state.canAttempt, isFalse);
  });

  test('installed direct sender remains eligible independently', () {
    final state = WatchNotificationState.fromMap({
      'deliverySupported': true,
      'apps': <Map<String, dynamic>>[],
    });
    expect(state.canAttempt, isTrue);
    expect(state.deliverySupported, isTrue);
  });

  test('listener does not invoke a third-party companion relay', () {
    final source = File('native/android/SalusNotificationListenerService.kt')
        .readAsStringSync();
    expect(source, contains('SalusWatchNotificationSender.send(this, target, item)'));
    expect(source, contains('target.protocolId == "ido-veryfit-family"'));
    expect(source, contains('recordObservedApp'));
    expect(source, contains('recordEligibleNotification'));
    expect(source, isNot(contains('postCompanionAlert')));
    expect(source, isNot(contains('00002a46')));
  });

  test('watch UI is truthful about unavailable direct transport', () {
    final screen = File('lib/screens/watch_device_screen.dart').readAsStringSync();
    final service = File('lib/services/watch_notification_service.dart')
        .readAsStringSync();
    expect(screen, contains('Phone notifications on this watch'));
    expect(screen, contains('All Gmail accounts'));
    expect(screen, contains('Android notification access'));
    expect(screen, contains('No compatible local Bluetooth notification sender'));
    expect(screen, contains('Last notification seen:'));
    expect(screen, contains('Last allowed for forwarding:'));
    expect(service, contains('companionRelay: false'));
    expect(service, contains('masterEnabled'));
  });
}
