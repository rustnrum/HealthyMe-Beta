import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android cannot request Bluetooth or run native hardware channels', () {
    final manifest=File('native/android/AndroidManifest.xml').readAsStringSync();
    final activity=File('native/android/MainActivity.kt').readAsStringSync();
    final prepare=File('scripts/prepare_android.sh').readAsStringSync();
    expect(manifest, isNot(contains('BLUETOOTH')));
    expect(manifest, isNot(contains('bluetooth_le')));
    expect(manifest, isNot(contains('SalusNotificationListenerService')));
    expect(activity, isNot(contains('android.bluetooth')));
    expect(activity, isNot(contains('source_discovery')));
    expect(prepare, isNot(contains('cp native/android/*.kt')));
    expect(prepare, contains('SalusBackupBridge.kt'));
  });

  test('Production sync and HRV are Health Connect only', () {
    final sync=File('lib/state/health_sync_provider.dart').readAsStringSync();
    final metric=File('lib/screens/metric_detail_screen.dart').readAsStringSync();
    final history=File('lib/services/metric_history_service.dart').readAsStringSync();
    final sources=File('lib/screens/connections_screen.dart').readAsStringSync();
    expect(sync, contains('HealthConnectService()'));
    expect(sync, isNot(contains('DirectMetricService()')));
    expect(metric, isNot(contains('Refresh ring history')));
    expect(metric, isNot(contains('Ring HRV firmware history')));
    expect(history, contains('HEART_RATE_VARIABILITY_RMSSD'));
    expect(history, isNot(contains('DirectMetricService().loadSamples')));
    expect(sources, contains('Health Connect'));
    expect(sources, isNot(contains('Bluetooth')));
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.54+92'));
  });

  test('Existing app identity, data services and premium screens remain', () {
    final shell=File('lib/screens/home_shell.dart').readAsStringSync();
    final app=File('lib/app.dart').readAsStringSync();
    expect(shell, contains('SalusHome87()'));
    expect(shell, contains('healthSyncProvider'));
    expect(shell, contains('bottomNavigationBar: _SalusBottomNav('));
    expect(app, contains('MorningCheckInGate(child: HomeShell())'));
    expect(File('scripts/prepare_android.sh').readAsStringSync(),
      contains('com.rustnrum.healthyme.beta03'));
    expect(File('lib/screens/workout_screen.dart').readAsStringSync(),
      contains('SalusTraining87('));
    expect(File('lib/screens/diet/diet_shell.dart').readAsStringSync(),
      contains('SalusNutrition87('));
  });
}
