import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Broad local profile catalog is unique and honest about missing drivers', () {
    final decoded = jsonDecode(File('assets/protocols/registry.json').readAsStringSync()) as Map<String, dynamic>;
    final packs = (decoded['packs'] as List).cast<Map<String, dynamic>>();
    expect(packs.length, greaterThanOrEqualTo(20));
    final ids = packs.map((e) => e['id'] as String).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids, contains('cmf-watch-pro-family'));
    expect(ids, contains('banglejs-family'));
    expect(ids, contains('pinetime-family'));
    for (final pack in packs) {
      expect(pack['builtInReader'], false);
      expect(pack['capabilities'], isEmpty);
    }
  });

  test('Auto discovery links a saved watch to its direct notification switch', () {
    final source = File('lib/screens/auto_discovery_screen.dart').readAsStringSync();
    expect(source, contains("'/watch-device', arguments: device.id"));
    expect(source, contains('Watch notification switch'));
    expect(source, contains('Garmin GFDI writer installed; delivery unverified'));
    expect(source, contains('Local IDO writer installed; delivery unverified'));
    expect(source, contains('Auto discovery'));
  });
}
