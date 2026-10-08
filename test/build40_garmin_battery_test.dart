import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/garmin_battery_service.dart';

void main() {
  test('hardware Battery must not be silently replaced by Garmin Body battery', () {
    expect(GarminBatteryService.validatedPercentage({
      'metrics': {'Body battery': 92},
    }), isNull);
  });

  test('hardware battery accepts only real and valid reported percentages', () {
    expect(GarminBatteryService.validatedPercentage({
      'metrics': {'Battery': 72},
    }), 72);
    expect(GarminBatteryService.validatedPercentage({
      'metrics': {'Battery': -2},
    }), isNull);
    expect(GarminBatteryService.validatedPercentage({
      'metrics': {'Battery': 101},
    }), isNull);
    expect(GarminBatteryService.validatedPercentage({
      'metrics': {'Battery': '82'},
    }), isNull);
  });
}
