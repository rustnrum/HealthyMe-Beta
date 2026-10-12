import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/ai_meal_planner_service.dart';

class FoodPreferencesScreen extends StatefulWidget {
  const FoodPreferencesScreen({super.key});
  @override
  State<FoodPreferencesScreen> createState() => _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends State<FoodPreferencesScreen> {
  static const _cuisines = [
    'Mediterranean', 'Mexican', 'Caribbean', 'Italian', 'American',
    'Greek', 'Indian', 'Thai', 'Japanese', 'Chinese', 'Southern / BBQ',
    'Middle Eastern', 'Seafood', 'Vegetarian',
  ];
  final _dislikes = TextEditingController();
  final _allergens = TextEditingController();
  final _service = const SalusMealPlannerService();
  Set<String> _favorites = {};
  String _goal = 'Balanced';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _dislikes.dispose(); _allergens.dispose(); super.dispose(); }

  Future<void> _load() async {
    final prefs = await _service.loadPreferences();
    if (!mounted) return;
    setState(() {
      _favorites = {...prefs.cuisines};
      _dislikes.text = prefs.dislikes;
      _allergens.text = prefs.allergens;
      _goal = prefs.nutritionGoal;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.savePreferences(SalusFoodPreferences(
        cuisines: _favorites.toList()..sort(),
        dislikes: _dislikes.text.trim(), allergens: _allergens.text.trim(),
        nutritionGoal: _goal,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save preferences: $error')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Food preferences')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(18), children: [
        const Text('Favorite cuisines', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('Favorites guide AI searches without hiding every other cuisine.',
          style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 5, children: [
          for (final cuisine in _cuisines) FilterChip(
            label: Text(cuisine), selected: _favorites.contains(cuisine),
            onSelected: (yes) => setState(() {
              if (yes) { _favorites.add(cuisine); }
              else { _favorites.remove(cuisine); }
            }),
          ),
        ]),
        const SizedBox(height: 22),
        const Text('Ingredients to avoid', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(controller: _dislikes, maxLines: 2,
          decoration: const InputDecoration(border: OutlineInputBorder(),
            labelText: 'Dislikes', hintText: 'Example: cilantro, olives')),
        const SizedBox(height: 20),
        const Text('Allergies or strict exclusions',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(controller: _allergens, maxLines: 2,
          decoration: const InputDecoration(border: OutlineInputBorder(),
            labelText: 'Allergies / exclusions', hintText: 'Example: peanuts, shellfish')),
        const SizedBox(height: 6),
        const Text('AI-generated recipes cannot guarantee ingredient or cross-contact safety. Always verify labels and preparation.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 20),
        const Text('Nutrition priority', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final choice in ['Balanced', 'Higher protein', 'Lower calorie', 'Lower carbohydrate'])
            ChoiceChip(label: Text(choice), selected: _goal == choice,
              onSelected: (_) => setState(() => _goal = choice)),
        ]),
        const SizedBox(height: 15),
        FilledButton.icon(onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving…' : 'Save preferences')),
      ],
    ),
  );
}
