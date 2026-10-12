import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/ai_meal_planner_service.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/salus_widgets.dart';

/// A real month/week view of the existing persisted meal plan. Empty slots are
/// visible; stored AI recipe detail is supplementary and never replaces plans.
class MealCalendarScreen extends ConsumerStatefulWidget {
  final VoidCallback onDiscover;
  const MealCalendarScreen({super.key, required this.onDiscover});
  @override
  ConsumerState<MealCalendarScreen> createState() => _MealCalendarScreenState();
}

class _MealCalendarScreenState extends ConsumerState<MealCalendarScreen> {
  final _service = const SalusMealPlannerService();
  DateTime _selected = DateTime.now();
  bool _monthly = false;
  Map<String, SalusMealIdea> _recipes = {};

  @override
  void initState() { super.initState(); _loadRecipes(); }
  Future<void> _loadRecipes() async {
    final data = await _service.loadRecipeAssignments();
    if (mounted) setState(() => _recipes = data);
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _startOfWeek(DateTime day) => _day(day).subtract(Duration(days: day.weekday - 1));

  List<DateTime> _dates() {
    if (!_monthly) {
      final monday = _startOfWeek(_selected);
      return [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    }
    final first = DateTime(_selected.year, _selected.month, 1);
    final start = _startOfWeek(first);
    final next = DateTime(_selected.year, _selected.month + 1, 1);
    final last = next.subtract(const Duration(days: 1));
    final days = last.difference(start).inDays + 1;
    final count = ((days + 6) ~/ 7) * 7;
    return [for (var i = 0; i < count; i++) start.add(Duration(days: i))];
  }

  String _short(DateTime d) => '${d.month}/${d.day}';
  int _filled(DateTime date) => salusMealSlots
      .where((slot) => (ref.read(todayPlanStateProvider).mealsFor(date)[slot] ?? '').trim().isNotEmpty).length;

  Future<void> _editSlot(String slot, String original) async {
    final controller = TextEditingController(text: original);
    final value = await showDialog<String>(context: context, builder: (dialog) => AlertDialog(
      title: Text('${_short(_selected)} • $slot'),
      content: TextField(controller: controller, autofocus: true,
        decoration: const InputDecoration(labelText: 'Meal name', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(dialog, ''), child: const Text('Clear')),
        FilledButton(onPressed: () => Navigator.pop(dialog, controller.text.trim()), child: const Text('Save')),
      ],
    ));
    // The dialog is closed; dispose the controller after the current frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (value == null || !mounted) return;
    await ref.read(todayPlanStateProvider.notifier).setMeal(_selected, slot, value);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Calendar updated. Planned meals are not logged as eaten.')));
  }

  void _viewRecipe(SalusMealIdea meal) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (sheet) => SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(meal.name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${meal.cuisine} • ${meal.minutes} minutes • ${meal.servings} servings'),
            const SizedBox(height: 7),
            Text('AI estimated per serving: ${meal.calories?.round() ?? '—'} kcal, ${meal.protein?.round() ?? '—'} g protein.'),
            const SizedBox(height: 16),
            const Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            for (final ingredient in meal.ingredients) Text('• $ingredient'),
            const SizedBox(height: 16),
            const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(meal.recipe), const SizedBox(height: 12),
            const Text('Ingredient, nutrition and allergy safety require review.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      )));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(todayPlanStateProvider, (_, __) { _loadRecipes(); });
    final plans = ref.watch(todayPlanStateProvider);
    final meals = plans.mealsFor(_selected);
    final dates = _dates();
    final filled = salusMealSlots.where((s) => (meals[s] ?? '').trim().isNotEmpty).length;
    final monthTitle = '${const [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ][_selected.month - 1]} ${_selected.year}';
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      const SalusSectionTitle(title: 'Meal calendar', eyebrow: 'Planned • Missing • Ready'),
      const SizedBox(height: 8),
      const Text('An empty circle means a meal is not planned. Green means all four slots are filled.',
        style: TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 12),
      Row(children: [
        IconButton(tooltip: 'Previous', icon: const Icon(Icons.chevron_left), onPressed: () => setState(() {
          _selected = _monthly ? DateTime(_selected.year, _selected.month - 1, 1)
              : _selected.subtract(const Duration(days: 7));
        })),
        Expanded(child: Text(_monthly ? monthTitle : '${_short(dates.first)} – ${_short(dates.last)}',
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
        IconButton(tooltip: 'Next', icon: const Icon(Icons.chevron_right), onPressed: () => setState(() {
          _selected = _monthly ? DateTime(_selected.year, _selected.month + 1, 1)
              : _selected.add(const Duration(days: 7));
        })),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ChoiceChip(label: const Text('Week'), selected: !_monthly,
          onSelected: (_) => setState(() => _monthly = false)),
        const SizedBox(width: 10),
        ChoiceChip(label: const Text('Month'), selected: _monthly,
          onSelected: (_) => setState(() => _monthly = true)),
        const SizedBox(width: 10),
        TextButton(onPressed: () => setState(() => _selected = DateTime.now()), child: const Text('Today')),
      ]),
      const SizedBox(height: 10),
      Row(children: [for (final day in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
        Expanded(child: Center(child: Text(day, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))))]),
      const SizedBox(height: 5),
      GridView.count(crossAxisCount: 7, childAspectRatio: _monthly ? 0.75 : 0.67,
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 5, crossAxisSpacing: 4,
        children: [for (final date in dates)
          InkWell(borderRadius: BorderRadius.circular(9), onTap: () => setState(() => _selected = date),
            child: Container(
              decoration: BoxDecoration(
                color: salusDayKey(date) == salusDayKey(_selected) ? AppTheme.surfaceHigh : AppTheme.surface,
                border: Border.all(color: salusDayKey(date) == salusDayKey(_selected) ? AppTheme.cyan : AppTheme.border),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${date.day}', style: TextStyle(fontWeight: FontWeight.bold,
                  color: _monthly && date.month != _selected.month ? AppTheme.textMuted : AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Icon(_filled(date) == 4 ? Icons.check_circle :
                  _filled(date) == 0 ? Icons.radio_button_unchecked : Icons.adjust,
                  color: _filled(date) == 4 ? AppTheme.mint :
                    _filled(date) == 0 ? AppTheme.textMuted : AppTheme.amber,
                  size: 15),
                Text('${_filled(date)}/4', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              ]),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Text('${_short(_selected)} • $filled of 4 meal slots planned',
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      for (final slot in salusMealSlots) ...[
        Builder(builder: (context) {
          final name = (meals[slot] ?? '').trim();
          final recipe = _recipes['${salusDayKey(_selected)}|$slot'];
          return SalusPaper(child: Row(children: [
            Icon(name.isEmpty ? Icons.radio_button_unchecked : Icons.check_circle_outline,
              color: name.isEmpty ? AppTheme.textMuted : AppTheme.mint),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slot, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Text(name.isEmpty ? 'Not planned' : name,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
              if (recipe != null && recipe.name == name) Text('${recipe.minutes} min • AI recipe saved',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ])),
            if (recipe != null && recipe.name == name) IconButton(tooltip: 'View recipe',
              onPressed: () => _viewRecipe(recipe), icon: const Icon(Icons.menu_book_outlined)),
            IconButton(tooltip: name.isEmpty ? 'Plan meal' : 'Edit planned meal',
              onPressed: () => _editSlot(slot, name), icon: Icon(name.isEmpty ? Icons.add_circle_outline : Icons.edit_outlined)),
          ]));
        }),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: widget.onDiscover,
        icon: const Icon(Icons.auto_awesome), label: const Text('Find and plan meals with Salus AI')),
      const SizedBox(height: 8),
      const Text('Planned meals do not count toward daily calories until logged after eating.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    ]);
  }
}
