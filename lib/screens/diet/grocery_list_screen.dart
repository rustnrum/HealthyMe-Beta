import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/salus_widgets.dart';

class GroceryListScreen extends ConsumerWidget {
  const GroceryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dietLogStateProvider);
    final plan = ref.watch(todayPlanStateProvider).mealsFor(DateTime.now());
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      const SalusSectionTitle(title: 'Grocery list', eyebrow: 'Shopping'),
      const SizedBox(height: 7),
      const Text('Add the ingredients you need. Salus will not guess ingredients or quantities from a meal name.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
      const SizedBox(height: 14),
      SalusPaper(onTap: () => _add(context, ref), child: const Row(children: [
        Icon(Icons.add_shopping_cart_rounded, color: AppTheme.mint, size: 26),
        SizedBox(width: 11),
        Expanded(child: Text('Add grocery item', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700))),
        Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
      ])),
      const SizedBox(height: 14),
      if (state.groceries.isEmpty)
        const SalusPaper(child: Text('Your grocery list is empty. Tap Add grocery item to get started.',
          style: TextStyle(color: AppTheme.textSecondary)))
      else
        for (final item in state.groceries)
          CheckboxListTile(
            value: item.checked,
            title: Text(item.name, style: TextStyle(
              decoration: item.checked ? TextDecoration.lineThrough : null,
              color: AppTheme.textPrimary)),
            onChanged: (value) => ref.read(dietLogStateProvider.notifier)
                .toggleGrocery(item.id, value ?? false),
            secondary: IconButton(
              tooltip: 'Delete grocery item',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => ref.read(dietLogStateProvider.notifier)
                  .removeGrocery(item.id)),
          ),
      const SizedBox(height: 18),
      const SalusSectionTitle(title: 'Today’s planned meals', eyebrow: 'Shopping reference'),
      const SizedBox(height: 8),
      for (final slot in salusMealSlots)
        Padding(padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text('$slot: ${plan[slot]?.isNotEmpty == true ? plan[slot] : 'Not planned'}',
            style: const TextStyle(color: AppTheme.textSecondary))),
    ]);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final input = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Add grocery item'),
      content: TextField(controller: input, autofocus: true,
        decoration: const InputDecoration(labelText: 'Item and quantity',
            hintText: 'Example: 2 onions')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialog, input.text),
          child: const Text('Add')),
      ],
    ));
    input.dispose();
    if (value != null && value.trim().isNotEmpty) {
      await ref.read(dietLogStateProvider.notifier).addGrocery(value);
    }
  }
}
