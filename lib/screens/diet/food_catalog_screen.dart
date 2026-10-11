import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/food_catalog_service.dart';
import '../../widgets/salus_widgets.dart';
import 'food_barcode_scanner_screen.dart';
import 'food_portion_sheet.dart';
import 'food_visual_overview.dart';

/// Search or camera-scan a real packaged food. Manual barcode typing is only a
/// fallback; normal logging needs one serving choice and a single save tap.
class FoodCatalogScreen extends ConsumerStatefulWidget {
  final bool barcodeMode;
  final String? initialSlot;
  const FoodCatalogScreen({super.key, this.barcodeMode = false,
    this.initialSlot});

  @override
  ConsumerState<FoodCatalogScreen> createState() => _FoodCatalogScreenState();
}

class _FoodCatalogScreenState extends ConsumerState<FoodCatalogScreen> {
  final _query = TextEditingController();
  bool _busy = false;
  bool _scanning = false;
  String? _error;
  List<CatalogFood> _results = const [];
  late final String _initialSlot;

  @override
  void initState() {
    super.initState();
    _initialSlot = widget.initialSlot ?? _defaultSlot();
    if (widget.barcodeMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scan();
      });
    }
  }

  String _defaultSlot() {
    final hour = DateTime.now().hour;
    if (hour < 10) return 'Breakfast';
    if (hour < 15) return 'Lunch';
    if (hour < 20) return 'Dinner';
    return 'Snacks';
  }

  @override
  void dispose() { _query.dispose(); super.dispose(); }

  Future<void> _search() async {
    if (_busy) return;
    final term = _query.text.trim();
    if (term.isEmpty) {
      setState(() => _error = 'Enter a food or brand to search.');
      return;
    }
    setState(() { _busy = true; _error = null; _results = const []; });
    try {
      final found = await const FoodCatalogService().search(term);
      if (!mounted) return;
      setState(() {
        _results = found;
        if (found.isEmpty) _error =
            'No matching foods with usable information. Try the brand or a simpler name.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is FormatException) return error.message;
    final message = error.toString().toLowerCase();
    if (message.contains('rate-limiting') || message.contains('429')) {
      return 'Open Food Facts is limiting searches right now. Wait a minute and try again.';
    }
    if (message.contains('socket') || message.contains('timeout') ||
        message.contains('handshake') || message.contains('network')) {
      return 'Could not reach Open Food Facts. Check your connection and retry.';
    }
    return 'Open Food Facts did not respond. Please try again.';
  }

  Future<void> _scan() async {
    if (_scanning || _busy) return;
    setState(() => _scanning = true);
    String? code;
    try {
      code = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => const FoodBarcodeScannerScreen()));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
    if (!mounted || code == null) return;
    setState(() { _busy = true; _error = null; _results = const []; });
    try {
      final products = await const FoodCatalogService().lookupBarcode(code);
      if (!mounted) return;
      if (products.isEmpty) {
        setState(() => _error = 'Barcode $code is not in Open Food Facts, '
            'or its entry has no usable details. Try searching by name.');
        return;
      }
      setState(() => _results = products);
      await _openPortion(products.first);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manualBarcode() async {
    var digits = '';
    // A separate dialog keeps the main food screen genuinely camera-first.
    final code = await showDialog<String>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter barcode manually'),
        content: TextField(onChanged: (value) => digits = value,
          autofocus: true, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'UPC / EAN digits')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, digits.trim()),
            child: const Text('Look up')),
        ],
      ));
    if (!mounted || code == null) return;
    setState(() { _busy = true; _error = null; _results = const []; });
    try {
      final found = await const FoodCatalogService().lookupBarcode(code);
      if (!mounted) return;
      setState(() {
        _results = found;
        if (found.isEmpty) _error = 'No food found for barcode $code.';
      });
      if (found.isNotEmpty) await _openPortion(found.first);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPortion(CatalogFood food) async {
    final logged = await showModalBottomSheet<bool>(context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => FoodPortionSheet(food: food, initialSlot: _initialSlot));
    if (!mounted || logged != true) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${food.name} added to your food log'),
      action: SnackBarAction(label: 'Done',
        onPressed: () { if (mounted) Navigator.of(context).pop(); }),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add food')),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        const SalusSectionTitle(title: 'What did you eat?',
          eyebrow: 'Scan · Choose a serving · Log'),
        const SizedBox(height: 15),
        SalusPaper(onTap: _busy ? null : _scan, glow: true,
          child: Row(children: [
            Container(width: 65, height: 65, decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.qr_code_scanner_rounded,
                color: AppTheme.mint, size: 40)),
            const SizedBox(width: 15),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scan a barcode', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 21,
                  fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Point your camera at the package',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
              ])),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.mint),
          ])),
        const SizedBox(height: 22),
        const Text('Or find food by name', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 17,
          fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(controller: _query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'Greek yogurt, bread, protein shake…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded),
              tooltip: 'Search foods', onPressed: _busy ? null : _search),
          )),
        const SizedBox(height: 9),
        Row(children: [
          TextButton.icon(onPressed: _busy ? null : _manualBarcode,
            icon: const Icon(Icons.keyboard_alt_outlined, size: 19),
            label: const Text('Type barcode instead')),
          const Spacer(),
          const Text('Open Food Facts', style: TextStyle(
            color: AppTheme.textMuted, fontSize: 11.5)),
        ]),
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          const Text('Looking up food…', style: TextStyle(
            color: AppTheme.textSecondary, fontSize: 12)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 15),
          SalusPaper(child: Row(children: [
            const Icon(Icons.info_outline, color: AppTheme.amber),
            const SizedBox(width: 10),
            Expanded(child: Text(_error!, style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 13))),
          ])),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 20),
          SalusSectionTitle(title: 'Matches (${_results.length})',
            eyebrow: 'Tap a food to choose your serving'),
          const SizedBox(height: 10),
          for (final food in _results) ...[
            SalusPaper(onTap: () => _openPortion(food), child: Row(children: [
              FoodPicture(imageUrl: food.imageUrl ?? '', size: 72),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textPrimary,
                      fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(food.brand.isEmpty ? 'Brand not recorded' : food.brand,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary,
                      fontSize: 12)),
                  if (food.servingGrams != null)
                    Text('Serving: ${food.servingLabel}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textMuted,
                        fontSize: 11.5)),
                  Text(food.kcal100g == null ? 'Nutrition incomplete'
                      : '${food.kcal100g!.round()} kcal per 100 g',
                    style: const TextStyle(color: AppTheme.mint, fontSize: 12.5)),
                ])),
              const Icon(Icons.add_circle_outline_rounded, color: AppTheme.mint),
            ])),
            const SizedBox(height: 9),
          ],
        ],
        const SizedBox(height: 22),
        const Text('Product details and photos are provided by Open Food Facts '
            '(ODbL database; CC BY-SA images). Entries are crowdsourced and '
            'may be missing or incorrect. Confirm against packaging.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
      ]),
  );
}
