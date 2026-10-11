"""Build 60: visually faster food diary with verified manual/product logging.

Fix Run #93 by shipping the corrected Build 59 scripts before this patch.
Idempotent on a committed Build 60 checkout. Existing saved keys, signature,
package ID, and working Garmin notification implementation are unchanged.
"""
from pathlib import Path


def replace(path, old, new):
    file = Path(path)
    contents = file.read_text(encoding='utf-8')
    if new in contents:
        return
    count = contents.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one anchor, found {count}: {old[:120]!r}')
    file.write_text(contents.replace(old, new, 1), encoding='utf-8')


log = 'lib/state/diet_log_state.dart'
replace(log,
'''  final String slot, name, portion;
  final double? calories, protein, carbs, fat, fiber;''',
'''  final String slot, name, portion;
  final String sourceName, sourceId, imageUrl;
  final double? calories, protein, carbs, fat, fiber;''')
replace(log,
'''    required this.slot, required this.name, this.portion = '',
    this.calories, this.protein, this.carbs, this.fat, this.fiber});''',
'''    required this.slot, required this.name, this.portion = '',
    this.calories, this.protein, this.carbs, this.fat, this.fiber,
    this.sourceName = 'Manual', this.sourceId = '', this.imageUrl = ''});''')
replace(log,
'''    'protein': protein, 'carbs': carbs, 'fat': fat, 'fiber': fiber,
  };''',
'''    'protein': protein, 'carbs': carbs, 'fat': fat, 'fiber': fiber,
    'sourceName': sourceName, 'sourceId': sourceId, 'imageUrl': imageUrl,
  };''')
replace(log,
'''    fiber: (j['fiber'] as num?)?.toDouble(),
  );''',
'''    fiber: (j['fiber'] as num?)?.toDouble(),
    sourceName: j['sourceName']?.toString() ?? 'Manual',
    sourceId: j['sourceId']?.toString() ?? '',
    imageUrl: j['imageUrl']?.toString() ?? '',
  );''')
replace(log,
'''        portion: portion, calories: calories, protein: protein,
        carbs: carbs, fat: fat, fiber: fiber);''',
'''        portion: portion, calories: calories, protein: protein,
        carbs: carbs, fat: fat, fiber: fiber,
        sourceName: sourceName, sourceId: sourceId, imageUrl: imageUrl);''')

home='lib/screens/diet/diet_home_screen.dart'
replace(home,
'''import 'food_entry_dialog.dart';''',
'''import 'food_entry_dialog.dart';
import 'food_catalog_screen.dart';
import 'food_visual_overview.dart';''')
replace(home,
'''    final meals = ref.watch(todayPlanStateProvider).mealsFor(today);
    return ListView(''',
'''    final meals = ref.watch(todayPlanStateProvider).mealsFor(today);
    // Today's best shortcuts: real previously logged foods, no fake catalog.
    final seenFoods = <String>{};
    final recentFoods = <FoodLogEntry>[];
    for (final entry in log.entries.reversed) {
      final key = '${entry.name.trim().toLowerCase()}|${entry.portion.trim().toLowerCase()}';
      if (seenFoods.add(key)) recentFoods.add(entry);
      if (recentFoods.length >= 5) break;
    }
    return ListView(''')
replace(home,
'''        const SizedBox(height: 15),
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recorded nutrients',''',
'''        const SizedBox(height: 15),
        FoodVisualOverview(log: log, day: today),
        const SizedBox(height: 12),
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nutrient details',''')
replace(home,
'''        const SizedBox(height: 12),
        SalusPaper(onTap: () => showFoodEntryDialog(context),''',
'''        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: SalusPaper(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const FoodCatalogScreen())),
            child: const Column(children: [
              Icon(Icons.search_rounded, color: AppTheme.mint, size: 28),
              SizedBox(height: 5),
              Text('Find food', style: TextStyle(color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700)),
            ]))),
          const SizedBox(width: 10),
          Expanded(child: SalusPaper(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const FoodCatalogScreen(barcodeMode: true))),
            child: const Column(children: [
              Icon(Icons.qr_code_rounded, color: AppTheme.amber, size: 28),
              SizedBox(height: 5),
              Text('Barcode lookup', style: TextStyle(color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700)),
            ]))),
        ]),
        const SizedBox(height: 12),
        SalusPaper(onTap: () => showFoodEntryDialog(context),''')
replace(home,
'''        const SizedBox(height: 16),
        const SalusSectionTitle(title: 'Meals', eyebrow: 'Recorded today'),''',
'''        if (recentFoods.isNotEmpty) ...[
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
        const SalusSectionTitle(title: 'Meals', eyebrow: 'Recorded today'),''')
replace(home,
'''            ListTile(
              title: Text(food.name, style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text('${food.slot}${food.portion.isEmpty ? '' : ' • ${food.portion}'}',''',
'''            ListTile(
              leading: FoodPicture(imageUrl: food.imageUrl),
              title: Text(food.name, style: const TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text('${food.slot}${food.portion.isEmpty ? '' : ' • ${food.portion}'}'
                  '${food.sourceName == 'Manual' ? '' : ' • ${food.sourceName}'}',''')
# Product lookup is a real HTTPS request. Ship network permission in the
# main app manifest, not only the temporary debug Android shell.
replace('native/android/AndroidManifest.xml',
'''    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />''',
'''    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />''')

replace('pubspec.yaml', 'version: 0.21.21+59', 'version: 0.21.22+60')
for file in Path('test').glob('*.dart'):
    before=file.read_text(encoding='utf-8')
    after=before.replace('version: 0.21.21+59','version: 0.21.22+60')
    if after!=before: file.write_text(after,encoding='utf-8')
# Run #94: legacy tests still asserted behavior intentionally removed by
# Build 59 Steps changes. Preserve both tests; update only stale assumptions:
# explicitly forced direct sync and a genuinely same-day Garmin step sample.
replace('test/build39_routes_and_notifications_test.dart',
'''    expect(sync, contains('_refreshSavedDirectDevices()'));''',
'''    expect(sync, contains('_refreshSavedDirectDevices(force: forceDirect)'));''')
replace('test/build27_direct_metrics_test.dart',
'''  test('Garmin realtime metrics become direct selectable sources', () {
    final service = DirectMetricService();
    final now = DateTime(2026, 10, 6, 16);''',
'''  test('Garmin realtime metrics become direct selectable sources', () {
    final service = DirectMetricService();
    // An old step total cannot be today's walking; use an actual same-day poll.
    final now = DateTime.now();''')

print('Build 60: corrected Steps build + Open Food Facts search, portions, visual logging, repeat shortcuts')
