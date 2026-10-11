import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/food_catalog_service.dart';
import 'package:healthy_me/state/diet_log_state.dart';

void main() {
  test('real per-100g values scale with eaten grams, never invent missing nutrients', () {
    final product = CatalogFood.fromOpenFoodFacts({
      'code': '12345678',
      'product_name': 'Plain test yogurt',
      'brands': 'Example',
      'nutriments': {
        'energy-kcal_100g': 70,
        'proteins_100g': 10,
        'carbohydrates_100g': 4,
        'fat_100g': 1,
      },
    });
    expect(product, isNotNull);
    expect(product!.scaled(product.kcal100g, 150), 105);
    expect(product.scaled(product.protein100g, 150), 15);
    expect(product.scaled(product.fiber100g, 150), isNull);
  });

  test('food without a nutrition panel stays visible but unknown', () {
    final food = CatalogFood.fromOpenFoodFacts({
      'product_name': 'Unknown',
      'nutriments': <String, dynamic>{},
    });
    expect(food?.name, 'Unknown');
    expect(food?.kcal100g, isNull);
    expect(food?.protein100g, isNull);
  });

  test('product source, photo and nutrients survive saved food roundtrip and repeat', () {
    final original = FoodLogEntry(
      id: '1', eatenAt: DateTime(2026, 10, 11, 12),
      slot: 'Lunch', name: 'Yogurt', portion: '150 g',
      calories: 105, protein: 15, sourceName: 'Open Food Facts',
      sourceId: '12345678', imageUrl: 'https://example.org/photo.jpg');
    final restored = FoodLogEntry.fromJson(original.toJson());
    expect(restored.sourceName, 'Open Food Facts');
    expect(restored.sourceId, '12345678');
    expect(restored.imageUrl, 'https://example.org/photo.jpg');
    final repeated = restored.repeated('2', DateTime(2026, 10, 12), 'Dinner');
    expect(repeated.slot, 'Dinner');
    expect(repeated.sourceName, 'Open Food Facts');
    expect(repeated.calories, 105);
    expect(repeated.fiber, isNull);
  });

  test('old saved meals without new fields remain readable', () {
    final restored = FoodLogEntry.fromJson({
      'id': 'legacy',
      'eatenAt': '2026-10-10T12:00:00.000',
      'slot': 'Lunch',
      'name': 'Sandwich',
    });
    expect(restored.sourceName, 'Manual');
    expect(restored.sourceId, '');
  });
}
