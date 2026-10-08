import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'today_plan_state.dart';

/// Real user-entered food values. Missing nutrients stay missing.
class FoodLogEntry {
  final String id;
  final DateTime eatenAt;
  final String slot, name, portion;
  final double? calories, protein, carbs, fat, fiber;
  const FoodLogEntry({required this.id, required this.eatenAt,
    required this.slot, required this.name, this.portion = '',
    this.calories, this.protein, this.carbs, this.fat, this.fiber});
  Map<String, dynamic> toJson() => {
    'id': id, 'eatenAt': eatenAt.toIso8601String(), 'slot': slot,
    'name': name, 'portion': portion, 'calories': calories,
    'protein': protein, 'carbs': carbs, 'fat': fat, 'fiber': fiber,
  };
  factory FoodLogEntry.fromJson(Map<String, dynamic> j) => FoodLogEntry(
    id: j['id']?.toString() ?? '',
    eatenAt: DateTime.tryParse(j['eatenAt']?.toString() ?? '') ?? DateTime.now(),
    slot: j['slot']?.toString() ?? 'Snacks',
    name: j['name']?.toString() ?? '', portion: j['portion']?.toString() ?? '',
    calories: (j['calories'] as num?)?.toDouble(),
    protein: (j['protein'] as num?)?.toDouble(),
    carbs: (j['carbs'] as num?)?.toDouble(),
    fat: (j['fat'] as num?)?.toDouble(),
    fiber: (j['fiber'] as num?)?.toDouble(),
  );
  FoodLogEntry repeated(String newId, DateTime when, String mealSlot) =>
      FoodLogEntry(id: newId, eatenAt: when, slot: mealSlot, name: name,
        portion: portion, calories: calories, protein: protein,
        carbs: carbs, fat: fat, fiber: fiber);
}

class GroceryEntry {
  final String id, name;
  final bool checked;
  const GroceryEntry({required this.id, required this.name, this.checked = false});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'checked': checked};
  factory GroceryEntry.fromJson(Map<String, dynamic> j) => GroceryEntry(
    id: j['id']?.toString() ?? '', name: j['name']?.toString() ?? '',
    checked: j['checked'] == true);
  GroceryEntry withChecked(bool value) => GroceryEntry(id: id, name: name, checked: value);
}

class DietLogState {
  final bool loaded;
  final List<FoodLogEntry> entries, savedMeals;
  final List<GroceryEntry> groceries;
  const DietLogState({this.loaded = false, this.entries = const [],
    this.savedMeals = const [], this.groceries = const []});
  List<FoodLogEntry> forDay(DateTime date) => entries.where((e) =>
      salusDayKey(e.eatenAt) == salusDayKey(date)).toList();
  double? knownTotal(DateTime day, double? Function(FoodLogEntry) select) {
    final available = forDay(day).map(select).whereType<double>().toList();
    return available.isEmpty ? null : available.reduce((a, b) => a + b);
  }
  bool incomplete(DateTime day, double? Function(FoodLogEntry) select) =>
      forDay(day).any((e) => select(e) == null);
}

class DietLogNotifier extends Notifier<DietLogState> {
  static const _key = 'salus_diet_log_v1';
  bool _loading = false;
  @override
  DietLogState build() {
    if (!_loading) { _loading = true; unawaited(_load()); }
    return const DietLogState();
  }
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) {state = const DietLogState(loaded: true); return;}
      final data = jsonDecode(raw) as Map<String, dynamic>;
      List<T> decode<T>(String key, T Function(Map<String, dynamic>) parse) =>
          (data[key] as List<dynamic>? ?? const []).whereType<Map>()
              .map((j) => parse(Map<String, dynamic>.from(j))).toList();
      state = DietLogState(loaded: true,
        entries: decode('entries', FoodLogEntry.fromJson),
        savedMeals: decode('savedMeals', FoodLogEntry.fromJson),
        groceries: decode('groceries', GroceryEntry.fromJson));
    } catch (_) { state = const DietLogState(loaded: true); }
  }
  Future<void> _save(DietLogState value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({
      'entries': value.entries.map((e) => e.toJson()).toList(),
      'savedMeals': value.savedMeals.map((e) => e.toJson()).toList(),
      'groceries': value.groceries.map((e) => e.toJson()).toList(),
    }));
  }
  String _id() => DateTime.now().microsecondsSinceEpoch.toString();
  Future<void> addFood(FoodLogEntry food, {bool saveAsTemplate = false}) async {
    final entry = food.repeated(_id(), DateTime.now(), food.slot);
    final saved = [...state.savedMeals];
    if (saveAsTemplate && !saved.any((e) =>
        e.name.toLowerCase() == entry.name.toLowerCase())) saved.add(entry);
    await _save(DietLogState(loaded: true, entries: [...state.entries, entry],
      savedMeals: saved, groceries: state.groceries));
  }
  Future<void> repeatFood(FoodLogEntry food, String slot) =>
      addFood(food.repeated('', DateTime.now(), slot));
  Future<void> deleteFood(String id) => _save(DietLogState(loaded: true,
    entries: state.entries.where((e) => e.id != id).toList(),
    savedMeals: state.savedMeals, groceries: state.groceries));
  Future<void> deleteSavedMeal(String id) => _save(DietLogState(loaded: true,
    entries: state.entries,
    savedMeals: state.savedMeals.where((e) => e.id != id).toList(),
    groceries: state.groceries));
  Future<void> addGrocery(String name) async {
    if (name.trim().isEmpty) return;
    await _save(DietLogState(loaded: true, entries: state.entries,
      savedMeals: state.savedMeals,
      groceries: [...state.groceries, GroceryEntry(id: _id(), name: name.trim())]));
  }
  Future<void> toggleGrocery(String id, bool checked) => _save(DietLogState(
    loaded: true, entries: state.entries, savedMeals: state.savedMeals,
    groceries: state.groceries.map((e) =>
        e.id == id ? e.withChecked(checked) : e).toList()));
  Future<void> removeGrocery(String id) => _save(DietLogState(
    loaded: true, entries: state.entries, savedMeals: state.savedMeals,
    groceries: state.groceries.where((e) => e.id != id).toList()));
}

final dietLogStateProvider = NotifierProvider<DietLogNotifier, DietLogState>(DietLogNotifier.new);
