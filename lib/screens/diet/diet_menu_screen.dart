import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/ai_meal_planner_service.dart';
import '../../services/salus_recipe_photo_service.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/salus_widgets.dart';
import 'food_entry_dialog.dart';

/// Saved recipes are favorites, NOT eaten food. Older logged meal templates
/// retain their independent journal behavior below the recipe library.
class DietMenuScreen extends ConsumerWidget {
  const DietMenuScreen({super.key});
  static const _service = SalusMealPlannerService();

  Future<void> _delete(BuildContext context, SalusSavedRecipe saved) async {
    final approve = await showDialog<bool>(context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove saved recipe?'),
        content: Text('Remove ${saved.recipe.name} from ${saved.category}? '
          'Existing calendar plans and food logs will not be changed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Remove')),
        ],
      ));
    if (approve == true) await _service.removeFavorite(saved.id);
  }

  Future<void> _plan(BuildContext context, WidgetRef ref, SalusSavedRecipe saved) async {
    DateTime date = DateTime.now();
    String slot = saved.category;
    final approval = await showDialog<bool>(context: context,
      builder: (dialog) => StatefulBuilder(builder: (dialog, setDialog) => AlertDialog(
        title: const Text('Plan saved recipe'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(saved.recipe.name), const SizedBox(height: 12),
          OutlinedButton.icon(icon: const Icon(Icons.calendar_today_outlined),
            label: Text('${date.month}/${date.day}/${date.year}'), onPressed: () async {
              final value = await showDatePicker(context: dialog, initialDate: date,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (value != null) setDialog(() => date = value);
            }),
          DropdownButton<String>(value: slot, isExpanded: true,
            items: [for (final item in salusMealSlots)
              DropdownMenuItem(value: item, child: Text(item))],
            onChanged: (v) { if (v != null) setDialog(() => slot = v); }),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Review')), 
        ],
      )));
    if (approval != true || !context.mounted) return;
    final original = ref.read(todayPlanStateProvider).mealsFor(date)[slot] ?? '';
    final confirm = await showDialog<bool>(context: context,
      builder: (dialog) => AlertDialog(
        title: Text(original.isEmpty ? 'Add to calendar?' : 'Replace planned meal?'),
        content: Text(original.isEmpty ? 'Add ${saved.recipe.name} to $slot?'
          : 'Replace "$original" with ${saved.recipe.name}? Nothing is logged as eaten.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Confirm')),
        ],
      ));
    if (confirm != true || !context.mounted) return;
    await ref.read(todayPlanStateProvider.notifier).setMeal(date, slot, saved.recipe.name);
    await _service.saveRecipeAssignment(salusDayKey(date), slot, saved.recipe);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Planned ${saved.recipe.name} for $slot.')));
  }

  Future<void> _details(BuildContext context, SalusMealIdea recipe) async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (sheet) => SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SalusRecipePhoto(imagePath: recipe.imagePath, width: 180, height: 140),
          const SizedBox(height: 10),
          Text(recipe.name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6), Text('${recipe.cuisine} • ${recipe.minutes} min • ${recipe.servings} servings'),
          const SizedBox(height: 5),
          Text('AI estimate per serving: ${recipe.calories?.round() ?? '—'} kcal · ${recipe.protein?.round() ?? '—'} g protein'),
          const SizedBox(height: 16), const Text('Ingredients', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          for (final ingredient in recipe.ingredients) Text('• $ingredient'),
          const SizedBox(height: 16), const Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(recipe.recipe.isEmpty ? 'Instructions not supplied.' : recipe.recipe),
          const SizedBox(height: 12),
          const Text('AI recipes are estimates. Review ingredient safety and labels.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ]),
      )));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dietLogStateProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      const SalusSectionTitle(title: 'My Meals', eyebrow: 'Saved recipes and food library'),
      const SizedBox(height: 9),
      const Text('Save AI recipes by meal type. Saving a recipe never logs it as eaten.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      const SizedBox(height: 16),
      ValueListenableBuilder<int>(
        valueListenable: SalusMealPlannerService.favoritesRevision,
        builder: (context, revision, _) => FutureBuilder<List<SalusSavedRecipe>>(
          key: ValueKey(revision), future: _service.loadFavorites(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Padding(
              padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            final favorites = snapshot.data!;
            if (favorites.isEmpty) return const SalusPaper(child: Text(
              'No AI recipes saved yet. Discover a meal and tap Save recipe.',
              style: TextStyle(color: AppTheme.textSecondary)));
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final category in SalusMealPlannerService.recipeCategories)
                if (favorites.any((entry) => entry.category == category)) ...[
                  Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                  for (final saved in favorites.where((entry) => entry.category == category)) ...[
                    SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SalusRecipePhoto(imagePath: saved.recipe.imagePath, width: 96, height: 80),
                      const SizedBox(height: 8),
                      Text(saved.recipe.name, style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
                      Text('${saved.recipe.cuisine} • ${saved.recipe.minutes} min',
                        style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 9),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        OutlinedButton(onPressed: () => _details(context, saved.recipe),
                          child: const Text('Recipe')),
                        FilledButton.tonal(onPressed: () => _plan(context, ref, saved),
                          child: const Text('Plan meal')),
                        IconButton(tooltip: 'Remove this recipe',
                          onPressed: () => _delete(context, saved),
                          icon: const Icon(Icons.delete_outline)),
                      ]),
                    ])),
                    const SizedBox(height: 8),
                  ],
                ],
            ]);
          },
        ),
      ),
      const SizedBox(height: 22),
      const SalusSectionTitle(title: 'Previously logged meals', eyebrow: 'Repeat an old entry'),
      const SizedBox(height: 8),
      SalusPaper(onTap: () => showFoodEntryDialog(context), child: const Row(children: [
        Icon(Icons.add_rounded, color: AppTheme.mint, size: 28),
        SizedBox(width: 10), Expanded(child: Text('Add food to your journal',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700))),
      ])),
      const SizedBox(height: 10),
      if (state.savedMeals.isEmpty)
        const SalusPaper(child: Text('No reusable logged meals yet.',
          style: TextStyle(color: AppTheme.textSecondary)))
      else for (final meal in state.savedMeals) ...[
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meal.name, style: const TextStyle(color: AppTheme.textPrimary,
            fontSize: 17, fontWeight: FontWeight.w700)),
          if (meal.portion.isNotEmpty) Text(meal.portion),
          Row(children: [
            Expanded(child: PopupMenuButton<String>(
              tooltip: 'Log this meal again',
              onSelected: (slot) => ref.read(dietLogStateProvider.notifier).repeatFood(meal, slot),
              itemBuilder: (context) => [for (final slot in salusMealSlots)
                PopupMenuItem(value: slot, child: Text('Log $slot'))],
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Log this meal again', style: TextStyle(color: AppTheme.mint))),
            )),
            IconButton(tooltip: 'Remove reusable food template',
              onPressed: () => ref.read(dietLogStateProvider.notifier).deleteSavedMeal(meal.id),
              icon: const Icon(Icons.delete_outline)),
          ]),
        ])),
        const SizedBox(height: 8),
      ],
    ]);
  }
}
