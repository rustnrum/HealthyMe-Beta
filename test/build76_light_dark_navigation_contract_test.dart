import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/widgets/salus_premium_visuals.dart';

void main() {
  test('Build 76 keeps Home subnavigation and original module selector', () {
    final home = File('lib/screens/home_shell.dart').readAsStringSync();
    expect(home, contains('bottomNavigationBar: _SalusBottomNav('));
    expect(home, contains('HealthyMeModuleMenuButton('));
    expect(home, isNot(contains('PremiumDestinationBar(index: 0')));
    final diet = File('lib/screens/diet/diet_shell.dart').readAsStringSync();
    expect(diet, contains('bottomNavigationBar: _DietBottomNav('));
    final health = File('lib/screens/health/health_shell.dart').readAsStringSync();
    expect(health, contains('bottomNavigationBar: _HealthBottomNav('));
    final training = File('lib/screens/workout_screen.dart').readAsStringSync();
    expect(training, isNot(contains('bottomNavigationBar: _tab')));
  });
  test('Both light and dark premium roles are real palettes', () {
    SalusV.lightMode = false;
    final darkBackground = SalusV.background;
    final darkText = SalusV.ink;
    SalusV.lightMode = true;
    expect(SalusV.background, isNot(darkBackground));
    expect(SalusV.ink, isNot(darkText));
    expect(SalusV.background.computeLuminance(), greaterThan(.75));
    expect(SalusV.ink.computeLuminance(), lessThan(.12));
    SalusV.lightMode = false;
  });
  test('Mountains are absent from the premium Home view', () {
    final home = File('lib/screens/premium/salus_premium_home.dart').readAsStringSync();
    expect(home, contains('SalusColorHero('));
    expect(home, isNot(contains('salus_night_mountains.jpg')));
    expect(File('assets/premium/salus_night_mountains.jpg').existsSync(), false);
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.42+80'));
  });
  testWidgets('Default premium card padding is compile-time constant', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SalusGlass(child: Text('Premium panel')))));
    expect(find.text('Premium panel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('A theme-aware card renders in light and dark',(tester) async {
    for(final mode in [false,true]) {
      SalusV.lightMode = mode;
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:SalusGlass(child:const Text('Real data')))));
      expect(find.text('Real data'),findsOneWidget);
      expect(tester.takeException(),isNull);
    }
    SalusV.lightMode = false;
  });
}
