import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/ble_protocol_profiles.dart';
import 'package:healthy_me/services/local_device_driver.dart';

void main() {
  test('source route opens auto discovery, advanced tools remain available', () {
    final source = File('lib/app.dart').readAsStringSync();
    final more = File('lib/screens/more_screen.dart').readAsStringSync();
    expect(source, contains("'/auto-discover': (_) => const AutoDiscoveryScreen()"));
    expect(source, contains("'/sources': (_) => const ConnectionsScreen()"));
    expect(source, contains("'/connections-advanced': (_) => const ConnectionsScreen()"));
    expect(more, contains('Automatic wearable discovery'));
    final gallery = File('lib/screens/device_gallery_screen.dart').readAsStringSync();
    expect(gallery, contains("pushNamed('/auto-discover')"));
  });

  test('discovery starts itself, inspects GATT, and only pairs on explicit add', () {
    final screen = File('lib/screens/auto_discovery_screen.dart')
        .readAsStringSync();
    expect(screen, contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(screen, contains('_discover();'));
    expect(screen, contains('final nearby = await _ble.scan('));
    expect(screen, contains('details = await _ble.inspect(entry.candidate)'));
    expect(screen, contains('await _ble.pair(entry.candidate)'));
    expect(screen, contains('onAdd: () => _add(item)'));
    expect(screen, contains('Unknown devices are shown'));
    expect(screen, contains('Direct notification writer:'));
    expect(screen, contains('Profile possibilities (not verified readings)')); 
  });

  test('name-free Bluetooth services identify standards, not invented brands', () {
    final report = BleProtocolProfiles.analyze(const ['180d', '180f']);
    expect(report.standardCapabilities, contains('Heart rate'));
    expect(report.standardCapabilities, contains('Battery'));
    expect(report.protocolProfile, isNull);
    expect(BleProtocolProfiles.analyze(const [], name: 'Mystery 123')
        .protocolProfile, isNull);
  });

  test('unrecognized device cannot claim a proprietary local reader', () {
    final decision = const SalusLocalDeviceDrivers().match(
      name: 'Mystery 123',
      protocolId: null,
    );
    expect(decision.status, SalusDriverStatus.unknown);
    expect(decision.canRead, isFalse);
  });
}
