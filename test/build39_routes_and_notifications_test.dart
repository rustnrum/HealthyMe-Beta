import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Data Sources and plan cards open their intended modules', () {
    final source = File('lib/screens/more_screen.dart').readAsStringSync();
    expect(source, contains('const ConnectionsScreen()'));
    expect(source, isNot(contains('const SourcesScreen()')));
    expect(source, contains("pushNamed('/workout')"));
    expect(source, contains("pushNamed('/diet')"));
    expect(source, contains("pushNamed('/recovery')"));
  });

  test('watch notifications stay opt-in but initialize app filters on enable', () {
    final source = File('native/android/SalusWatchNotificationStore.kt')
        .readAsStringSync();
    expect(source, contains('initialAppsConfigured'));
    expect(source, contains('if (enabled &&'));
    expect(source, contains('if (!p.contains(pref)) editor.putBoolean(pref, true)'));
    expect(source, contains('"deliverySupported" to (protocolId == "ido-veryfit-family")'));
  });

  test('notification diagnostics distinguish observed from eligible alerts', () {
    final listener = File('native/android/SalusNotificationListenerService.kt')
        .readAsStringSync();
    final screen = File('lib/screens/watch_device_screen.dart').readAsStringSync();
    expect(listener, contains('recordObservedApp'));
    expect(listener, contains('recordEligibleNotification'));
    expect(screen, contains('Last notification seen:'));
    expect(screen, contains('Last allowed for forwarding:'));
    expect(screen, contains('does not confirm the watch received it'));
  });

  test('auto direct sync preserves manual source and excludes CPAP', () {
    final sync = File('lib/state/health_sync_provider.dart').readAsStringSync();
    expect(sync, contains('_refreshSavedDirectDevices()'));
    expect(sync, contains("device.protocolId == 'cpap-family'"));
    expect(sync, contains('registeredDevices: savedDevices'));
    expect(sync, isNot(contains('staleAfterRefresh')));
  });

  test('beta AI entry does not open a pretend functioning chat', () {
    final app = File('lib/app.dart').readAsStringSync();
    expect(app, contains('Salus AI is not available in this beta'));
    expect(app, isNot(contains('const AiCoachScreen()')));
  });
}
