import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Build 84 uses original graphic assets for all three mockup screens', () {
    for (final name in [
      'hero_mountain', 'ring_recovery', 'ring_steps', 'ring_calories',
      'spark_rhr', 'spark_hrv', 'sleep_bar', 'body_battery',
      'trend_recovery', 'trend_skin', 'avatar',
    ]) {
      expect(File('assets/preview84/img/$name.png').existsSync(), isTrue,
          reason: 'Missing original graphic: $name');
    }
    final home = File('lib/screens/preview84/screens/home_screen.dart').readAsStringSync();
    final health = File('lib/screens/preview84/screens/health_screen.dart').readAsStringSync();
    final trends = File('lib/screens/preview84/screens/trends_screen.dart').readAsStringSync();
    expect(home, contains("assets/preview84/img/ring_recovery.png"));
    expect(health, contains("assets/preview84/img/body_battery.png"));
    expect(health, contains("assets/preview84/img/sleep_bar.png"));
    expect(trends, contains("assets/preview84/img/trend_recovery.png"));
    expect(trends, contains("assets/preview84/img/trend_skin.png"));
    expect(File('lib/app.dart').readAsStringSync(), contains("'/preview84'"));
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.46+84'));
  });
}
