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

  test('hides unknown long package ids behind readable label', () {
    expect(
      SourceNameService.friendly('com.vendor.internal.really.long.package.identifier'),
      'Connected health source',
    );
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
