import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';

Future<void> showFoodEntryDialog(BuildContext context, {String? slot}) =>
    showDialog<void>(context: context,
      builder: (_) => FoodEntryDialog(initialSlot: slot ?? 'Breakfast'));

class FoodEntryDialog extends ConsumerStatefulWidget {
  final String initialSlot;
  const FoodEntryDialog({super.key, required this.initialSlot});
  @override
  ConsumerState<FoodEntryDialog> createState() => _FoodEntryDialogState();
}

class _FoodEntryDialogState extends ConsumerState<FoodEntryDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _portion = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  late String _slot;
  bool _saveMeal = false;
  bool _busy = false;

  @override
  void initState() { super.initState(); _slot = widget.initialSlot; }
  @override
  void dispose() {
    for (final c in [_name, _portion, _calories, _protein, _carbs, _fat, _fiber]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) => double.tryParse(c.text.trim());
  String? _nutrientValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.trim());
    return number == null || !number.isFinite || number < 0
        ? 'Enter a valid number or leave blank' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(dietLogStateProvider.notifier).addFood(FoodLogEntry(
        id: '', eatenAt: DateTime.now(), slot: _slot, name: _name.text.trim(),
        portion: _portion.text.trim(), calories: _parse(_calories),
        protein: _parse(_protein), carbs: _parse(_carbs), fat: _parse(_fat),
        fiber: _parse(_fiber)), saveAsTemplate: _saveMeal);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save the food entry. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _numberField(String label, TextEditingController controller) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    validator: _nutrientValidator,
    decoration: InputDecoration(labelText: label, hintText: 'Optional'),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Log food'),
    content: SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: Form(key: _form, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _slot,
              decoration: const InputDecoration(labelText: 'Meal'),
              items: [for (final meal in salusMealSlots)
                DropdownMenuItem(value: meal, child: Text(meal))],
              onChanged: (v) { if (v != null) setState(() => _slot = v); },
            ),
            TextFormField(controller: _name, autofocus: true,
              decoration: const InputDecoration(labelText: 'Food name'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Name is required' : null),
            TextFormField(controller: _portion,
              decoration: const InputDecoration(
                labelText: 'Serving / portion (optional)')),
            const SizedBox(height: 8),
            const Align(alignment: Alignment.centerLeft,
              child: Text('Only enter nutrient values you know. Salus will not guess.')),
            _numberField('Calories (kcal)', _calories),
            _numberField('Protein (g)', _protein),
            _numberField('Carbohydrates (g)', _carbs),
            _numberField('Fat (g)', _fat),
            _numberField('Fiber (g)', _fiber),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _saveMeal, title: const Text('Save to my meals'),
              onChanged: (v) => setState(() => _saveMeal = v ?? false),
            ),
          ],
        )),
      ),
    ),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel')),
      FilledButton(onPressed: _busy ? null : _save,
          child: const Text('Save food')),
    ],
  );
}
