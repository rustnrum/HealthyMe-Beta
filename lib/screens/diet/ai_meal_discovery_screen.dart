import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/ai_meal_planner_service.dart';
import '../../services/salus_recipe_photo_service.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/salus_widgets.dart';
import 'food_preferences_screen.dart';

/// Discover recipes, review AI suggestions, then explicitly approve calendar
/// changes. This screen never adds food to the eaten-food journal.
class AiMealDiscoveryScreen extends ConsumerStatefulWidget {
  const AiMealDiscoveryScreen({super.key});
  @override
  ConsumerState<AiMealDiscoveryScreen> createState() => _AiMealDiscoveryScreenState();
}

class _AiMealDiscoveryScreenState extends ConsumerState<AiMealDiscoveryScreen> {
  final _request = TextEditingController();
  final _service = const SalusMealPlannerService();
  SalusFoodPreferences _preferences = const SalusFoodPreferences();
  SalusMealSuggestions? _results;
  bool _searching = false;
  bool _applying = false;
  bool _more = false;
  String? _error;

  @override
  void initState() { super.initState(); _loadPreferences(); }
  @override
  void dispose() { _request.dispose(); super.dispose(); }

  Future<void> _loadPreferences() async {
    final prefs = await _service.loadPreferences();
    if (mounted) setState(() => _preferences = prefs);
  }

  String _dateKey(DateTime date) => salusDayKey(date);
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  List<String> _missingDinnerSlots() {
    final start = _startOfDay(DateTime.now());
    final plan = ref.read(todayPlanStateProvider);
    return [for (var offset = 0; offset < 7; offset++)
      if ((plan.mealsFor(start.add(Duration(days: offset)))['Dinner'] ?? '').trim().isEmpty)
        '${_dateKey(start.add(Duration(days: offset)))} Dinner'];
  }

