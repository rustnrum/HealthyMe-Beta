import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/food_catalog_service.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/salus_widgets.dart';

/// Explicit search instead of search-as-you-type: respects food API limits,
/// avoids accidental downloads, and shows sources for every result.
class FoodCatalogScreen extends ConsumerStatefulWidget {
  final bool barcodeMode;
  const FoodCatalogScreen({super.key, this.barcodeMode = false});

  @override
  ConsumerState<FoodCatalogScreen> createState() => _FoodCatalogScreenState();
}

class _FoodCatalogScreenState extends ConsumerState<FoodCatalogScreen> {
  final _query = TextEditingController();
  bool _barcode = false;
  bool _busy = false;
  String? _error;
  List<CatalogFood> _results = const [];

  @override
  void initState() {
    super.initState();
    _barcode = widget.barcodeMode;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; _results = const []; });
    try {
      final found = _barcode
          ? await const FoodCatalogService().lookupBarcode(_query.text)
          : await const FoodCatalogService().search(_query.text);
      if (!mounted) return;
      setState(() {
        _results = found;
        if (found.isEmpty) _error = 'No usable nutrition entry found. You can log it manually.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is FormatException
          ? e.message : 'Lookup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _log(CatalogFood food) async {
    final grams = TextEditingController(text: '100');
    var slot = 'Breakfast';
    double? amount;
    try {
      amount = await showDialog<double>(context: context, builder: (dialogContext) {
        return StatefulBuilder(builder: (context, update) {
          final amountNow = double.tryParse(grams.text.trim());
          final valid = amountNow != null && amountNow > 0 && amountNow <= 10000;
          String display(double? value, String suffix) =>
              value == null ? '—' : '${value.toStringAsFixed(1)} $suffix';
          return AlertDialog(
            title: Text(food.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            content: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.brand.isEmpty ? 'Open Food Facts' : food.brand,
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                TextField(
                  controller: grams,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount eaten in grams', hintText: 'e.g. 125'),
                  onChanged: (_) => update(() {}),
                ),
                if (food.servingLabel.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text('Package serving: ${food.servingLabel} (verify grams)',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: slot,
                  decoration: const InputDecoration(labelText: 'Meal'),
                  items: [for (final name in salusMealSlots)
                    DropdownMenuItem(value: name, child: Text(name))],
                  onChanged: (value) => update(() { if (value != null) slot = value; }),
                ),
                const SizedBox(height: 14),
                Text('Known nutrients for this amount', style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Text(valid
                    ? '${display(food.scaled(food.kcal100g, amountNow), 'kcal')} · '
                      '${display(food.scaled(food.protein100g, amountNow), 'g')} protein\n'
                      '${display(food.scaled(food.carbs100g, amountNow), 'g')} carbs · '
                      '${display(food.scaled(food.fat100g, amountNow), 'g')} fat'
                    : 'Enter a valid amount to calculate nutrition.',
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 9),
                const Text('Community-supplied data. Check your package label. Missing nutrients stay unknown.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
              ],
            )),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: valid ? () => Navigator.pop(dialogContext, amountNow) : null,
                child: const Text('Log food'),
              ),
            ],
          );
        });
      });
    } finally {
      grams.dispose();
    }
    if (!mounted || amount == null) return;
    try {
      await ref.read(dietLogStateProvider.notifier).addFood(FoodLogEntry(
        id: '', eatenAt: DateTime.now(), slot: slot,
        name: food.name,
        portion: '${amount.toStringAsFixed(0)} g',
        calories: food.scaled(food.kcal100g, amount),
        protein: food.scaled(food.protein100g, amount),
        carbs: food.scaled(food.carbs100g, amount),
        fat: food.scaled(food.fat100g, amount),
        fiber: food.scaled(food.fiber100g, amount),
        imageUrl: food.imageUrl ?? '',
        sourceName: 'Open Food Facts',
        sourceId: food.code,
      ));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged ${food.name} to $slot')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_barcode ? 'Barcode lookup' : 'Find food')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 35),
      children: [
        const SalusSectionTitle(title: 'Food library', eyebrow: 'Find · Verify · Log'),
        const SizedBox(height: 7),
        Text(_barcode
            ? 'Enter the barcode digits on a package. Camera scanning is planned; this lookup already uses real product data.'
            : 'Search packaged foods by name. Verify the label and enter the weight eaten before adding it.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 13),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.search), label: Text('Search')),
            ButtonSegment(value: true, icon: Icon(Icons.qr_code), label: Text('Barcode')),
          ],
          selected: {_barcode},
          onSelectionChanged: (selected) => setState(() {
            _barcode = selected.first;
            _results = const [];
            _error = null;
            _query.clear();
          }),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          keyboardType: _barcode ? TextInputType.number : TextInputType.text,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            prefixIcon: Icon(_barcode ? Icons.qr_code : Icons.search),
            labelText: _barcode ? 'Barcode numbers' : 'Food name or brand',
            hintText: _barcode ? 'e.g. 737628064502' : 'e.g. Greek yogurt',
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: _busy ? null : _search,
          icon: _busy ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: Text(_busy ? 'Looking up…' : 'Find food')),
        if (_error != null) ...[
          const SizedBox(height: 13),
          Text(_error!, style: const TextStyle(color: AppTheme.amber)),
        ],
        const SizedBox(height: 17),
        for (final food in _results) ...[
          SalusPaper(onTap: () => _log(food), child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(11), child:
              SizedBox(width: 62, height: 62,
                child: food.imageUrl == null
                    ? const ColoredBox(color: AppTheme.surfaceHigh,
                        child: Icon(Icons.restaurant, color: AppTheme.mint))
                    : Image.network(food.imageUrl!, fit: BoxFit.cover,
                        errorBuilder: (c, e, trace) => const ColoredBox(
                          color: AppTheme.surfaceHigh,
                          child: Icon(Icons.restaurant, color: AppTheme.mint))),
              )),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
                Text(food.brand.isEmpty ? 'Brand not recorded' : food.brand,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text(food.kcal100g == null ? 'Calories not provided'
                    : '${food.kcal100g!.round()} kcal / 100 g',
                  style: const TextStyle(color: AppTheme.mint, fontSize: 12)),
              ])),
            const Icon(Icons.add_circle_outline, color: AppTheme.mint),
          ])),
          const SizedBox(height: 9),
        ],
        const SizedBox(height: 16),
        const Text('Product names, nutrition data and photos: Open Food Facts. '
          'Database: ODbL; images: CC BY-SA. https://world.openfoodfacts.org '
          '· Community entries can be wrong or incomplete. Double-check labels.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
      ],
    ),
  );
}
