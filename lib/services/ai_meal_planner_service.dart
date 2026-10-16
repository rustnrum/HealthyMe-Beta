import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'salus_ai_service.dart';

/// Food restrictions are intentionally distinct from tastes. AI suggestions
/// are never presented as allergy-certified or nutrient-verified.
class SalusFoodPreferences {
  final List<String> cuisines;
  final String dislikes;
  final String allergens;
  final String nutritionGoal;
  const SalusFoodPreferences({
    this.cuisines = const [],
    this.dislikes = '',
    this.allergens = '',
    this.nutritionGoal = 'Balanced',
  });
  Map<String, dynamic> toJson() => {
    'cuisines': cuisines, 'dislikes': dislikes,
    'allergens': allergens, 'nutritionGoal': nutritionGoal,
  };
  factory SalusFoodPreferences.fromJson(Map<String, dynamic> data) =>
      SalusFoodPreferences(
        cuisines: (data['cuisines'] is List)
            ? (data['cuisines'] as List).map((v) => v.toString()).toList()
            : const [],
        dislikes: data['dislikes']?.toString() ?? '',
        allergens: data['allergens']?.toString() ?? '',
        nutritionGoal: data['nutritionGoal']?.toString() ?? 'Balanced',
      );
}

class SalusMealIdea {
  final String name;
  final String cuisine;
  final String description;
  final String recipe;
  final String imagePath;
  final List<String> ingredients;
  final int servings;
  final int minutes;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final String? date;
  final String? slot;

  const SalusMealIdea({required this.name, required this.cuisine,
    required this.description, required this.recipe, this.imagePath = '',
    required this.ingredients, required this.servings,
    required this.minutes, this.calories, this.protein, this.carbs, this.fat, this.fiber, this.date, this.slot});

  SalusMealIdea withPhoto(String path) => SalusMealIdea(
    name: name, cuisine: cuisine, description: description, recipe: recipe,
    imagePath: path, ingredients: ingredients, servings: servings,
    minutes: minutes, calories: calories, protein: protein, carbs: carbs,
    fat: fat, fiber: fiber, date: date, slot: slot);

  static double? _number(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  factory SalusMealIdea.fromJson(Map<String, dynamic> j) {
    final ingredients = j['ingredients'];
    final name = j['name']?.toString().trim() ?? '';
    if (name.isEmpty) throw const FormatException('A recipe has no name');
    final date = j['date']?.toString();
    final slot = j['slot']?.toString();
    return SalusMealIdea(
      name: name,
      cuisine: j['cuisine']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      recipe: j['instructions']?.toString() ?? '',
      imagePath: j['imagePath']?.toString() ?? '',
      ingredients: ingredients is List
          ? ingredients.map((v) => v.toString()).where((v) => v.trim().isNotEmpty).toList()
          : const [],
      servings: (_number(j['servings']) ?? 1).clamp(1, 30).round(),
      minutes: (_number(j['minutes']) ?? 0).clamp(0, 600).round(),
      calories: _credible(_number(j['estimated_calories_per_serving']), 0, 3000),
      protein: _credible(_number(j['estimated_protein_g_per_serving']), 0, 300),
      carbs: _credible(_number(j['estimated_carbs_g_per_serving']), 0, 600),
      fat: _credible(_number(j['estimated_fat_g_per_serving']), 0, 300),
      fiber: _credible(_number(j['estimated_fiber_g_per_serving']), 0, 100),
      date: (date != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) ? date : null,
      slot: const ['Breakfast', 'Lunch', 'Dinner', 'Snacks'].contains(slot) ? slot : null,
    );
  }

  static double? _credible(double? number, double min, double max) =>
      number != null && number.isFinite && number >= min && number <= max
          ? number : null;

  Map<String, dynamic> toJson() => {
    'name': name, 'cuisine': cuisine, 'description': description,
    'instructions': recipe, 'imagePath': imagePath, 'ingredients': ingredients,
    'servings': servings, 'minutes': minutes,
    'estimated_calories_per_serving': calories,
    'estimated_protein_g_per_serving': protein,
    'estimated_carbs_g_per_serving': carbs,
    'estimated_fat_g_per_serving': fat,
    'estimated_fiber_g_per_serving': fiber,
    'date': date, 'slot': slot,
  };
}

class SalusMealSuggestions {
  final List<SalusMealIdea> meals;
  final String note;
  const SalusMealSuggestions(this.meals, this.note);

  /// Never fabricate meal results when the AI returns unparseable text.
  static SalusMealSuggestions parse(String response) {
    var text = response.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('AI did not return a recipe list. Try another search.');
    }
    final decoded = jsonDecode(text.substring(start, end + 1));
    if (decoded is! Map || decoded['meals'] is! List) {
      throw const FormatException('AI response did not include meals.');
    }
    final meals = <SalusMealIdea>[];
    for (final item in (decoded['meals'] as List).take(14)) {
      if (item is Map) {
        try { meals.add(SalusMealIdea.fromJson(Map<String, dynamic>.from(item))); }
        on FormatException { /* Reject an invalid recipe; no guesswork. */ }
      }
    }
    if (meals.isEmpty) throw const FormatException('No usable recipe results. Try changing your search.');
    return SalusMealSuggestions(meals, decoded['note']?.toString() ?? '');
  }
}

/// User-approved recipe bookmark; separate from eaten food journal.
class SalusSavedRecipe {
  final String id;
  final String category;
  final SalusMealIdea recipe;
  const SalusSavedRecipe({required this.id, required this.category, required this.recipe});

