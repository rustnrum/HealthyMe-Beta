import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/food_catalog_service.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import 'food_visual_overview.dart';

/// Portion and meal are the only routine user decisions after recognizing food.
/// No fabricated serving weight or missing nutrient is ever saved as factual.
class FoodPortionSheet extends ConsumerStatefulWidget {
  final CatalogFood food;
  final String initialSlot;
  const FoodPortionSheet({super.key, required this.food, required this.initialSlot});

  @override
  ConsumerState<FoodPortionSheet> createState() => _FoodPortionSheetState();
}

class _FoodPortionSheetState extends ConsumerState<FoodPortionSheet> {
  late String _slot;
  late double _grams;
  bool _custom = false;
  bool _saving = false;
  final _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _slot = widget.initialSlot;
    _grams = widget.food.servingGrams ?? 100;
  }

  @override
  void dispose() { _customController.dispose(); super.dispose(); }

  String _number(double value) => value == value.roundToDouble()
      ? value.round().toString() : value.toStringAsFixed(1);

  Widget _nutrition(String name, double? per100g, String units) {
    final value = widget.food.scaled(per100g, _grams);
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value == null ? '—' : '${_number(value)} $units',
          style: const TextStyle(color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900, fontSize: 17)),
        Text(name, style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 12)),
      ]));
  }

  Future<void> _log() async {
    if (_saving || !_grams.isFinite || _grams <= 0 || _grams > 10000) return;
    setState(() => _saving = true);
    try {
      final food = widget.food;
      await ref.read(dietLogStateProvider.notifier).addFood(FoodLogEntry(
        id: '', eatenAt: DateTime.now(), slot: _slot,
        name: food.name, portion: '${_number(_grams)} g',
        calories: food.scaled(food.kcal100g, _grams),
        protein: food.scaled(food.protein100g, _grams),
        carbs: food.scaled(food.carbs100g, _grams),
        fat: food.scaled(food.fat100g, _grams),
        fiber: food.scaled(food.fiber100g, _grams),
        sourceName: 'Open Food Facts', sourceId: food.code,
        imageUrl: food.imageUrl ?? '',
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save this food. Please try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final serving = food.servingGrams;
    return SafeArea(top: false, child: Padding(
      padding: EdgeInsets.fromLTRB(18, 8, 18,
        22 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            FoodPicture(imageUrl: food.imageUrl ?? '', size: 78),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textPrimary,
                    fontSize: 19, fontWeight: FontWeight.w900)),
                Text(food.brand.isNotEmpty ? food.brand : 'Open Food Facts',
                  style: const TextStyle(color: AppTheme.textSecondary)),
              ])),
          ]),
          const SizedBox(height: 20),
          const Text('How much did you eat?', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 17,
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (serving != null) ...[
              ChoiceChip(label: Text('½ serving · ${_number(serving / 2)} g'),
                selected: !_custom && _grams == serving / 2,
                onSelected: (_) => setState(() { _grams = serving / 2; _custom = false; })),
              ChoiceChip(label: Text('1 serving · ${_number(serving)} g'),
                selected: !_custom && _grams == serving,
                onSelected: (_) => setState(() { _grams = serving; _custom = false; })),
              ChoiceChip(label: Text('2 servings · ${_number(serving * 2)} g'),
                selected: !_custom && _grams == serving * 2,
                onSelected: (_) => setState(() { _grams = serving * 2; _custom = false; })),
            ],
            ChoiceChip(label: const Text('100 g'),
              selected: !_custom && _grams == 100,
              onSelected: (_) => setState(() { _grams = 100; _custom = false; })),
            ChoiceChip(label: const Text('Custom weight'),
              selected: _custom,
              onSelected: (_) => setState(() {
                _custom = true;
                _customController.text = _number(_grams);
              })),
          ]),
          if (_custom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Grams eaten'),
              onChanged: (s) => setState(() { _grams = double.tryParse(s) ?? 0; }),
            ),
          ],
          if (serving == null) ...[
            const SizedBox(height: 8),
            const Text('Serving weight unavailable. 100 g is a starting choice, '
                'not an estimate of your actual portion.',
              style: TextStyle(color: AppTheme.amber, fontSize: 12)),
          ] else if (food.servingLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Package serving: ${food.servingLabel}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 19),
          const Text('Add to', style: TextStyle(color: AppTheme.textPrimary,
              fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final slot in salusMealSlots)
              ChoiceChip(label: Text(slot), selected: _slot == slot,
                onSelected: (_) => setState(() => _slot = slot)),
          ]),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(17)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('For ${_number(_grams)} g', style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 7),
              Row(children: [
                _nutrition('Calories', food.kcal100g, 'kcal'),
                _nutrition('Protein', food.protein100g, 'g'),
                _nutrition('Carbs', food.carbs100g, 'g'),
                _nutrition('Fat', food.fat100g, 'g'),
              ]),
            ])),
          const SizedBox(height: 8),
          const Text('Nutrition: Open Food Facts community database. '
              'Check the package label; missing values stay unknown.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
          const SizedBox(height: 15),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _saving || _grams <= 0 || _grams > 10000 ? null : _log,
            icon: _saving ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_circle_outline),
            label: Text(_saving ? 'Saving…' : 'Add to $_slot'),
          )),
        ],
      )),
    ));
  }
}