  Future<void> _search([String? suggested, bool append = false]) async {
    final query = (suggested ?? _request.text).trim();
    final priorNames = append ? (_results?.meals.map((e) => e.name).join('; ') ?? '') : ''; 
    if (query.isEmpty || _searching) return;
    _request.text = query;
    final isPlanning = query.toLowerCase().contains('unplanned') ||
        query.toLowerCase().contains('week') ||
        query.toLowerCase().contains('calendar');
    setState(() { _searching = true; _error = null; if (!append) _results = null; _more = append; });
    try {
      final options = isPlanning ? _missingDinnerSlots() : null;
      if (isPlanning && options!.isEmpty) {
        setState(() => _error = 'Every dinner this week is already planned. Choose another search.');
        return;
      }
      final result = await _service.discover(
        request: append ? '$query. Give different recipes. Exclude all these previously shown: $priorNames.' : query,
        preferences: _preferences,
        openSlots: options == null ? null : options.join('; '));
      if (mounted) {
        final existing = append ? (_results?.meals ?? const <SalusMealIdea>[]) : <SalusMealIdea>[];
        final names = existing.map((e) => e.name.trim().toLowerCase()).toSet();
        final merged = [...existing, ...result.meals.where((e) => names.add(e.name.trim().toLowerCase()))];
        final combined = SalusMealSuggestions(merged.take(32).toList(), result.note);
        setState(() => _results = combined);
        await _service.saveLastDiscovery(combined);
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Meal discovery failed: $error');
    } finally { if (mounted) setState(() { _searching = false; _more = false; }); }
  }

  Future<void> _planRecipe(SalusMealIdea idea) async {
    var date = DateTime.now();
    if (idea.date != null) {
      date = DateTime.tryParse(idea.date!) ?? date;
    }
    var slot = idea.slot ?? 'Dinner';
    final choice = await showDialog<(DateTime, String)>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (dialog, setDialog) => AlertDialog(
        title: const Text('Add to meal calendar'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(idea.name), const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('${date.month}/${date.day}/${date.year}'),
            onPressed: () async {
              final selected = await showDatePicker(context: dialog,
                initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (selected != null) setDialog(() => date = selected);
            },
          ),
          DropdownButton<String>(value: slot, isExpanded: true,
            items: [for (final item in salusMealSlots)
              DropdownMenuItem(value: item, child: Text(item))],
            onChanged: (value) { if (value != null) setDialog(() => slot = value); }),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, (date, slot)), child: const Text('Review')),
        ],
      )),
    );
    if (choice == null || !mounted) return;
    await _applyPlans([(idea, choice.$1, choice.$2)]);
  }

  Future<void> _applyGeneratedWeek() async {
    final ideas = _results?.meals ?? const <SalusMealIdea>[];
    final selections = <(SalusMealIdea, DateTime, String)>[];
    final validSlots = _missingDinnerSlots().toSet();
    for (final idea in ideas) {
      final date = idea.date == null ? null : DateTime.tryParse(idea.date!);
      if (date != null && idea.slot == 'Dinner' &&
          validSlots.contains('${_dateKey(date)} Dinner') &&
          !selections.any((item) => _dateKey(item.$2) == _dateKey(date))) {
        selections.add((idea, date, 'Dinner'));
      }
    }
    if (selections.isEmpty) {
      _toast('No suggestions matched this week’s unplanned dinners. Add a recipe individually.');
      return;
    }
    await _applyPlans(selections);
  }

  Future<void> _applyPlans(List<(SalusMealIdea, DateTime, String)> selections) async {
    if (_applying || selections.isEmpty) return;
    final existing = ref.read(todayPlanStateProvider);
    final conflicts = selections.where((item) =>
      (existing.mealsFor(item.$2)[item.$3] ?? '').trim().isNotEmpty).toList();
    final allowReplace = await showDialog<bool>(context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Add ${selections.length} planned meal${selections.length == 1 ? '' : 's'}?'),
        content: Text(conflicts.isEmpty
          ? 'These meals will be added to your calendar. They will NOT be logged as eaten. Nutrition numbers are AI estimates.'
          : '${conflicts.length} calendar slot(s) already contain a meal. Replace existing plans? No food logs will be changed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(conflicts.isEmpty ? 'Add to calendar' : 'Replace and add')),
        ],
      ));
    if (allowReplace != true || !mounted) return;
    setState(() => _applying = true);
    try {
      for (final (idea, date, slot) in selections) {
        await ref.read(todayPlanStateProvider.notifier).setMeal(date, slot, idea.name);
        await _service.saveRecipeAssignment(_dateKey(date), slot, idea);
      }
      _toast('${selections.length} meal${selections.length == 1 ? '' : 's'} added to the calendar.');
    } catch (error) { _toast('Some meals could not be saved: $error'); }
    finally { if (mounted) setState(() => _applying = false); }
  }

  Future<void> _saveFavorite(SalusMealIdea idea, String category) async {
    try {
      final inserted = await _service.saveFavorite(idea, category);
      _toast(inserted ? 'Saved ${idea.name} to $category recipes.' : 'Already saved to $category.');
    } catch (error) { _toast('Could not save recipe: $error'); }
  }

  Future<void> _addRecipePhoto(SalusMealIdea idea) async {
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

  Widget _saveRecipeMenu(SalusMealIdea idea) => PopupMenuButton<String>(
    tooltip: 'Save this recipe to My Meals',
    onSelected: (category) => _saveFavorite(idea, category),
    itemBuilder: (context) => [for (final category in SalusMealPlannerService.recipeCategories)
      PopupMenuItem(value: category, child: Text('Save to $category'))],
    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bookmark_add_outlined, size: 18), SizedBox(width: 6), Text('Save recipe'),
      ])),
  );

  Future<void> _addGroceries(SalusMealIdea idea) async {
    if (idea.ingredients.isEmpty) { _toast('This recipe did not include ingredients.'); return; }
    final ok = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Add recipe ingredients?'),
      content: Text('Add ${idea.ingredients.length} AI-suggested ingredients to your grocery list? Check pantry quantities before shopping.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Add ingredients')),
      ],
    ));
    if (ok != true || !mounted) return;
    final known = ref.read(dietLogStateProvider).groceries.map((v) => v.name.toLowerCase()).toSet();
    for (final ingredient in idea.ingredients) {
      if (known.add(ingredient.toLowerCase())) {
        await ref.read(dietLogStateProvider.notifier).addGrocery(ingredient);
      }
    }
    _toast('Ingredients added to your grocery list.');
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showRecipe(SalusMealIdea idea) async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (sheet) => SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
            SalusRecipePhoto(imagePath: idea.imagePath, width: 180, height: 140),
            const SizedBox(height: 12),
            Text(idea.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('${idea.cuisine} • ${idea.minutes} min • ${idea.servings} serving(s)'),
            const SizedBox(height: 8),
            const Text('Nutrition per serving: AI estimates, not verified values.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            Text('~${idea.calories?.round().toString() ?? '—'} kcal  •  ~${idea.protein?.round().toString() ?? '—'} g protein'),
            const SizedBox(height: 18),
            const Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            for (final ingredient in idea.ingredients)
              Padding(padding: const EdgeInsets.only(top: 5), child: Text('• $ingredient')),
            const SizedBox(height: 16),
            const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6), Text(idea.recipe.isEmpty ? 'No instructions provided.' : idea.recipe),
            const SizedBox(height: 16),
            const Text('Verify ingredients and cross-contact if you have allergies.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: () { Navigator.pop(sheet); _planRecipe(idea); },
                icon: const Icon(Icons.calendar_month_outlined), label: const Text('Plan meal')),
              _saveRecipeMenu(idea),
              OutlinedButton.icon(onPressed: () { Navigator.pop(sheet); _addRecipePhoto(idea); },
                icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Attach photo')),
              OutlinedButton.icon(onPressed: () { Navigator.pop(sheet); _addGroceries(idea); },
                icon: const Icon(Icons.shopping_cart_outlined), label: const Text('Add groceries')),
            ]),
          ],
        ),
      )));
  }

  @override
  Widget build(BuildContext context) {
    final ideas = _results?.meals ?? const <SalusMealIdea>[];
    final scheduled = ideas.any((m) => m.date != null && m.slot == 'Dinner');
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      const SalusSectionTitle(title: 'Discover meals', eyebrow: 'Find it • Plan it • Cook it'),
      const SizedBox(height: 8),
      const Text('Describe what you want to cook, or let Salus AI fill your unplanned dinners.',
        style: TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 15),
      TextField(controller: _request, minLines: 2, maxLines: 4,
        decoration: const InputDecoration(border: OutlineInputBorder(),
          hintText: 'e.g. Mediterranean dinners with chicken, high protein, under 30 minutes',
          labelText: 'Ask Salus AI for meal ideas')),
      const SizedBox(height: 9),
      FilledButton.icon(onPressed: _searching ? null : () => _search(),
        icon: _searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
        label: Text(_searching ? 'Finding recipes…' : 'Find meals with AI')),
      const SizedBox(height: 12),
      Wrap(spacing: 7, runSpacing: 7, children: [
        ActionChip(label: const Text('Mediterranean'), onPressed: _searching ? null : () => _search('Suggest eight Mediterranean dinners with complete recipes')),
        ActionChip(label: const Text('Mexican'), onPressed: _searching ? null : () => _search('Suggest eight Mexican dinner recipes')),
        ActionChip(label: const Text('Use my ingredients'), onPressed: _searching ? null : () { _request.text = 'I have: '; _toast('Add your ingredients in the search box, then tap Find meals.'); }),
        ActionChip(label: const Text('Fill unplanned dinners'), onPressed: _searching ? null : () => _search('Fill my unplanned dinners this week with different easy meals and assign the available dates')),
      ]),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodPreferencesScreen()));
          await _loadPreferences();
        }, icon: const Icon(Icons.tune_rounded),
        label: Text('Food preferences • ${_preferences.cuisines.isEmpty ? 'Set favorites' : _preferences.cuisines.join(', ')}'),
      ),
      const SizedBox(height: 10),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_error!, style: const TextStyle(color: AppTheme.rose))),
      if (_results != null) ...[
        const SizedBox(height: 10),
        Text('${ideas.length} AI meal suggestion${ideas.length == 1 ? '' : 's'}',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.bold)),
        if ((_results?.note ?? '').isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 5),
            child: Text(_results!.note, style: const TextStyle(color: AppTheme.textSecondary))),
        if (scheduled) ...[
          const SizedBox(height: 10),
          FilledButton.tonalIcon(onPressed: _applying ? null : _applyGeneratedWeek,
            icon: const Icon(Icons.calendar_month_rounded), label: const Text('Review and add unplanned dinners')),
        ],
        const SizedBox(height: 8),
        for (final idea in ideas) ...[
          SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SalusRecipePhoto(imagePath: idea.imagePath, width: 110, height: 88),
            const SizedBox(height: 7),
            Text(idea.name, style: const TextStyle(color: AppTheme.textPrimary,
              fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${idea.cuisine} • ${idea.minutes} min • ${idea.servings} servings',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Text(idea.description, style: const TextStyle(color: AppTheme.textPrimary)),
            const SizedBox(height: 7),
            Text('Estimated per serving: ${idea.calories?.round().toString() ?? '—'} kcal · ${idea.protein?.round().toString() ?? '—'} g protein',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            if (idea.date != null && idea.slot != null)
              Text('Suggested: ${idea.date} · ${idea.slot}',
                style: const TextStyle(color: AppTheme.cyan, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              OutlinedButton(onPressed: () => _showRecipe(idea), child: const Text('View recipe')),
              OutlinedButton.icon(onPressed: () => _addRecipePhoto(idea),
                icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Photo')),
              _saveRecipeMenu(idea),
              FilledButton.tonal(onPressed: _applying ? null : () => _planRecipe(idea), child: const Text('Plan meal')),
            ]),
          ])),
          const SizedBox(height: 9),
        ],
        OutlinedButton.icon(
          onPressed: _searching || _applying ? null : () => _search(null, true),
          icon: _more ? const Icon(Icons.hourglass_empty) : const Icon(Icons.refresh_rounded),
          label: Text(_more ? 'Finding more…' : 'Find more recipes'),
        ),
        const SizedBox(height: 10),
        const Text('AI recipes and nutrient estimates require review. Nothing is logged as eaten until you log it yourself.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    ]);
  }
}
