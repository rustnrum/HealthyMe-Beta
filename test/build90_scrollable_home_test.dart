import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthy_me/screens/premium/salus_home_87.dart';
import 'package:healthy_me/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Home is exactly the approved scrollable module layout', () {
    final home = File('lib/screens/premium/salus_home_87.dart').readAsStringSync();
    final nav = File('lib/screens/home_shell.dart').readAsStringSync();
    expect(home, contains('PageStorageKey<String>(\'salus-scrollable-home-90\')'));
    for (final title in [
      'Recovery Score', 'AI Insight', "Today's Nutrition", "Today's Workout",
      'Daily Measurements', 'Recent Trends', 'Key Health Metrics', 'Upcoming Care',
    ]) {
      expect(home, contains(title), reason: title);
    }
    expect(home, contains('assets/premium/salus_wordmark_90.png'));
    expect(home, contains('assets/premium/salus_mountain_85.webp'));
    expect(nav, contains("'Home'"));
    expect(nav, contains("'Training'"));
    expect(nav, contains("'Health'"));
    expect(nav, contains("'Discover'"));
    expect(nav, contains('bottomNavigationBar: _SalusBottomNav('));
    expect(home, isNot(contains('Data.recovery')));
    expect(home, isNot(contains('Ring HRV firmware history')));
    expect(home, isNot(contains('bodyBatteryRecords')));
  });

  // Match lib/main.dart: the production app overrides this provider after loading storage.
  // Without it, tests crash before any layout assertions can run.
  testWidgets('Larger accessibility text can scroll without overflow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [initialAppStateProvider.overrideWithValue(const HealthyMeState())],
      child: const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.35)),
        child: Scaffold(body: SalusHome87()),
      ),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Dynamic hero must expand to accommodate text, not clip its children.
    expect(tester.getSize(find.byKey(const Key('salus-home-hero-90'))).height,
      greaterThan(264));
    for (var i = 0; i < 7; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -480));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  for (final width in [320.0, 360.0, 412.0, 820.0]) {
    testWidgets('Scrollable real-data Home does not overflow at $width', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(
        overrides: [initialAppStateProvider.overrideWithValue(const HealthyMeState())],
        child: const MaterialApp(home: Scaffold(body: SalusHome87())),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Recovery Score'), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -480));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Upcoming Care'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
