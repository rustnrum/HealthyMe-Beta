"""Small, fail-closed integration of Build91 Home AI and recipe photo changes.

Edits only the existing recipe model, discovery/calendar photo presentation,
and an API response parser. Never touches a user storage key, signing material,
old Bluetooth migration, or any Health Connect integration.
"""
from pathlib import Path


def replace_one(path, old, new):
    file = Path(path)
    text = file.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'Build91 source anchor {path} count {count}: {old[:70]!r}')
    file.write_text(text.replace(old, new, 1))

# Preserve backward-compatible model JSON. Existing recipes have imagePath=''.
p = 'lib/services/ai_meal_planner_service.dart'
replace_one(p, '  final String recipe;\n', '  final String recipe;\n  final String imagePath;\n')
replace_one(p, '    required this.description, required this.recipe,\n',
            "    required this.description, required this.recipe, this.imagePath = '',\n")
replace_one(p, '  static double? _number(dynamic v) {', '''  SalusMealIdea withPhoto(String path) => SalusMealIdea(
    name: name, cuisine: cuisine, description: description, recipe: recipe,
    imagePath: path, ingredients: ingredients, servings: servings,
    minutes: minutes, calories: calories, protein: protein, carbs: carbs,
    fat: fat, fiber: fiber, date: date, slot: slot);

  static double? _number(dynamic v) {''')
replace_one(p, "      recipe: j['instructions']?.toString() ?? '',",
            "      recipe: j['instructions']?.toString() ?? '',\n      imagePath: j['imagePath']?.toString() ?? '',")
replace_one(p, "    'instructions': recipe, 'ingredients': ingredients,",
            "    'instructions': recipe, 'imagePath': imagePath, 'ingredients': ingredients,")

# Current OpenAI model listing response is {data: [{id: ...}]}.
# Old code erroneously looked for {models: [{slug: ...}]}.
p = 'lib/services/salus_ai_service.dart'
replace_one(p, "final list = value['models'];", "final list = value['data'];")
replace_one(p, "(m['slug'] ?? '').toString().startsWith('gpt-')",
            "(m['id'] ?? '').toString().startsWith('gpt-')")
replace_one(p, "final slug = (record['slug'] ?? '').toString();",
            "final slug = (record['id'] ?? '').toString();")

# Recipe discovery: attach a genuine locally selected photo, preserve with JSON.
p = 'lib/screens/diet/ai_meal_discovery_screen.dart'
replace_one(p, "import '../../services/ai_meal_planner_service.dart';",
            "import '../../services/ai_meal_planner_service.dart';\nimport '../../services/salus_recipe_photo_service.dart';")
replace_one(p, '  Widget _saveRecipeMenu(SalusMealIdea idea) => PopupMenuButton<String>(', '''  Future<void> _addRecipePhoto(SalusMealIdea idea) async {
    try {
      final path = await const SalusRecipePhotoService().chooseAndKeep();
      if (path == null || !mounted) return;
      final results = _results;
      if (results == null) return;
      final meals = [for (final item in results.meals)
        if (identical(item, idea)) item.withPhoto(path) else item];
      final updated = SalusMealSuggestions(meals, results.note);
      setState(() => _results = updated);
      await _service.saveLastDiscovery(updated);
      _toast('Photo saved with the recipe. Save or plan the updated recipe.');
    } catch (error) {
      _toast('Could not attach photo: $error');
    }
  }

  Widget _saveRecipeMenu(SalusMealIdea idea) => PopupMenuButton<String>(''')
replace_one(p, "            Text(idea.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),",
            "            SalusRecipePhoto(imagePath: idea.imagePath, width: 180, height: 140),\n            const SizedBox(height: 12),\n            Text(idea.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),")
replace_one(p, "              _saveRecipeMenu(idea),\n              OutlinedButton.icon(onPressed: () { Navigator.pop(sheet); _addGroceries(idea); },",
            "              _saveRecipeMenu(idea),\n              OutlinedButton.icon(onPressed: () { Navigator.pop(sheet); _addRecipePhoto(idea); },\n                icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Attach photo')),\n              OutlinedButton.icon(onPressed: () { Navigator.pop(sheet); _addGroceries(idea); },")
replace_one(p, "          SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n            Text(idea.name,",
            "          SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n            SalusRecipePhoto(imagePath: idea.imagePath, width: 110, height: 88),\n            const SizedBox(height: 7),\n            Text(idea.name,")
replace_one(p, "              OutlinedButton(onPressed: () => _showRecipe(idea), child: const Text('View recipe')),\n              _saveRecipeMenu(idea),",
            "              OutlinedButton(onPressed: () => _showRecipe(idea), child: const Text('View recipe')),\n              OutlinedButton.icon(onPressed: () => _addRecipePhoto(idea),\n                icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Photo')),\n              _saveRecipeMenu(idea),")

# Saved My Meals library displays the attached photograph as well.
p = 'lib/screens/diet/diet_menu_screen.dart'
replace_one(p, "import '../../services/ai_meal_planner_service.dart';",
            "import '../../services/ai_meal_planner_service.dart';\nimport '../../services/salus_recipe_photo_service.dart';")
replace_one(p, "          Text(recipe.name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),",
            "          SalusRecipePhoto(imagePath: recipe.imagePath, width: 180, height: 140),\n          const SizedBox(height: 10),\n          Text(recipe.name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),")
replace_one(p, "                    SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                      Text(saved.recipe.name,",
            "                    SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                      SalusRecipePhoto(imagePath: saved.recipe.imagePath, width: 96, height: 80),\n                      const SizedBox(height: 8),\n                      Text(saved.recipe.name,")

# Calendar also uses saved photograph, without a new duplicate data store.
p = 'lib/screens/diet/meal_calendar_screen.dart'
replace_one(p, "import '../../services/ai_meal_planner_service.dart';",
            "import '../../services/ai_meal_planner_service.dart';\nimport '../../services/salus_recipe_photo_service.dart';")
replace_one(p, "            Text(meal.name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),",
            "            SalusRecipePhoto(imagePath: meal.imagePath, width: 180, height: 140),\n            const SizedBox(height: 10),\n            Text(meal.name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),")
replace_one(p, "            Icon(name.isEmpty ? Icons.radio_button_unchecked : Icons.check_circle_outline,",
            "            if (recipe != null && recipe.name == name && recipe.imagePath.isNotEmpty) ...[\n              SalusRecipePhoto(imagePath: recipe.imagePath, width: 46, height: 46),\n              const SizedBox(width: 7),\n            ] else\n            Icon(name.isEmpty ? Icons.radio_button_unchecked : Icons.check_circle_outline,")

# Quick verification that tests retain source-contract and existing storage support.
for path in [
    'lib/screens/premium/salus_home_87.dart',
    'lib/screens/premium/salus_home_ai_card.dart',
    'lib/services/salus_recipe_photo_service.dart',
]:
    assert Path(path).exists(), path
assert "View Today's Plan" not in Path('lib/screens/premium/salus_home_87.dart').read_text()
assert Path('assets/premium/salus_wordmark_90.png').exists()
assert 'BLUETOOTH' not in Path('native/android/AndroidManifest.xml').read_text()
