import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthy_me/services/ai_meal_planner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SalusMealIdea recipe(String name) => SalusMealIdea.fromJson({
    'name': name, 'cuisine': 'Mexican',
    'description': 'Dinner',
    'ingredients': ['300 g steak', '2 peppers'],
    'instructions': 'Cook and serve',
    'servings': 2,
    'minutes': 25,
    'estimated_calories_per_serving': 510,
    'estimated_protein_g_per_serving': 37,
  });

  test('favorite AI recipes have a separate, removable Breakfast/Lunch/Dinner library', () async {
    SharedPreferences.setMockInitialValues({});
    const service = SalusMealPlannerService();
    final item = recipe('Steak fajitas');
    expect(await service.saveFavorite(item, 'Dinner'), isTrue);
    expect(await service.saveFavorite(item, 'Dinner'), isFalse);
    expect(await service.saveFavorite(item, 'Lunch'), isTrue);
    final saved = await service.loadFavorites();
    expect(saved.length, 2);
    expect(saved.where((e) => e.category == 'Dinner').single.recipe.ingredients,
      contains('300 g steak'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('salus_diet_log_v1'), isNull);
    expect(prefs.getString('salus_daily_meal_plan_v1'), isNull);
    await service.removeFavorite(saved.first.id);
    expect((await service.loadFavorites()).length, 1);
    await expectLater(service.saveFavorite(item, 'Brunch'), throwsArgumentError);
  });

  test('latest AI recipe search can be shared with global voice assistant', () async {
    SharedPreferences.setMockInitialValues({});
    const service = SalusMealPlannerService();
    final result = SalusMealSuggestions([recipe('Lemon chicken')], 'AI estimate');
    await service.saveLastDiscovery(result);
    final read = await service.loadLastDiscovery();
    expect(read, hasLength(1));
    expect(read.single.name, 'Lemon chicken');
    expect(read.single.servings, 2);
  });

  test('recipe parser preserves multiple distinct suggestions', () {
    final response = jsonEncode({
      'meals': [for (var i = 1; i <= 8; i++) recipe('Recipe $i').toJson()],
      'note': 'Suggestions are estimates',
    });
    expect(SalusMealSuggestions.parse(response).meals.length, 8);
  });
}
