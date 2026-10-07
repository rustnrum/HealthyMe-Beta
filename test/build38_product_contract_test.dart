import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home puts metrics before device batteries and Today plan', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();
    final metric = source.indexOf("label: 'Sleep'");
    final batteries = source.indexOf("'Device batteries'");
    final today = source.indexOf('_TodayPlanCard(');

    expect(metric, greaterThan(0));
    expect(batteries, greaterThan(metric));
    expect(today, greaterThan(batteries));
    expect(source, contains('SalusMountainBackground'));
  });

  test('sleep uses age guidance instead of a proprietary-looking score', () {
    final source = File('lib/screens/sleep_screen.dart').readAsStringSync();
    expect(source, isNot(contains('Sleep Score')));
    expect(source, isNot(contains('_ScoreRing')));
    expect(source, contains('_SleepTargetBadge'));
    expect(source, contains('Stages are from the same'));
    expect(
      source,
      contains('will not combine sleep duration from one provider with stages from another'),
    );
  });

  test('mountain background contains no grid or particle painter', () {
    final source =
        File('lib/widgets/salus_mountain_background.dart').readAsStringSync();
    expect(source, contains('hero_mountains.jpg'));
    expect(source, isNot(contains('CustomPainter')));
    expect(source, isNot(contains('drawCircle')));
  });

  test('watch notifications support app filters and Gmail accounts', () {
    final screen =
        File('lib/screens/watch_device_screen.dart').readAsStringSync();
    final listener = File(
      'native/android/SalusNotificationListenerService.kt',
    ).readAsStringSync();
    final sender =
        File('native/android/SalusWatchNotificationSender.kt').readAsStringSync();

    expect(screen, contains('Phone notifications on this watch'));
    expect(screen, contains('Text messages'));
    expect(screen, contains('All Gmail accounts'));
    expect(listener, contains('EXTRA_SUB_TEXT'));
    expect(sender, contains('"com.facebook.orca" -> 9'));
    expect(sender, contains('"com.whatsapp" -> 8'));
    expect(sender, contains('0x05, 0x03'));
  });

  test('CPAP screen keeps pairing unless user explicitly re-pairs', () {
    final screen =
        File('lib/screens/cpap_screen_v38.dart').readAsStringSync();
    final native =
        File('native/android/MainActivity.kt').readAsStringSync();

    expect(screen, contains('Typical pressure'));
    expect(screen, contains('Re-pair device'));
    expect(screen, contains('only when the CPAP displays a one-time code'));
    expect(native, contains('protectCpapPairing'));
    expect(native, contains('resetCpapPairing'));
  });
}
