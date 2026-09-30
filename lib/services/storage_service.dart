import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';

class StorageService {
  static const _key = 'healthy_me_state_v03';
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<HealthyMeState> load() async {
    final raw = await _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const HealthyMeState();

    try {
      return HealthyMeState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const HealthyMeState();
    }
  }

  Future<void> save(HealthyMeState state) {
    return _prefs.setString(_key, state.encode());
  }
}
