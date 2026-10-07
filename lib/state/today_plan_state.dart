import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const salusMealSlots = <String>['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

String salusDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class TodayPlanState {
  final bool loaded;
  final Map<String, Map<String, String>> mealsByDay;

  const TodayPlanState({
    this.loaded = false,
    this.mealsByDay = const {},
  });

  Map<String, String> mealsFor(DateTime date) =>
      Map<String, String>.from(mealsByDay[salusDayKey(date)] ?? const {});
}

class TodayPlanNotifier extends Notifier<TodayPlanState> {
  static const _key = 'salus_daily_meal_plan_v1';
  bool _loading = false;

  @override
  TodayPlanState build() {
    if (!_loading) {
      _loading = true;
      unawaited(_load());
    }
    return const TodayPlanState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.trim().isEmpty) {
        state = const TodayPlanState(loaded: true);
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        state = const TodayPlanState(loaded: true);
        return;
      }
      final values = <String, Map<String, String>>{};
      for (final entry in decoded.entries) {
        final rawMeals = entry.value;
        if (rawMeals is! Map) continue;
        values[entry.key.toString()] = {
          for (final meal in rawMeals.entries)
            meal.key.toString(): meal.value.toString(),
        };
      }
      state = TodayPlanState(loaded: true, mealsByDay: values);
    } catch (_) {
      state = const TodayPlanState(loaded: true);
    }
  }

  Future<void> setMeal(DateTime date, String slot, String value) async {
    final next = <String, Map<String, String>>{
      for (final entry in state.mealsByDay.entries)
        entry.key: Map<String, String>.from(entry.value),
    };
    final key = salusDayKey(date);
    final meals = next.putIfAbsent(key, () => <String, String>{});
    final text = value.trim();
    if (text.isEmpty) {
      meals.remove(slot);
    } else {
      meals[slot] = text;
    }
    if (meals.isEmpty) next.remove(key);
    state = TodayPlanState(loaded: true, mealsByDay: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }
}

final todayPlanStateProvider =
    NotifierProvider<TodayPlanNotifier, TodayPlanState>(
  TodayPlanNotifier.new,
);
