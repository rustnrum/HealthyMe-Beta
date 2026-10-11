import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/food_catalog_service.dart';
import 'package:healthy_me/state/diet_log_state.dart';

void main() {
  test('real label serving grams enables one-tap portions', () {
    final food = CatalogFood.fromOpenFoodFacts({
      'code': '0123456789012', 'product_name': 'Plain Greek Yogurt',
      'brands': 'Test', 'serving_size': '3/4 cup (170 g)',
      'nutriments': {
        'energy-kcal_100g': 60, 'proteins_100g': 10,
        'carbohydrates_100g': 4, 'fat_100g': 0,
      },
    });
    expect(food, isNotNull);
    expect(food!.servingGrams, 170);
    expect(food.scaled(food.kcal100g, 170), 102);
    expect(food.scaled(food.protein100g, 85), 8.5);
  });

  test('ml serving is not made up as grams, unknown macros stay unknown', () {
    final drink = CatalogFood.fromOpenFoodFacts({
      'code': '0123456789012', 'product_name': 'Fruit drink',
      'serving_size': '250 ml',
      'nutriments': {'energy-kcal_100g': 45},
    });
    expect(drink, isNotNull);
    expect(drink!.servingGrams, isNull);
    expect(drink.scaled(drink.protein100g, 100), isNull);
  });

  test('products with missing nutrient values can still be identified', () {
    final food = CatalogFood.fromOpenFoodFacts({
      'code': '0123456789012', 'product_name': 'New packaged food',
    });
    expect(food?.name, 'New packaged food');
    expect(food?.kcal100g, isNull);
    expect(food?.imageUrl, isNull);
  });

  test('existing saved food JSON remains compatible and repeatable', () {
    final food = FoodLogEntry.fromJson({
      'id': '7', 'eatenAt': '2026-10-11T12:00:00.000',
      'slot': 'Lunch', 'name': 'Yogurt', 'portion': '170 g',
      'calories': 102, 'protein': 17,
    });
    final repeated = food.repeated('8', DateTime(2026, 10, 12), 'Breakfast');
    expect(repeated.calories, 102);
    expect(repeated.protein, 17);
    expect(repeated.slot, 'Breakfast');
  });

  test('barcode uses real on-device camera, not typed-only workflow', () {
    final scanner = File('lib/screens/diet/food_barcode_scanner_screen.dart')
        .readAsStringSync();
    final catalog = File('lib/screens/diet/food_catalog_screen.dart')
        .readAsStringSync();
    final home = File('lib/screens/diet/diet_home_screen.dart')
        .readAsStringSync();
    final manifest = File('native/android/AndroidManifest.xml')
        .readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(scanner, contains('MobileScanner(controller: _controller'));
    expect(scanner, contains(r"RegExp(r'^\d{8,14}$')"));
    expect(catalog, contains('lookupBarcode(code)'));
    expect(catalog, contains('FoodPortionSheet('));
    expect(home, contains('FoodCatalogScreen(barcodeMode: true)'));
    expect(manifest, contains('android.permission.CAMERA'));
    expect(pubspec, contains('mobile_scanner: ^7.4.2'));
  });
}
