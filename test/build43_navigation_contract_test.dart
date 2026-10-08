import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/widgets/device_image.dart';

void main() {
  test('Today vital tiles open their own routes instead of generic Trends', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    final app = File('lib/app.dart').readAsStringSync();
    for (final name in [
      '/metric-hrv', '/metric-resting-heart-rate',
      '/metric-respiratory-rate', '/spo2-history',
    ]) {
      expect(home, contains("pushNamed('$name')"));
      expect(app, contains("'$name':"));
    }
    expect(home, contains('SalusDeviceBatteryIndicator('));
    expect(home, contains("pushNamed('/recovery')"));
  });

  test('Health has functional chart, lab and device destinations', () {
    final health = File('lib/screens/health/health_home_screen.dart').readAsStringSync();
    final vitals = File('lib/screens/health/health_vitals_screen.dart').readAsStringSync();
    expect(health, contains("pushNamed('/labs')"));
    expect(health, contains("'/metric-hrv'"));
    expect(vitals, contains('onTap:'));
    expect(vitals, contains('/metric-'));
  });

  test('Diet placeholders were replaced by editable persisted records', () {
    final diet = File('lib/screens/diet/diet_home_screen.dart').readAsStringSync();
    final meals = File('lib/screens/diet/diet_menu_screen.dart').readAsStringSync();
    final groceries = File('lib/screens/diet/grocery_list_screen.dart').readAsStringSync();
    expect(diet, contains('showFoodEntryDialog'));
    expect(meals, contains('repeatFood('));
    expect(groceries, contains('toggleGrocery('));
    expect(diet, isNot(contains('Photo, barcode, search, describe or voice')));
  });

  test('New device icons match category, not proprietary brand', () {
    expect(DeviceImage.imageFor('Smart ring'), 'ring');
    expect(DeviceImage.imageFor('Watch / band'), 'band');
    expect(DeviceImage.imageFor('Smart watch'), 'watch');
    expect(DeviceImage.imageFor('Bluetooth Scale'), 'scale');
    expect(DeviceImage.imageFor('Blood pressure monitor'), 'bp');
  });

  test('illustration assets and gallery entry point are in the overlay', () {
    expect(File('assets/devices/ring.png').existsSync(), isTrue);
    expect(File('assets/devices/watch.png').existsSync(), isTrue);
    expect(File('assets/illustrations/body_front_back.webp').existsSync(), isTrue);
    final more = File('lib/screens/more_screen.dart').readAsStringSync();
    expect(more, contains('/body-visual'));
    expect(more, contains('/device-gallery'));
  });
}
