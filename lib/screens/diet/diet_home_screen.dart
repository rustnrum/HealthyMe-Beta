import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/salus_widgets.dart';
import 'food_entry_dialog.dart';
import 'food_photo_analysis_screen.dart';
import 'food_catalog_screen.dart';
import 'food_visual_overview.dart';

class DietHomeScreen extends ConsumerWidget {
  const DietHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(dietLogStateProvider);
    final today = DateTime.now();
    final foods = log.forDay(today);
    final meals = ref.watch(todayPlanStateProvider).mealsFor(today);
    // Today's best shortcuts: real previously logged foods, no fake catalog.
    final seenFoods = <String>{};
    final recentFoods = <FoodLogEntry>[];
    for (final entry in log.entries.reversed) {
      final key = '${entry.name.trim().toLowerCase()}|${entry.portion.trim().toLowerCase()}';
      if (seenFoods.add(key)) recentFoods.add(entry);
      if (recentFoods.length >= 5) break;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        const SalusSectionTitle(title: 'Today', eyebrow: 'Nutrition journal'),
        const SizedBox(height: 6),
        const Text('Only food you actually log is counted. Missing nutrients are never estimated.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
        const SizedBox(height: 15),
        FoodVisualOverview(log: log, day: today),
        const SizedBox(height: 12),
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nutrient details', style: TextStyle(
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
        const SizedBox(height: 14),
        // Photo recognition is explicit, reviewable and always optional.
        SalusPaper(glow: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const FoodPhotoAnalysisScreen())),
          child: const Row(children: [
            Icon(Icons.camera_alt_rounded, color: AppTheme.mint, size: 37),
            SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Take a food photo', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 20,
                  fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('AI estimate → review → log', style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12.5)),
              ])),
            Icon(Icons.chevron_right_rounded, color: AppTheme.mint),
          ])),
        const SizedBox(height: 10),
        // Barcode uses the local camera decoder and Open Food Facts.
        SalusPaper(glow: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const FoodCatalogScreen(barcodeMode: true))),
          child: Row(children: [
            Container(width: 69, height: 69,
              decoration: BoxDecoration(
                color: AppTheme.mint.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.qr_code_scanner_rounded,
                color: AppTheme.mint, size: 41)),
            const SizedBox(width: 14),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scan your food', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 21,
                  fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Camera scan → serving → saved',
                  style: TextStyle(color: AppTheme.textSecondary,
                      fontSize: 12.5)),
              ])),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.mint),
          ])),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: SalusPaper(onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FoodCatalogScreen())),
            child: const Row(children: [
              Icon(Icons.search_rounded, color: AppTheme.cyan),
              SizedBox(width: 8),
              Expanded(child: Text('Find food', style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w800))),
            ]))),
          const SizedBox(width: 10),
          Expanded(child: SalusPaper(onTap: () => showFoodEntryDialog(context),
            child: const Row(children: [
              Icon(Icons.edit_note_rounded, color: AppTheme.amber),
              SizedBox(width: 8),
              Expanded(child: Text('Quick add', style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w800))),
            ]))),
        ]),
        if (recentFoods.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SalusSectionTitle(title: 'Log again', eyebrow: 'Your recent foods · one tap'),
          const SizedBox(height: 10),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final entry in recentFoods) ...[
                SizedBox(width: 152, child: SalusPaper(onTap: () {
                    ref.read(dietLogStateProvider.notifier).repeatFood(entry, entry.slot);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Added ${entry.name} to ${entry.slot}')));
                  }, child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FoodPicture(imageUrl: entry.imageUrl, size: 58),
                      const SizedBox(height: 7),
                      Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary, fontSize: 13)),
                      Text(entry.portion.isEmpty ? entry.slot : entry.portion,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSecondary,
                              fontSize: 11)),
                      const SizedBox(height: 4),
                      const Icon(Icons.add_circle_outline, color: AppTheme.mint, size: 20),
                    ]))),
                const SizedBox(width: 8),
              ],
            ])),
        ],
        const SizedBox(height: 16),
        const SalusSectionTitle(title: 'Meals', eyebrow: 'Recorded today'),
        const SizedBox(height: 8),
        for (final slot in salusMealSlots) ...[
          SalusPaper(onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FoodCatalogScreen(initialSlot: slot))),
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
              leading: FoodPicture(imageUrl: food.imageUrl),
              title: Text(food.name, style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text('${food.slot}${food.portion.isEmpty ? '' : ' • ${food.portion}'}'
                  '${food.sourceName == 'Manual' ? '' : ' • ${food.sourceName}'}',
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
