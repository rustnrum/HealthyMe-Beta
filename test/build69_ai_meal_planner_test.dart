import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/ai_meal_planner_service.dart';

void main() {
  test('AI meal JSON retains recipe, nutrition estimates and date assignment', () {
    final response = jsonEncode({
      'meals': [
        {
          'name': 'Mediterranean Chicken Bowl',
          'cuisine': 'Mediterranean',
          'description': 'Chicken, vegetables, lemon rice',
          'ingredients': ['300 g chicken', '1 cup rice', '1 lemon'],
          'instructions': 'Cook chicken and rice. Add vegetables and lemon.',
          'servings': 2,
          'minutes': 30,
          'estimated_calories_per_serving': 580,
          'estimated_protein_g_per_serving': 42,
          'date': '2026-10-15',
          'slot': 'Dinner',
        },
      ],
      'note': 'Review estimates.',
    });
    final parsed = SalusMealSuggestions.parse('```json\n$response\n```');
    expect(parsed.meals, hasLength(1));
    expect(parsed.meals.single.name, 'Mediterranean Chicken Bowl');
    expect(parsed.meals.single.ingredients.length, 3);
    expect(parsed.meals.single.calories, 580);
    expect(parsed.meals.single.protein, 42);
    expect(parsed.meals.single.date, '2026-10-15');
    expect(parsed.meals.single.slot, 'Dinner');
    expect(SalusMealIdea.fromJson(parsed.meals.single.toJson()).name,
        'Mediterranean Chicken Bowl');
  });

  test('invalid dates, unrecognized meal slots and nonsense nutrients are rejected', () {
    final item = SalusMealIdea.fromJson({
      'name': 'Test meal', 'ingredients': [], 'servings': 4,
      'estimated_calories_per_serving': -50,
      'estimated_protein_g_per_serving': 9000,
      'date': 'tomorrow', 'slot': 'Brunch',
    });
    expect(item.calories, isNull);
    expect(item.protein, isNull);
    expect(item.date, isNull);
    expect(item.slot, isNull);
  });

  test('food preferences preserve cuisine favorites, dislikes, and exclusions', () {
    const prefs = SalusFoodPreferences(
      cuisines: ['Mediterranean', 'Mexican'],
      dislikes: 'Cilantro', allergens: 'Peanuts',
      nutritionGoal: 'Higher protein',
    );
    final again = SalusFoodPreferences.fromJson(prefs.toJson());
    expect(again.cuisines, contains('Mexican'));
    expect(again.dislikes, 'Cilantro');
    expect(again.allergens, 'Peanuts');
    expect(again.nutritionGoal, 'Higher protein');
  });

  test('malformed and non-recipe AI responses never create fake meals', () {
    expect(() => SalusMealSuggestions.parse('Here is a tasty recipe!'),
        throwsFormatException);
    expect(() => SalusMealSuggestions.parse('{"meals":[]}'),
        throwsFormatException);
  });
}
