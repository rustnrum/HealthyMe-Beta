import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bloodwork_result.dart';
import '../models/connection_models.dart';
import '../models/health_data.dart';
import '../models/user_profile.dart';

class BootstrapData {
  final UserProfile profile;
  final HealthDataState healthData;
  final List<BloodworkResult> labs;
  final ConnectionsState connections;

  const BootstrapData({
    required this.profile,
    required this.healthData,
    required this.labs,
    required this.connections,
  });
}

final bootstrapDataProvider = Provider<BootstrapData>(
  (ref) => throw UnimplementedError('BootstrapData must be overridden in main.'),
);

class StorageService {
  static const _profileKey = 'hm_profile_v02';
  static const _healthKey = 'hm_health_v02';
  static const _labsKey = 'hm_labs_v02';
  static const _connectionsKey = 'hm_connections_v02';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<BootstrapData> loadBootstrapData() async {
    final profile = _decodeObject(
      await _prefs.getString(_profileKey),
      UserProfile.fromJson,
      const UserProfile(),
    );
    final health = _decodeObject(
      await _prefs.getString(_healthKey),
      HealthDataState.fromJson,
      const HealthDataState(),
    );
    final connections = _decodeObject(
      await _prefs.getString(_connectionsKey),
      ConnectionsState.fromJson,
      const ConnectionsState(),
    );

    final rawLabs = await _prefs.getString(_labsKey);
    var labs = <BloodworkResult>[];
    if (rawLabs != null) {
      try {
        final decoded = jsonDecode(rawLabs) as List<dynamic>;
        labs = decoded
            .whereType<Map<String, dynamic>>()
            .map(BloodworkResult.fromJson)
            .toList();
      } catch (_) {
        labs = <BloodworkResult>[];
      }
    }

    return BootstrapData(
      profile: profile,
      healthData: health,
      labs: labs,
      connections: connections,
    );
  }

  T _decodeObject<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
    T fallback,
  ) {
    if (raw == null) return fallback;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return fallback;
    }
  }

  Future<void> saveProfile(UserProfile profile) {
    return _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<void> saveHealthData(HealthDataState data) {
    return _prefs.setString(_healthKey, jsonEncode(data.toJson()));
  }

  Future<void> saveLabs(List<BloodworkResult> labs) {
    return _prefs.setString(
      _labsKey,
      jsonEncode(labs.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveConnections(ConnectionsState connections) {
    return _prefs.setString(
      _connectionsKey,
      jsonEncode(connections.toJson()),
    );
  }
}
