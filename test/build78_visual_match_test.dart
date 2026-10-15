import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/widgets/salus77_design.dart';
import 'package:healthy_me/widgets/salus_premium_visuals.dart';
import 'package:healthy_me/widgets/module_menu_button.dart';

void main(){
  test('Approved recovery-led Home and circular tiles exist',(){
    final home=File('lib/screens/premium/salus_home_77.dart').readAsStringSync();
    expect(home,contains("S77Section('Recovery Score'"));
    expect(home.split('S77RingTile(').length-1,4);
    expect(home,contains('PremiumLineChart('));
    expect(home.contains('salus_night_mountains.jpg'),false);
    expect(File('pubspec.yaml').readAsStringSync(),contains('version: 0.21.49+87'));
  });
  test('Existing module navigation remains unchanged',(){
    final home=File('lib/screens/home_shell.dart').readAsStringSync();
    expect(home,contains('bottomNavigationBar: _SalusBottomNav('));
    for(final path in ['lib/screens/diet/diet_shell.dart','lib/screens/health/health_shell.dart']){
      expect(File(path).readAsStringSync(),contains('HealthyMeModuleMenuButton('));
    }
  });
  testWidgets('Circular progress tile paints with unknown and known values',(tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Column(children:[
      S77RingTile(label:'Steps',value:'3,000',icon:Icons.directions_walk,
        color:Colors.teal,fraction:.3),
      S77RingTile(label:'Nutrition',value:'—',icon:Icons.restaurant,
        color:Colors.orange,fraction:null),
    ]))));
    expect(find.text('30%'),findsOneWidget);
    expect(find.text('—'),findsWidgets);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Module selector is labeled when enabled',(tester)async{
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:HealthyMeModuleMenuButton(
      current:HealthyMeModule.fitness,showLabel:true,lightSurface:true,
      iconColor:Colors.black,onSelected:(_){},))));
    expect(find.text('Modules'),findsOneWidget);
    expect(tester.takeException(),isNull);
    SalusV.lightMode=false;
  });
}
