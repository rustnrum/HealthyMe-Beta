import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/salus_widgets.dart';
import 'diet_shell.dart';

class DietPlanningScreen extends ConsumerWidget {
  const DietPlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime.now();
    final meals = ref.watch(todayPlanStateProvider).mealsFor(date);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        const SalusSectionTitle(
          title: 'Today’s menu',
          eyebrow: 'Breakfast • Lunch • Dinner • Snacks',
        ),
        const SizedBox(height: 5),
        const Text(
          'Plan what you intend to eat. The same menu appears on the Salus Today page.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        for (final slot in salusMealSlots) ...[
          SalusPaper(
            onTap: () => _editMeal(context, ref, date, slot, meals[slot] ?? ''),
            child: Row(
              children: [
                Icon(_icon(slot), color: _color(slot)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot,
                        style: const TextStyle(
                          color: DietPalette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (meals[slot] ?? '').trim().isEmpty
                            ? 'Not planned'
                            : meals[slot]!,
                        style: TextStyle(
                          color: (meals[slot] ?? '').trim().isEmpty
                              ? DietPalette.textMuted
                              : DietPalette.textSecondary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.edit_rounded,
                  color: DietPalette.textSecondary,
                  size: 19,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }

  Future<void> _editMeal(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    String slot,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(slot),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '$slot plan',
            hintText: 'What are you having?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await ref.read(todayPlanStateProvider.notifier).setMeal(date, slot, value);
  }

  static IconData _icon(String slot) => switch (slot) {
        'Breakfast' => Icons.wb_sunny_outlined,
        'Lunch' => Icons.light_mode_outlined,
        'Dinner' => Icons.wb_twilight_outlined,
        _ => Icons.bedtime_outlined,
      };

  static Color _color(String slot) => switch (slot) {
        'Breakfast' => AppTheme.mint,
        'Lunch' => AppTheme.amber,
        'Dinner' => AppTheme.rose,
        _ => AppTheme.purple,
      };
}
