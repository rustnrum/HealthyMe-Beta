import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthy_me/widgets/salus_premium_ui.dart';
import 'package:healthy_me/services/ai_meal_planner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Premium dashboard has a readable no-history state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Center(
      child:PremiumLineChart(values:[null,null,null,null,null,null,null])))));
    expect(find.text('More recorded days needed for a trend'),findsOneWidget);
  });
  testWidgets('Unknown nutrition target remains unreported', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:PremiumProgress(
      label:'Protein', value:42, target:null, color:SalusSkin.green))));
    expect(find.text('42 g'),findsOneWidget);
    expect(find.textContaining('42 /'),findsNothing);
  });
  test('AI recipe extended macros preserve missing historical nutrient values', () {
    final old=SalusMealIdea.fromJson({'name':'Old saved soup','cuisine':'Soup',
      'servings':2,'minutes':20,'estimated_protein_g_per_serving':16});
    expect(old.protein,16);
    expect(old.carbs,isNull);
    final updated=SalusMealIdea.fromJson({'name':'Bean bowl','cuisine':'Mediterranean',
      'estimated_calories_per_serving':540,'estimated_protein_g_per_serving':34,
      'estimated_carbs_g_per_serving':55,'estimated_fat_g_per_serving':19,
      'estimated_fiber_g_per_serving':11});
    expect(updated.carbs,55);
    expect(updated.fiber,11);
    expect(updated.toJson()['estimated_fat_g_per_serving'],19);
  });
  test('Premium appearance preference can be persisted without changing health data', () async {
    SharedPreferences.setMockInitialValues({});
    SalusAppearance.light.value=true;
    await SalusAppearance.toggle();
    expect(SalusAppearance.light.value,isFalse);
    final prefs=await SharedPreferences.getInstance();
    expect(prefs.getBool('salus_premium_light_v1'),false);
    expect(prefs.getString('healthy_me_state_v03'),isNull);
    expect(prefs.getString('salus_diet_log_v1'),isNull);
  });
}
