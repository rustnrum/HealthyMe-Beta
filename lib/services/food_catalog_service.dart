import 'dart:convert';
import 'dart:io';

/// Real packaged-product information from Open Food Facts (ODbL). Community
/// nutrition and serving sizes can be incomplete or wrong. Never fill in
/// missing nutrient fields with invented numbers.
class CatalogFood {
  final String code;
  final String name;
  final String brand;
  final String? imageUrl;
  final String servingLabel;
  final double? kcal100g;
  final double? protein100g;
  final double? carbs100g;
  final double? fat100g;
  final double? fiber100g;

  const CatalogFood({required this.code, required this.name,
    required this.brand, required this.imageUrl, required this.servingLabel,
    this.kcal100g, this.protein100g, this.carbs100g, this.fat100g,
    this.fiber100g});

  /// Serving is only preselected when the label explicitly provides grams.
  /// Do not equate ml with g; density isn't always 1.
  double? get servingGrams {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*g\b', caseSensitive: false)
        .firstMatch(servingLabel);
    final amount = double.tryParse(match?.group(1)?.replaceAll(',', '.') ?? '');
    return amount != null && amount.isFinite && amount > 0 && amount <= 10000
        ? amount : null;
  }

  double? scaled(double? per100g, double grams) =>
      per100g == null ? null : per100g * grams / 100;

  static CatalogFood? fromOpenFoodFacts(Map<String, dynamic> json) {
    final name = (json['product_name'] ?? json['product_name_en'] ?? '')
        .toString().trim();
    if (name.isEmpty) return null;
    final raw = json['nutriments'];
    final nutrients = raw is Map
        ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    double? value(String field) {
      final rawValue = nutrients[field];
      final number = rawValue is num
          ? rawValue.toDouble() : double.tryParse(rawValue?.toString() ?? '');
      return number != null && number.isFinite && number >= 0 && number <= 2000
          ? number : null;
    }
    final rawImage = (json['image_front_small_url'] ??
        json['image_small_url'] ?? '').toString();
    final imageUri = Uri.tryParse(rawImage);
    return CatalogFood(
      code: (json['code'] ?? '').toString(),
      name: name,
      brand: (json['brands'] ?? '').toString().trim(),
      imageUrl: imageUri?.scheme == 'https' ? rawImage : null,
      servingLabel: (json['serving_size'] ?? '').toString().trim(),
      kcal100g: value('energy-kcal_100g'),
      protein100g: value('proteins_100g'),
      carbs100g: value('carbohydrates_100g'),
      fat100g: value('fat_100g'),
      fiber100g: value('fiber_100g'),
    );
  }
}

class FoodCatalogService {
  const FoodCatalogService();
  static const _fields = 'code,product_name,product_name_en,brands,'
      'serving_size,image_front_small_url,image_small_url,nutriments';

  // OFF v2 does not currently support generic text search. Trigger legacy
  // search ONLY on explicit user action, respecting 10 search req/min/IP.
  Future<List<CatalogFood>> search(String term) async {
    final query = term.trim();
    if (query.length < 2) {
      throw const FormatException('Enter at least 2 characters.');
    }
    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': query, 'search_simple': '1', 'action': 'process',
      'json': '1', 'page_size': '20', 'fields': _fields,
    });
    final data = await _get(uri);
    final items = data['products'];
    if (items is! List) return const [];
    return items.whereType<Map>()
        .map((entry) => CatalogFood.fromOpenFoodFacts(
            Map<String, dynamic>.from(entry)))
        .whereType<CatalogFood>().toList();
  }

  Future<List<CatalogFood>> lookupBarcode(String text) async {
    final code = text.trim();
    if (!RegExp(r'^\d{8,14}$').hasMatch(code)) {
      throw const FormatException('Barcode must contain 8–14 digits.');
    }
    final uri = Uri.https('world.openfoodfacts.org',
        '/api/v2/product/$code.json', {'fields': _fields});
    final data = await _get(uri);
    if (data['status'] != 1 || data['product'] is! Map) return const [];
    final product = CatalogFood.fromOpenFoodFacts(
        Map<String, dynamic>.from(data['product'] as Map));
    return product == null ? const [] : [product];
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 14));
      request.headers.set(HttpHeaders.userAgentHeader,
          'Salus/0.21.26 (https://rustnrum.com)');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 14));
      if (response.statusCode == 429) {
        throw const HttpException('Food database is rate-limiting requests.');
      }
      if (response.statusCode != 200) {
        throw HttpException('Food database returned ${response.statusCode}.');
      }
      final content = await response.transform(utf8.decoder).join()
          .timeout(const Duration(seconds: 14));
      final json = jsonDecode(content);
      if (json is! Map) {
        throw const FormatException('Invalid food database response.');
      }
      return Map<String, dynamic>.from(json);
    } finally {
      client.close(force: true);
    }
  }
}
