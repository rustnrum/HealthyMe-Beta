import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Build 86 restores the existing live Home, not the Build85 sample mockup', () {
    final shell = File('lib/screens/home_shell.dart').readAsStringSync();
    final oldHome = File('lib/screens/premium/salus_home_87.dart').readAsStringSync();
    expect(shell, contains('SalusHome87()'));
    expect(shell, isNot(contains('SalusHome85()')));
    expect(shell, contains('SalusVoiceLauncher('));
    expect(shell, contains('bottomNavigationBar: _SalusBottomNav('));
    expect(shell, contains('healthSyncProvider'));
    for (final liveService in [
      'ref.watch(appStateProvider)',
      'RecoveryService.build(',
      'HrvSourceService.resolve(',
      'SalusEnergyService.estimate(',
      'HomeInsightService.build(',
      'ref.watch(dietLogStateProvider)',
      'ref.watch(workoutStateProvider)',
    ]) {
      expect(oldHome, contains(liveService), reason: liveService);
    }
    expect(oldHome, isNot(contains('Data.recovery')));
  });

  test('Build 86 preserves original app identity, release identity, and references', () {
    final manifest = File('native/android/AndroidManifest.xml').readAsStringSync();
    final script = File('scripts/prepare_android.sh').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(manifest, contains('android:label="Salus"'));
    expect(script, contains('com.rustnrum.healthyme.beta03'));
    expect(pubspec, contains('version: 0.21.53+91'));
    for (final name in [
      'assets/premium/salus_mountain_79.webp',
      'assets/premium/salus_mountain_85.webp',
      'assets/preview84/img/ring_recovery.png',
    ]) {
      expect(File(name).existsSync(), isTrue, reason: name);
    }
  });
}
