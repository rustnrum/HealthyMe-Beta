import 'dart:convert';
import 'dart:io';

/// Product data from Open Food Facts. Community-supplied values need user
/// confirmation against a package label. Missing nutrients remain null.
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

  const CatalogFood({
    required this.code,
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.servingLabel,
    this.kcal100g,
    this.protein100g,
    this.carbs100g,
    this.fat100g,
    this.fiber100g,
  });

  double? scaled(double? per100g, double grams) =>
      per100g == null ? null : per100g * grams / 100;

  static CatalogFood? fromOpenFoodFacts(Map<String, dynamic> json) {
    final name = (json['product_name'] ?? json['product_name_en'] ?? '')
        .toString().trim();
    if (name.isEmpty) return null;
    final raw = json['nutriments'];
    if (raw is! Map) return null;
    final nutrients = Map<String, dynamic>.from(raw);
    double? value(String field) {
      final rawValue = nutrients[field];
      final number = rawValue is num
          ? rawValue.toDouble()
          : double.tryParse(rawValue?.toString() ?? '');
      return number != null && number.isFinite && number >= 0 && number <= 2000
          ? number : null;
    }

    final kcal = value('energy-kcal_100g');
    final protein = value('proteins_100g');
    final carbs = value('carbohydrates_100g');
    final fat = value('fat_100g');
    final fiber = value('fiber_100g');
    if ([kcal, protein, carbs, fat, fiber].every((v) => v == null)) {
      return null;
    }
    final rawImage = (json['image_front_small_url'] ??
        json['image_small_url'] ?? '').toString();
    final imageUri = Uri.tryParse(rawImage);
    return CatalogFood(
      code: (json['code'] ?? '').toString(),
      name: name,
      brand: (json['brands'] ?? '').toString().trim(),
      imageUrl: imageUri?.scheme == 'https' ? rawImage : null,
      servingLabel: (json['serving_size'] ?? '').toString(),
      kcal100g: kcal,
      protein100g: protein,
      carbs100g: carbs,
      fat100g: fat,
      fiber100g: fiber,
    );
  }
}

class FoodCatalogService {
  const FoodCatalogService();

  // Plain text search belongs to v1; OFF v2 full-text search is unsupported.
  // Searches execute only on button press, respecting its 10/min/IP limit.
  Future<List<CatalogFood>> search(String term) async {
    final query = term.trim();
    if (query.length < 2) throw const FormatException('Enter at least 2 characters.');
    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '15',
      'fields': 'code,product_name,product_name_en,brands,serving_size,'
          'image_front_small_url,image_small_url,nutriments',
    });
    final data = await _get(uri);
    final items = data['products'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) =>
        CatalogFood.fromOpenFoodFacts(Map<String, dynamic>.from(e)))
        .whereType<CatalogFood>().toList();
  }

  Future<List<CatalogFood>> lookupBarcode(String text) async {
    final code = text.trim();
    if (!RegExp(r'^\d{8,14}$').hasMatch(code)) {
      throw const FormatException('Enter a barcode with 8–14 digits.');
    }
    final uri = Uri.https('world.openfoodfacts.org',
        '/api/v2/product/$code.json', {
      'fields': 'code,product_name,product_name_en,brands,serving_size,'
          'image_front_small_url,image_small_url,nutriments',
    });
    final data = await _get(uri);
    if (data['status'] != 1 || data['product'] is! Map) return const [];
    final food = CatalogFood.fromOpenFoodFacts(
        Map<String, dynamic>.from(data['product'] as Map));
    return food == null ? const [] : [food];
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 9);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.userAgentHeader,
          'Salus/0.21.22 (https://rustnrum.com)');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode == 429) {
        throw const HttpException('Food database is rate-limiting requests. Try later.');
      }
      if (response.statusCode != 200) {
        throw HttpException('Food database returned ${response.statusCode}.');
      }
      final content = await response.transform(utf8.decoder).join()
          .timeout(const Duration(seconds: 12));
      final json = jsonDecode(content);
      if (json is! Map) throw const FormatException('Invalid food database response.');
      return Map<String, dynamic>.from(json);
    } finally {
      client.close(force: true);
    }
  }
}
