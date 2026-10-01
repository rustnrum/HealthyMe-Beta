import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:healthy_me/services/health_connect_service.dart';

void main() {
  test('converts Health Connect meters to miles', () {
    final miles = HealthConnectService.distanceValueToMiles(
      1609.344,
      HealthDataUnit.METER,
    );
    expect(miles, closeTo(1.0, 0.0001));
  });

  test('leaves mile values unchanged', () {
    final miles = HealthConnectService.distanceValueToMiles(
      3.5,
      HealthDataUnit.MILE,
    );
    expect(miles, 3.5);
  });
}
