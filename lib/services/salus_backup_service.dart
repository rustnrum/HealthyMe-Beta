import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';
import 'storage_service.dart';

/// Backup format v1: app state (SharedPreferencesAsync) plus classic preference
/// histories. Native SAF bridge performs password-derived AES-256-GCM.
/// OAuth credentials / secure storage are never backed up.
class SalusBackupService {
  static const channel = MethodChannel('com.rustnrum.healthyme/backup');
  static const format = 'salus-encrypted-data-v1';
  const SalusBackupService();

  static bool includedKey(String key) =>
      (key.startsWith('salus_') || key.startsWith('healthy_me_')) &&
      !RegExp(r'(token|secret|password|oauth|auth_code|private_key|credential|api_key)',
          caseSensitive: false).hasMatch(key);

  static Map<String, dynamic>? encodePreference(Object? value) {
    if (value is String) return {'type': 'string', 'value': value};
    if (value is bool) return {'type': 'bool', 'value': value};
    if (value is int) return {'type': 'int', 'value': value};
    if (value is double && value.isFinite) return {'type': 'double', 'value': value};
    if (value is List<String>) return {'type': 'strings', 'value': value};
    return null;
  }

  static bool validPreference(Object? entry) {
    if (entry is! Map) return false;
    final type = entry['type'];
    final value = entry['value'];
    return switch(type) {
      'string' => value is String,
      'bool' => value is bool,
      'int' => value is int,
      'double' => value is num && value.isFinite,
      'strings' => value is List && value.every((e) => e is String),
      _ => false,
    };
  }

  Future<String> buildBackupJson() async {
    final state = await StorageService().load();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final entries = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (!includedKey(key)) continue;
      final typed = encodePreference(prefs.get(key));
      if (typed != null) entries[key] = typed;
    }
    return jsonEncode({
      'format': format,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'state': state.toJson(),
      'preferences': entries,
      'limitations': 'Account secrets and external Health Connect records are not included. Re-authorize providers after restore.',
    });
  }

  Future<void> exportEncrypted(String password) async {
    if (!Platform.isAndroid) throw StateError('Encrypted document backup requires Android.');
    if (password.length < 12) throw ArgumentError('Password must be 12+ characters.');
    final json = await buildBackupJson();
    // Private ephemeral cache file: encrypted by native bridge before SAF export.
    final temp = File('${Directory.systemTemp.path}/salus-export-${DateTime.now().microsecondsSinceEpoch}.json');
    await temp.writeAsString(json, flush: true);
    try {
      final now = DateTime.now();
      final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await channel.invokeMethod<String>('saveEncrypted', {
        'password': password, 'path': temp.path,
        'filename': 'Salus-Backup-$date.salus',
      });
    } finally { if (await temp.exists()) await temp.delete(); }
  }

  Future<int> restoreEncrypted(String password) async {
    if (!Platform.isAndroid) throw StateError('Encrypted restore requires Android.');
    if (password.length < 12) throw ArgumentError('Password must be 12+ characters.');
    final path = await channel.invokeMethod<String>('restoreEncrypted', {'password': password});
    if (path == null) throw StateError('No backup selected.');
    final temp = File(path);
    try {
      final obj = jsonDecode(await temp.readAsString());
      if (obj is! Map || obj['format'] != format || obj['state'] is! Map ||
          obj['preferences'] is! Map) {
        throw const FormatException('Not a compatible Salus backup.');
      }
      final stateMap = Map<String, dynamic>.from(obj['state'] as Map);
      final restored = HealthyMeState.fromJson(stateMap);
      // Validate every key and type before touching app storage.
      final incoming = Map<String, dynamic>.from(obj['preferences'] as Map);
      if (incoming.length > 1000) throw const FormatException('Too many preference records.');
      for (final entry in incoming.entries) {
        if (!includedKey(entry.key) || !validPreference(entry.value)) {
          throw const FormatException('Backup includes an unsupported preference record.');
        }
      }
      final prefs = await SharedPreferences.getInstance();
      for (final entry in incoming.entries) {
        final record = entry.value as Map;
        final value = record['value'];
        final ok = switch(record['type']) {
          'string' => await prefs.setString(entry.key, value as String),
          'bool' => await prefs.setBool(entry.key, value as bool),
          'int' => await prefs.setInt(entry.key, value as int),
          'double' => await prefs.setDouble(entry.key, (value as num).toDouble()),
          'strings' => await prefs.setStringList(entry.key, List<String>.from(value as List)),
          _ => false,
        };
        if (!ok) throw StateError('Failed to restore ${entry.key}.');
      }
      await StorageService().save(restored);
      return incoming.length + 1;
    } finally { if (await temp.exists()) await temp.delete(); }
  }
}
