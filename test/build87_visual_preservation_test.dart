import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/screens/premium/salus87_ui.dart';

void main() {
  test('Build87 active dashboards preserve real data and approved image assets', () {
    final home=File('lib/screens/home_shell.dart').readAsStringSync();
    final workout=File('lib/screens/workout_screen.dart').readAsStringSync();
    final diet=File('lib/screens/diet/diet_shell.dart').readAsStringSync();
    final homeScreen=File('lib/screens/premium/salus_home_87.dart').readAsStringSync();
    final training=File('lib/screens/premium/salus_training_87.dart').readAsStringSync();
    final nutrition=File('lib/screens/premium/salus_nutrition_87.dart').readAsStringSync();
    expect(home,contains('SalusHome87()'));
    expect(home,contains('healthSyncProvider'));
    expect(home,contains('bottomNavigationBar: _SalusBottomNav('));
    expect(workout,contains('SalusTraining87('));
    expect(diet,contains('SalusNutrition87('));
    for(final service in ['RecoveryService.build(', 'HrvSourceService.resolve(',
      'SalusEnergyService.estimate(', 'HomeInsightService.build(',
      'ref.watch(dietLogStateProvider)', 'ref.watch(workoutStateProvider)']){
      expect(homeScreen,contains(service),reason:service);
    }
    expect(homeScreen, isNot(contains('Data.recovery')));
    expect(training,contains('ref.watch(workoutStateProvider)'));
    expect(nutrition,contains('ref.watch(dietLogStateProvider)'));
    expect(nutrition,contains('ref.watch(todayPlanStateProvider)'));
    for(final asset in [
      'assets/premium/salus_mountain_85.webp',
      'assets/premium/training_hero.jpg',
      'assets/premium/muscle_reference.jpg',
      'assets/premium/nutrition_photo77.jpg',
      'assets/preview84/img/ring_recovery.png',
      'assets/preview84/img/ring_calories.png',
    ]) {expect(File(asset).existsSync(),isTrue,reason:asset);}
    expect(File('pubspec.yaml').readAsStringSync(),contains('version: 0.21.51+89'));
  });

  for(final width in [320.0, 360.0, 412.0, 820.0]){
    testWidgets('Premium cards and approved ring fit width $width',(tester)async{
      await tester.binding.setSurfaceSize(Size(width,800));
      addTearDown(()=>tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home:Scaffold(backgroundColor:S87.bg,
        body:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(children:[
            S87Panel(child:LayoutBuilder(builder:(context,c){
              final ringSize=(c.maxWidth-135).clamp(102.0,154.0).toDouble();
              return Row(children:[
                S87ArtworkRing(asset:'assets/preview84/img/ring_recovery.png',
                  value:'—',caption:'Unavailable',size:ringSize,measured:false),
                const SizedBox(width:9),
                const Expanded(child:Column(children:[
                  S87MetricLine(icon:Icons.bedtime,color:S87.purple,label:'Sleep',value:'7h 47m'),
                  S87MetricLine(icon:Icons.favorite,color:S87.red,label:'RHR',value:'63 bpm'),
                ])),
              ]);
            })),
            const SizedBox(height:12),
            const Row(children:[
              Expanded(child:S87Stat(icon:Icons.directions_walk,title:'Steps',
                value:'—',detail:'recorded today',color:S87.green)),
              SizedBox(width:9),
              Expanded(child:S87Stat(icon:Icons.restaurant_menu,title:'Nutrition',
                value:'—',detail:'not logged',color:S87.orange)),
            ]),
          ]))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      expect(find.text('Unavailable'),findsOneWidget);
    });
  }
}
