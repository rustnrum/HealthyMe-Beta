import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/widgets/salus_premium_visuals.dart';

void main(){
  test('Build 75 has authored dark assets and no missing files',(){
    final pubspec=File('pubspec.yaml').readAsStringSync();
    expect(RegExp(r'^version: 0\.21\.(37|38|39|40|41|42|43|44|45|46|47|48|49)\+(75|76|77|78|79|80|81|82|83|84|85|86|87)$',multiLine:true).hasMatch(pubspec),isTrue);
    expect(pubspec,contains('assets/premium/'));
    for(final filename in ['training_hero.jpg',
      'meal_illustration.jpg','muscle_reference.jpg']){
      expect(File('assets/premium/$filename').lengthSync(),greaterThan(5000));
    }
    final app=File('lib/app.dart').readAsStringSync();
    expect(app,contains("'/backup':"));
    expect(app.contains('builder: (context, child) => Stack(fit: StackFit.expand'),isFalse);
    final theme=File('lib/widgets/salus_premium_ui.dart').readAsStringSync();
    expect(theme,contains('ValueNotifier<bool>(false)'));
    expect(theme,contains('salus_premium_light_v2'));
    expect(File('lib/screens/health/health_shell.dart').readAsStringSync(),
      contains('SalusHealth77()'));
  });
  testWidgets('Colored gauge paints with double precision geometry',(tester)async{
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Center(
      child:SalusGauge(value:38.0,total:100.0,center:'38',
        caption:'Data coverage',color:Colors.cyan,size:120)))));
    expect(find.text('38'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Unknown calorie macros do not draw fake completed nutrition',(tester)async{
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:SalusMacroRing(
      protein:null,carbs:null,fat:null,kcal:null,target:null))));
    expect(find.text('—'),findsOneWidget);
  });
}
