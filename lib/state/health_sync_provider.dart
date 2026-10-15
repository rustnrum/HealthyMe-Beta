import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/health_connect_service.dart';
import 'app_state.dart';

/// Health Connect is the only live sensor-data import path in Salus.
/// Existing workout, nutrition, lab, and profile storage remains untouched.
class HealthSyncNotifier extends AsyncNotifier<void> {
  final HealthConnectService _service = HealthConnectService();

  @override
  Future<void> build() async {}

  Future<bool> connectAndSync() async {
    state = const AsyncLoading();
    try {
      final auth = await _service.authorize();
      ref.read(appStateProvider.notifier).setHealthAuthorization(auth.authorized);
      if (!auth.authorized) {
        throw StateError('Health Connect permission was not granted.');
      }
      await _sync(historyOverride: auth.history);
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      ref.read(appStateProvider.notifier).setHealthError(error.toString());
      state = AsyncError(error, stack);
      return false;
    }
  }

  Future<void> sync({bool forceDirect = false}) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await _sync();
      state = const AsyncData(null);
    } catch (error, stack) {
      ref.read(appStateProvider.notifier).setHealthError(error.toString());
      state = AsyncError(error, stack);
    }
  }

  Future<String> refreshSelectedDirectSteps() async {
    await sync();
    return state.hasError ? 'Health Connect sync failed. Check permissions.'
        : 'Health Connect steps synchronized.';
  }

  Future<String> refreshSelectedHrv() async {
    await sync();
    return state.hasError ? 'Health Connect sync failed. Check permissions.'
        : 'Health Connect HRV synchronized.';
  }

  Future<void> _sync({bool? historyOverride}) async {
    final app = ref.read(appStateProvider);
    // Drop historical transport selections; actual records are selected by
    // their Health Connect DataOrigin instead of by a hardware transport.
    final sources = Map<String, String>.from(app.metricSources);
    for (final entry in sources.entries.toList()) {
      if (entry.value.startsWith('ble:')) {
        sources.remove(entry.key);
        ref.read(appStateProvider.notifier).setMetricSource(entry.key, 'Auto');
      }
    }
    if (!app.health.authorized) {
      // Preserve authorization state and personal records while offline.
      return;
    }
    final HealthSnapshot snapshot = await _service.sync(
      historicalAccess: historyOverride ?? app.health.historicalAccess,
      metricSources: sources,
    );
    ref.read(appStateProvider.notifier).setHealthSnapshot(snapshot);
  }

  Future<void> disconnect() async {
    state = const AsyncLoading();
    try {
      await _service.revoke();
      ref.read(appStateProvider.notifier).setHealthSnapshot(const HealthSnapshot());
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }
}

final healthSyncProvider = AsyncNotifierProvider<HealthSyncNotifier, void>(
  HealthSyncNotifier.new,
);
