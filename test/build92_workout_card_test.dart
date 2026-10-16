import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/workout_models.dart';
import 'package:healthy_me/screens/premium/salus_workout_portrait_92.dart';

void main() {
  test('Existing user workouts remain readable with optional new fields', () {
    final oldExercise = WorkoutExercise.fromJson({
      'id': 'old-1', 'name': 'Bench press', 'sets': 3, 'reps': 10,
      'restSeconds': 60,
    });
    expect(oldExercise.phase, 'Main');
    final oldWorkout = ScheduledWorkout.fromJson({
      'id': 'old-workout', 'name': 'Existing routine',
      'scheduledFor': '2026-10-17T14:00:00',
      'exercises': [oldExercise.toJson()],
    });
    expect(oldWorkout.exercises.single.name, 'Bench press');
    expect(oldWorkout.plannedMinutes, isNull);
    expect(oldWorkout.focus, isEmpty);
  });

  test('New workout fields survive save/load and copyWith', () {
    const warmup = WorkoutExercise(id: 'w1', name: 'Warm-up',
      sets: 1, reps: 5, phase: 'Warm-up');
    const main = WorkoutExercise(id: 'm1', name: 'Bench press',
      sets: 3, reps: 10, weight: 100, phase: 'Main');
    const cooldown = WorkoutExercise(id: 'c1', name: 'Stretch',
      sets: 1, reps: 5, phase: 'Cool-down');
    final planned = ScheduledWorkout(id: 'session-1', name: 'Upper body',
      scheduledFor: DateTime(2026, 10, 17), plannedMinutes: 45,
      focus: 'Upper body strength', exercises: [warmup, main, cooldown]);
    final loaded = ScheduledWorkout.fromJson(planned.toJson());
    expect(loaded.plannedMinutes, 45);
    expect(loaded.focus, 'Upper body strength');
    expect(loaded.exercises.map((e) => e.phase).toList(),
      ['Warm-up', 'Main', 'Cool-down']);
    expect(loaded.exercises[1].weight, 100);
    expect(loaded.copyWith(focus: 'Strength').focus, 'Strength');
  });

  test('Workout portrait uses only an explicitly completed profile choice', () {
    expect(SalusWorkoutPortrait92.assetFor(sex: 'Male', completed: true),
      'assets/premium/salus_workout_male_92.jpg');
    expect(SalusWorkoutPortrait92.assetFor(sex: 'female', completed: true),
      'assets/premium/salus_workout_female_92.jpg');
    expect(SalusWorkoutPortrait92.assetFor(sex: 'Male', completed: false), isNull);
    expect(SalusWorkoutPortrait92.assetFor(sex: 'Other', completed: true), isNull);
  });

  test('Two new images exist; no previous brand artwork was replaced', () {
    expect(File('assets/premium/salus_workout_male_92.jpg').lengthSync(),
      greaterThan(1000));
    expect(File('assets/premium/salus_workout_female_92.jpg').lengthSync(),
      greaterThan(1000));
    expect(File('assets/premium/salus_wordmark_90.png').existsSync(), isTrue);
    final home = File('lib/screens/premium/salus_home_87.dart').readAsStringSync();
    expect(home, contains('SalusWorkoutPortrait92('));
    expect(home, contains('profileSex: app.profile.sex'));
    expect(home, contains('BoxFit.cover'));
    expect(home, contains("_workoutMeta('Duration'"));
    expect(home, contains("_workoutMeta('Total sets'"));
    expect(home, contains("_workoutSection('Warm-up'"));
    expect(home, contains("_workoutSection('Cool-down'"));
    expect(home, contains("Today's Nutrition"));
    expect(home, contains('NEXT PLANNED MEAL'));
  });

  for (final width in [320.0, 360.0, 412.0, 820.0]) {
    testWidgets('Portrait scales on $width without clipping the asset', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
        Center(child: SalusWorkoutPortrait92(
          profileSex: 'Male', profileCompleted: true,
          width: 110, height: 92,
        )),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
    });
  }
}
