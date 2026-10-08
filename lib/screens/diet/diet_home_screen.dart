import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/salus_widgets.dart';
import 'food_entry_dialog.dart';

class DietHomeScreen extends ConsumerWidget {
  const DietHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(dietLogStateProvider);
    final today = DateTime.now();
    final foods = log.forDay(today);
    final meals = ref.watch(todayPlanStateProvider).mealsFor(today);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        const SalusSectionTitle(title: 'Today', eyebrow: 'Nutrition journal'),
        const SizedBox(height: 6),
        const Text('Only food you actually log is counted. Missing nutrients are never estimated.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
        const SizedBox(height: 15),
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recorded nutrients', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('${foods.length} food entries today • known values only',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 13),
          Wrap(spacing: 10, runSpacing: 12, children: [
            _total('Calories', log.knownTotal(today, (f) => f.calories), 'kcal',
                log.incomplete(today, (f) => f.calories)),
            _total('Protein', log.knownTotal(today, (f) => f.protein), 'g',
                log.incomplete(today, (f) => f.protein)),
            _total('Carbs', log.knownTotal(today, (f) => f.carbs), 'g',
                log.incomplete(today, (f) => f.carbs)),
            _total('Fat', log.knownTotal(today, (f) => f.fat), 'g',
                log.incomplete(today, (f) => f.fat)),
            _total('Fiber', log.knownTotal(today, (f) => f.fiber), 'g',
                log.incomplete(today, (f) => f.fiber)),
          ]),
        ])),
        const SizedBox(height: 12),
        SalusPaper(onTap: () => showFoodEntryDialog(context),
            child: const Row(children: [
              Icon(Icons.add_circle_outline_rounded, color: AppTheme.mint, size: 36),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Log food', style: TextStyle(color: AppTheme.textPrimary,
                    fontSize: 20, fontWeight: FontWeight.w800)),
                Text('Enter a serving and any known nutrients',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
              ])),
              Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ])),
        const SizedBox(height: 16),
        const SalusSectionTitle(title: 'Meals', eyebrow: 'Recorded today'),
        const SizedBox(height: 8),
        for (final slot in salusMealSlots) ...[
          SalusPaper(onTap: () => showFoodEntryDialog(context, slot: slot),
            child: Row(children: [
              Icon(_icon(slot), color: AppTheme.mint),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot, style: const TextStyle(color: AppTheme.textPrimary,
                      fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(foods.where((f) => f.slot == slot).isEmpty
                      ? 'Nothing logged • tap to add'
                      : foods.where((f) => f.slot == slot)
                          .map((f) => f.name).join(' • '),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary)),
                  if ((meals[slot] ?? '').trim().isNotEmpty)
                    Text('Planned: ${meals[slot]}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ])),
              const Icon(Icons.add_rounded, color: AppTheme.mint),
            ])),
          const SizedBox(height: 9),
        ],
        if (foods.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SalusSectionTitle(title: 'Food log', eyebrow: 'Today'),
          const SizedBox(height: 8),
          for (final food in foods.reversed)
            ListTile(
              title: Text(food.name, style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text('${food.slot}${food.portion.isEmpty ? '' : ' • ${food.portion}'}',
                  style: const TextStyle(color: AppTheme.textSecondary)),
              trailing: IconButton(tooltip: 'Delete food entry',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => ref.read(dietLogStateProvider.notifier)
                    .deleteFood(food.id)),
            ),
        ],
      ],
    );
  }

  Widget _total(String label, double? value, String unit, bool incomplete) =>
      SizedBox(width: 105, child: Column(children: [
        Text(value == null ? '—' : '${value.toStringAsFixed(0)} $unit',
            style: const TextStyle(color: AppTheme.textPrimary,
                fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text('$label${incomplete ? '*' : ''}', style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 12)),
      ]));

  IconData _icon(String slot) => switch (slot) {
    'Breakfast' => Icons.wb_sunny_outlined,
    'Lunch' => Icons.light_mode_outlined,
    'Dinner' => Icons.restaurant_rounded,
    _ => Icons.cookie_outlined,
  };
}
