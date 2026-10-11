"""Build 64: camera-first Food logging; preserve saved meals and other modules.

The new catalog, portion sheet and scanner are supplied as source overlays.
Migrations here touch only pubspec, Android CAMERA permission, and Food Today UX.
"""
from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    value = p.read_text(encoding='utf-8')
    if new in value:
        return
    count = value.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected 1 original anchor, found {count}: {old[:90]!r}')
    p.write_text(value.replace(old, new, 1), encoding='utf-8')


replace('pubspec.yaml',
    'version: 0.21.25+63', 'version: 0.21.26+64')
replace('pubspec.yaml',
    '  image_picker: ^1.2.3',
    '  image_picker: ^1.2.3\n  mobile_scanner: ^7.4.2')

manifest = 'native/android/AndroidManifest.xml'
replace(manifest,
    '    <uses-permission android:name="android.permission.INTERNET" />',
    '    <uses-permission android:name="android.permission.INTERNET" />\n'
    '    <uses-permission android:name="android.permission.CAMERA" />\n'
    '    <uses-feature android:name="android.hardware.camera" android:required="false" />')

home = 'lib/screens/diet/diet_home_screen.dart'
s = Path(home).read_text(encoding='utf-8')
start = '''        Row(children: [
          Expanded(child: SalusPaper(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const FoodCatalogScreen())),'''
end = '''        if (recentFoods.isNotEmpty) ...['''
replacement = '''        // Camera-first daily action. Typed nutrients remain an optional fallback.
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
'''
if replacement not in s:
    if s.count(start) != 1 or s.count(end) != 1:
        raise RuntimeError('Food Today: expected unique initial action row and recent-food anchor')
    i = s.index(start)
    j = s.index(end, i)
    Path(home).write_text(s[:i] + replacement + s[j:], encoding='utf-8')
replace(home,
    '''          SalusPaper(onTap: () => showFoodEntryDialog(context, slot: slot),''',
    '''          SalusPaper(onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FoodCatalogScreen(initialSlot: slot))),''')

print('Build 64 Food: camera barcode, visual serving flow, fallbacks, and preserved log.')

# Product-identification remains useful when a community record has no
# nutritional panel. Test that unknown macros stay null, not that the item
# disappears completely (the old Build60 UX).
test_path = 'test/build60_food_catalog_test.dart'
replace(test_path,
    """  test('missing nutritional facts are not guessed', () {
    expect(CatalogFood.fromOpenFoodFacts({
      'product_name': 'Unknown',
      'nutriments': <String, dynamic>{},
    }), isNull);
  });""",
    """  test('food without a nutrition panel stays visible but unknown', () {
    final food = CatalogFood.fromOpenFoodFacts({
      'product_name': 'Unknown',
      'nutriments': <String, dynamic>{},
    });
    expect(food?.name, 'Unknown');
    expect(food?.kcal100g, isNull);
    expect(food?.protein100g, isNull);
  });""")
