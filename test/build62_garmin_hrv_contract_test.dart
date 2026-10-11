import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short Garmin R-R intervals are never presented as overnight HRV', () {
    final source = File('native/android/SalusProtocolReader.kt')
        .readAsStringSync();
    expect(source, contains('garminRrMs.isNotEmpty()'));
    expect(source, isNot(contains('sqrt(sumSquares / (garminRrMs.size - 1))')));
    expect(source, isNot(contains('metrics["HRV"] =')));
  });

  test('old data preserved but quarantined from active HRV history', () {
    final direct = File('lib/services/direct_metric_service.dart')
        .readAsStringSync();
    final history = File('lib/services/metric_history_service.dart')
        .readAsStringSync();
    expect(direct, contains('Unverified Garmin short HRV'));
    expect(direct, contains('clearHrv: excludeGarminHrv'));
    expect(history, contains('excludedGarminHrv: excludedGarmin'));
  });
}
