import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/salus_widgets.dart';
import 'food_entry_dialog.dart';

class DietMenuScreen extends ConsumerWidget {
  const DietMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dietLogStateProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      const SalusSectionTitle(title: 'Saved meals', eyebrow: 'Your own food library'),
      const SizedBox(height: 8),
      const Text('Save a meal while logging food, then reuse it without re-entering known nutrients.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
      const SizedBox(height: 15),
      SalusPaper(onTap: () => showFoodEntryDialog(context), child: const Row(children: [
        Icon(Icons.add_rounded, color: AppTheme.mint, size: 28),
        SizedBox(width: 10), Expanded(child: Text('Create a meal by logging food',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700))),
        Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
      ])),
      const SizedBox(height: 14),
      if (state.savedMeals.isEmpty)
        const SalusPaper(child: Text('No saved meals yet. When logging food, select “Save to my meals”.',
          style: TextStyle(color: AppTheme.textSecondary)))
      else
        for (final meal in state.savedMeals) ...[
          SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(meal.name, style: const TextStyle(color: AppTheme.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w700)),
            if (meal.portion.isNotEmpty)
              Text(meal.portion, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: PopupMenuButton<String>(
                tooltip: 'Repeat saved meal',
                onSelected: (slot) {
                  ref.read(dietLogStateProvider.notifier).repeatFood(meal, slot);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Added ${meal.name} to $slot')));
                },
                itemBuilder: (context) => [
                  for (final slot in salusMealSlots)
                    PopupMenuItem<String>(value: slot, child: Text(slot)),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    Icon(Icons.add_circle_outline_rounded, color: AppTheme.mint),
                    SizedBox(width: 7),
                    Text('Log this meal again', style: TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                  ]),
                ),
              )),
              IconButton(tooltip: 'Remove from saved meals',
                onPressed: () => ref.read(dietLogStateProvider.notifier)
                    .deleteSavedMeal(meal.id),
                icon: const Icon(Icons.delete_outline_rounded)),
            ]),
          ])),
          const SizedBox(height: 10),
        ],
    ]);
  }
}
