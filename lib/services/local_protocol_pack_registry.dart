import 'dart:convert';

import 'package:flutter/services.dart';

import 'ble_protocol_profiles.dart';

class LocalProtocolPackMatch {
  final String id;
  final String label;
  final String deviceKind;
  final List<String> capabilities;
  final bool builtInReader;
  final String note;

  const LocalProtocolPackMatch({
    required this.id,
    required this.label,
    required this.deviceKind,
    required this.capabilities,
    required this.builtInReader,
    required this.note,
  });
}

class _LocalProtocolPack {
  final String id;
  final String label;
  final String deviceKind;
  final Set<String> services;
  final Set<String> nameTokens;
  final List<String> capabilities;
  final bool builtInReader;
  final String note;

  const _LocalProtocolPack({
    required this.id,
    required this.label,
    required this.deviceKind,
    required this.services,
    required this.nameTokens,
    required this.capabilities,
    required this.builtInReader,
    required this.note,
  });
}

class LocalProtocolPackRegistry {
  final List<_LocalProtocolPack> _packs;

  const LocalProtocolPackRegistry._(this._packs);

  static Future<LocalProtocolPackRegistry>? _cached;

  static Future<LocalProtocolPackRegistry> load() =>
      _cached ??= _loadInternal();

  static Future<LocalProtocolPackRegistry> _loadInternal() async {
    final raw = await rootBundle.loadString('assets/protocols/registry.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final packs = <_LocalProtocolPack>[];

    for (final item in (decoded['packs'] as List<dynamic>? ?? const [])) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      packs.add(
        _LocalProtocolPack(
          id: map['id']?.toString() ?? '',
          label: map['label']?.toString() ?? 'Compatibility family',
          deviceKind: map['deviceKind']?.toString() ?? 'Bluetooth device',
          services: (map['services'] as List<dynamic>? ?? const [])
              .map((value) => BleProtocolProfiles.normalizeUuid(value.toString()))
              .toSet(),
          nameTokens: (map['nameTokens'] as List<dynamic>? ?? const [])
              .map((value) => value.toString().toLowerCase())
              .toSet(),
          capabilities: (map['capabilities'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(),
          builtInReader: map['builtInReader'] == true,
          note: map['note']?.toString() ?? '',
        ),
      );
    }

    return LocalProtocolPackRegistry._(
      packs.where((pack) => pack.id.isNotEmpty).toList(),
    );
  }

  LocalProtocolPackMatch? match({
    required String name,
    required Iterable<String> services,
  }) {
    final normalizedServices =
        services.map(BleProtocolProfiles.normalizeUuid).toSet();
    final tokens = name
        .trim()
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9áéíóúüñ]+'))
        .where((token) => token.isNotEmpty)
        .toSet();

    _LocalProtocolPack? best;
    var bestScore = 0;

    for (final pack in _packs) {
      var score = 0;
      if (pack.services.any(normalizedServices.contains)) score += 100;
      if (pack.nameTokens.any(tokens.contains)) score += 20;
      if (score > bestScore) {
        best = pack;
        bestScore = score;
      }
    }

    if (best == null || bestScore == 0) return null;
    return LocalProtocolPackMatch(
      id: best.id,
      label: best.label,
      deviceKind: best.deviceKind,
      capabilities: best.capabilities,
      builtInReader: best.builtInReader,
      note: best.note,
    );
  }
}
