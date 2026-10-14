import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/widgets/salus77_design.dart';

void main() {
  test('Build 80 keeps original navigation and implements a full Home background', () {
    final home = File('lib/screens/premium/salus_home_77.dart').readAsStringSync();
    final visuals = File('lib/widgets/salus77_design.dart').readAsStringSync();
    final shell = File('lib/screens/home_shell.dart').readAsStringSync();
    expect(home, contains('SalusMountainBackdrop(light:light'));
    expect(home, isNot(contains("Image.asset('assets/premium/salus_mountain_79.webp'")));
    expect(visuals, contains("Image.asset('assets/premium/salus_mountain_79.webp'"));
    expect(visuals, contains('Positioned.fill('));
    expect(home.split('S77RingTile(').length - 1, 4);
    expect(home, contains('S77RestingHeartChart('));
    expect(shell, contains('bottomNavigationBar: _SalusBottomNav('));
    expect(File('assets/premium/salus_mountain_79.webp').lengthSync(), greaterThan(10000));
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.46+84'));
  });

  test('Main energy is source independent and device telemetry is not faked', () {
    final home = File('lib/screens/premium/salus_home_77.dart').readAsStringSync();
    expect(home, contains('SalusEnergyService.estimate('));
    expect(home, contains("'Salus Energy'"));
    expect(home, isNot(contains("s.metric == 'Body battery'")));
    expect(home, isNot(contains('_deviceBodyBattery')));
    final energy = File('lib/services/salus_energy_service.dart').readAsStringSync();
    expect(energy, contains('Needs recent sleep plus a personal HRV or resting-heart-rate baseline.'));
    expect(energy, contains("quality: 'Provisional estimate'"));
  });

  test('Product-facing branding remains Salus without changing user data identity', () {
    final manifest = File('native/android/AndroidManifest.xml').readAsStringSync();
    final app = File('lib/app.dart').readAsStringSync();
    expect(manifest, contains('android:label="Salus"'));
    expect(app, contains("title: 'Salus'"));
    // Changing the existing applicationId or package namespace would create
    // a new app, rather than installing over the user's saved Salus app.
    expect(manifest, isNot(contains('android:label="Healthy Me"')));
  });

  testWidgets('Larger circular tiles fit a phone-width column', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 174, child: S77RingTile(
        label: 'Sleep', value: '8h 15m', detail: 'last recorded',
        icon: Icons.bedtime, color: Colors.purple, fraction: 0.92,
      )),
    ))));
    expect(find.text('92%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Resting-HR graph uses measured values and handles missing history', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 190, child: S77RestingHeartChart(
        values: [57.0, 62.0, 64.0], height: 114,
      )),
    ))));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 190, child: S77RestingHeartChart(
        values: [null, 57.0], height: 114,
      )),
    ))));
    expect(find.text('More recorded days needed for a trend'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
