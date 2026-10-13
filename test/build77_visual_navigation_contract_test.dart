import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/widgets/salus77_design.dart';
import 'package:healthy_me/widgets/salus_premium_visuals.dart';

void main(){
  test('All four designed overview screens are wired to original module shells',(){
    expect(File('lib/screens/home_shell.dart').readAsStringSync(),contains('SalusHome77()'));
    expect(File('lib/screens/diet/diet_shell.dart').readAsStringSync(),contains('SalusNutrition77('));
    expect(File('lib/screens/workout_screen.dart').readAsStringSync(),contains('SalusTraining77('));
    expect(File('lib/screens/health/health_shell.dart').readAsStringSync(),contains('SalusHealth77()'));
    for(final path in ['lib/screens/home_shell.dart','lib/screens/diet/diet_shell.dart','lib/screens/workout_screen.dart', 'lib/screens/health/health_shell.dart']){
      expect(File(path).readAsStringSync(),contains('HealthyMeModuleMenuButton('),reason:path);
    }
    expect(File('lib/screens/home_shell.dart').readAsStringSync(),contains('bottomNavigationBar: _SalusBottomNav('));
    expect(File('lib/screens/diet/diet_shell.dart').readAsStringSync(),contains('bottomNavigationBar: _DietBottomNav('));
    expect(File('lib/screens/health/health_shell.dart').readAsStringSync(),contains('bottomNavigationBar: _HealthBottomNav('));
    expect(File('pubspec.yaml').readAsStringSync(),contains('version: 0.21.43+81'));
  });
  test('No mountains or invented biometric readings in replacement screens',(){
    for(final path in ['lib/screens/premium/salus_home_77.dart','lib/screens/premium/salus_nutrition_77.dart',
      'lib/screens/premium/salus_training_77.dart','lib/screens/premium/salus_health_77.dart']){
      final text=File(path).readAsStringSync();
      expect(text,contains('Salus'),reason:path);
      expect(text.contains('salus_night_mountains.jpg'),isFalse,reason:path);
    }
  });
  testWidgets('Real-data-only empty macro and recovery rings render',(tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Column(children:[
      S77Arc(center:'—',caption:'No data',segments:const [],size:130),
      S77PairedChart(left:const [null,null],right:const [null,null],labels:const ['M','T']),
    ]))));
    expect(find.text('—'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Both theme palettes keep readable surface structure',(tester)async{
    for(final light in [false,true]){
      SalusV.lightMode=light;
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:S77Surface(child:const Text('Salus 77')))));
      expect(find.text('Salus 77'),findsOneWidget);
      expect(tester.takeException(),isNull);
    }
    SalusV.lightMode=false;
  });
}
