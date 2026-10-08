import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/local_device_driver.dart';
import 'package:healthy_me/widgets/device_battery_indicator.dart';
import 'package:flutter/material.dart';

void main() {
  test('all device kinds receive type-based icons without brand checks', () {
    expect(SalusDeviceBatteryIndicator.iconForKind('Ring'), Icons.radio_button_unchecked_rounded);
    expect(SalusDeviceBatteryIndicator.iconForKind('Smart ring'), Icons.radio_button_unchecked_rounded);
    expect(SalusDeviceBatteryIndicator.iconForKind('Watch / band'), Icons.watch_rounded);
    expect(SalusDeviceBatteryIndicator.iconForKind('Watch'), Icons.watch_rounded);
  });

  test('battery indicator has empty, quarter, half, three-quarter and full states', () {
    expect(SalusDeviceBatteryIndicator.iconForPercent(5), Icons.battery_alert_rounded);
    expect(SalusDeviceBatteryIndicator.iconForPercent(25), Icons.battery_1_bar_rounded);
    expect(SalusDeviceBatteryIndicator.iconForPercent(50), Icons.battery_3_bar_rounded);
    expect(SalusDeviceBatteryIndicator.iconForPercent(75), Icons.battery_5_bar_rounded);
    expect(SalusDeviceBatteryIndicator.iconForPercent(100), Icons.battery_full_rounded);
  });

  test('history screen is routed and does not generate synthetic observations', () {
    final routes = File('lib/app.dart').readAsStringSync();
    final source = File('lib/screens/spo2_history_screen.dart').readAsStringSync();
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(routes, contains("'/spo2-history'"));
    expect(home, contains("pushNamed('/spo2-history')"));
    expect(source, contains('SpO2HistoryService().load('));
    expect(source, contains('s.sourceId == selected'));
  });

  test('home battery chips render generic type and level indicators', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(home, contains('SalusDeviceBatteryIndicator('));
    expect(home, contains('deviceKind: item.device.deviceKind'));
    expect(home, contains('percentage: item.value'));
    expect(home, isNot(contains(r'${item.device.name}')));
  });

  test('all runtime direct reads pass through local driver dispatcher', () {
    final source = File('lib/services/direct_metric_service.dart').readAsStringSync();
    expect(source, contains('SalusLocalDeviceDrivers().read('));
    expect(source, contains('salus_direct_metric_samples_v1'));
  });

  test('native transport remains available for installed drivers', () {
    const drivers = SalusLocalDeviceDrivers();
    expect(drivers.match(name: 'A ring', protocolId: 'ring-uart-v1').status,
        SalusDriverStatus.ready);
  });
}