  Map<String, dynamic> toJson() => {
    'id': id, 'category': category, 'recipe': recipe.toJson(),
  };
  factory SalusSavedRecipe.fromJson(Map<String, dynamic> json) => SalusSavedRecipe(
    id: json['id']?.toString() ?? '',
    category: json['category']?.toString() ?? 'Dinner',
    recipe: SalusMealIdea.fromJson(Map<String, dynamic>.from(json['recipe'] as Map)),
  );
}

class SalusMealPlannerService {
  static const _preferencesKey = 'salus_food_preferences_v1';
  static const _recipesKey = 'salus_planned_recipe_details_v1';
  static const _favoritesKey = 'salus_saved_ai_recipes_v1';
  static final ValueNotifier<int> favoritesRevision = ValueNotifier<int>(0);
  static const _recentSearchKey = 'salus_recent_recipe_search_v1';
  const SalusMealPlannerService();

  static const recipeCategories = <String>['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

  Future<List<SalusSavedRecipe>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_favoritesKey);
    if (text == null || text.isEmpty) return [];
    try {
      final list = jsonDecode(text) as List;
      return list.whereType<Map>().map((item) {
        try { return SalusSavedRecipe.fromJson(Map<String, dynamic>.from(item)); }
        catch (_) { return null; }
      }).whereType<SalusSavedRecipe>().toList();
    } catch (_) { return []; }
  }

  /// Returns false if this recipe is already saved in the selected category.
  Future<bool> saveFavorite(SalusMealIdea recipe, String category) async {
    if (!recipeCategories.contains(category)) throw ArgumentError.value(category, 'category');
    final saved = await loadFavorites();
    if (saved.any((entry) => entry.category == category &&
        entry.recipe.name.trim().toLowerCase() == recipe.name.trim().toLowerCase())) {
      return false;
    }
    final item = SalusSavedRecipe(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      category: category, recipe: recipe,
    );
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(_favoritesKey,
      jsonEncode([...saved, item].map((v) => v.toJson()).toList()));
    if (ok) favoritesRevision.value += 1;
    return ok;
  }

  Future<void> removeFavorite(String id) async {
    final saved = await loadFavorites();
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(_favoritesKey,
      jsonEncode(saved.where((v) => v.id != id).map((v) => v.toJson()).toList()));
    if (ok) favoritesRevision.value += 1;
  }

  Future<void> saveLastDiscovery(SalusMealSuggestions result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentSearchKey,
      jsonEncode(result.meals.map((v) => v.toJson()).toList()));
  }

  Future<List<SalusMealIdea>> loadLastDiscovery() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_recentSearchKey);
    if (data == null) return [];
    try {
      return (jsonDecode(data) as List).whereType<Map>().map((m) {
        try { return SalusMealIdea.fromJson(Map<String, dynamic>.from(m)); }
        catch (_) { return null; }
      }).whereType<SalusMealIdea>().toList();
    } catch (_) { return []; }
  }

  Future<SalusFoodPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_preferencesKey);
    if (raw == null) return const SalusFoodPreferences();
    try { return SalusFoodPreferences.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map)); }
    catch (_) { return const SalusFoodPreferences(); }
  }

  Future<void> savePreferences(SalusFoodPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferencesKey, jsonEncode(value.toJson()));
  }

  Future<SalusMealSuggestions> discover({
    required String request,
    required SalusFoodPreferences preferences,
    String? openSlots,
  }) async {
    final question = '''You are generating OPTIONAL meal ideas for Salus Diet.
Return ONLY a JSON object in this shape:
{"meals":[{"name":"...","cuisine":"...","description":"...",
"ingredients":["amount and ingredient"],"instructions":"numbered cooking steps",
"servings":2,"minutes":30,"estimated_calories_per_serving":500,
"estimated_protein_g_per_serving":35,"estimated_carbs_g_per_serving":42,
"estimated_fat_g_per_serving":13,"estimated_fiber_g_per_serving":7,"date":null,"slot":null}],"note":"..."}.
If making a weekly plan, include YYYY-MM-DD date and Breakfast/Lunch/Dinner/Snacks slot for each meal.
Produce up to 8 complete distinct meals for a normal search (up to 10 when planning a week). Do not claim nutrition estimates are verified.
Preferred cuisines: ${preferences.cuisines.join(', ').isEmpty ? 'variety' : preferences.cuisines.join(', ')}.
Disliked ingredients (avoid or substitute): ${preferences.dislikes.isEmpty ? 'none' : preferences.dislikes}.
Allergies / strict exclusion requests: ${preferences.allergens.isEmpty ? 'none specified' : preferences.allergens}. NEVER knowingly include these, warn to review ingredient labels and cross-contact.
Nutrition priority: ${preferences.nutritionGoal}.
${openSlots == null ? '' : 'Available unplanned slots (ONLY suggest plans for these): $openSlots.'}
User request: $request.''';
    final response = await const SalusAiService().ask(question);
    return SalusMealSuggestions.parse(response);
  }

  /// Detailed recipes are stored in parallel to the existing string meal plan
  /// so old calendar entries, food logs, and previous builds remain readable.
  Future<Map<String, SalusMealIdea>> loadRecipeAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recipesKey);
    if (raw == null) return {};
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final output = <String, SalusMealIdea>{};
      for (final entry in decoded.entries) {
        try { output[entry.key] = SalusMealIdea.fromJson(Map<String, dynamic>.from(entry.value as Map)); }
        catch (_) { /* Ignore invalid, preserve remainder. */ }
      }
      return output;
    } catch (_) { return {}; }
  }

  Future<void> saveRecipeAssignment(String date, String slot, SalusMealIdea idea) async {
    final values = await loadRecipeAssignments();
    values['$date|$slot'] = idea;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recipesKey,
      jsonEncode(values.map((key, value) => MapEntry(key, value.toJson()))));
  }
}
