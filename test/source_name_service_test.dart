import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/source_name_service.dart';

void main() {
  test('normalizes Samsung package id', () {
    expect(
      SourceNameService.friendly('com.sec.android.app.shealth'),
      'Samsung Health',
    );
  });

  test('normalizes Android phone-origin package id', () {
    expect(
      SourceNameService.friendly('com.android.healthconnect.phone.j8fd1ebc'),
      'Your phone',
    );
  });

  test('normalizes actual Health Connect package id', () {
    expect(
      SourceNameService.friendly('com.google.android.apps.healthdata'),
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

  test('recognizes QRing package id for display only', () {
    expect(SourceNameService.friendly('com.app.cq.ring'), 'QRing');
  });

  test('recognizes iMoni package id for display only', () {
    expect(SourceNameService.friendly('com.xs.imoni'), 'iMoni');
  });

  test('stable source key prefers sourceId over sourceName', () {
    expect(
      SourceNameService.key(
        sourceId: 'com.app.cq.ring',
        sourceName: 'QRing',
      ),
      'com.app.cq.ring',
    );
  });

  test('source matching accepts package id or display name', () {
    expect(
      SourceNameService.pointMatches(
        selected: 'QRing',
        sourceId: 'com.app.cq.ring',
        sourceName: 'QRing',
      ),
      isTrue,
    );
  });
}
