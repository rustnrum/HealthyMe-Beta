import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/ai_meal_planner_service.dart';
import 'package:healthy_me/services/salus_recipe_photo_service.dart';

void main() {
  test('Saved recipe photo path round trips without discarding old recipes', () {
    const idea = SalusMealIdea(name: 'Lemon chicken', cuisine: 'Mediterranean',
      description: '', recipe: '', ingredients: ['chicken'], servings: 2,
      minutes: 25, imagePath: '/app/salus_recipe_photos/meal_12.jpg');
    final restored = SalusMealIdea.fromJson(idea.toJson());
    expect(restored.imagePath, idea.imagePath);
    final previous = SalusMealIdea.fromJson({
      'name': 'Legacy meal', 'cuisine': 'Home', 'description': '',
      'instructions': '', 'ingredients': [], 'servings': 1, 'minutes': 5,
    });
    expect(previous.imagePath, isEmpty);
    expect(previous.withPhoto('/app/salus_recipe_photos/new.jpg').imagePath,
      '/app/salus_recipe_photos/new.jpg');
  });

  test('Build91 is an additive Home change and keeps existing real modules', () {
    final home = File('lib/screens/premium/salus_home_87.dart').readAsStringSync();
    final newCard = File('lib/screens/premium/salus_home_ai_card.dart').readAsStringSync();
    final meal = File('lib/screens/diet/ai_meal_discovery_screen.dart').readAsStringSync();
    final planner = File('lib/services/ai_meal_planner_service.dart').readAsStringSync();
    final workout = File('lib/screens/workout_screen.dart').readAsStringSync();
    final shell = File('lib/screens/home_shell.dart').readAsStringSync();
    expect(home, contains('SalusHomeAiCard('));
    expect(home, contains('NEXT PLANNED MEAL'));
    expect(home, contains('workout.exercises.take(5)'));
    expect(home, isNot(contains('View Today\'s Plan')));
    expect(newCard, contains('salus_ai_daily_health_consent_v1'));
    expect(newCard, contains('SalusAiService().ask('));
    expect(meal, contains('_addRecipePhoto('));
    expect(planner, contains("'imagePath': imagePath"));
    expect(workout, contains('workoutStateProvider'));
    expect(shell, contains('SalusHome87()'));
    expect(shell, contains('bottomNavigationBar: _SalusBottomNav('));
  });

  for (final width in [320.0, 360.0, 412.0, 820.0]) {
    testWidgets('Unknown meal photo shows clearly absent image at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(
        body: Center(child: SalusRecipePhoto(imagePath: '')),
      )));
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
