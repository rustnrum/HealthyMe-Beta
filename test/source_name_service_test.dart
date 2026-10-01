import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/source_name_service.dart';

void main() {
  test('normalizes Samsung package id', () {
    expect(
      SourceNameService.friendly('com.sec.android.app.shealth'),
      'Samsung Health',
    );
  });

  test('normalizes Health Connect package id', () {
    expect(
      SourceNameService.friendly('com.android.healthconnect.phone.j8fd1ebc'),
      'Health Connect',
    );
  });

  test('unknown package ids become human readable and never expose com prefix', () {
    final label = SourceNameService.friendly('com.vendor.internal.health.client');
    expect(label, 'Vendor');
    expect(label.contains('com.'), isFalse);
  });

  test('deduplicates sources by friendly provider name', () {
    final values = SourceNameService.uniqueRawByFriendly([
      'Samsung Health',
      'com.sec.android.app.shealth',
      'Garmin Connect',
    ]);
    expect(values.length, 2);
  });
}
