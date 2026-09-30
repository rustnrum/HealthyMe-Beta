import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/health_connect_service.dart';
import 'app_state.dart';

class HealthSyncNotifier extends AsyncNotifier<void> {
  final _service = HealthConnectService();

  @override
  Future<void> build() async {}

  Future<bool> connectAndSync() async {
    state = const AsyncLoading();
    try {
      final auth = await _service.authorize();
      ref.read(appStateProvider.notifier).setHealthAuthorization(
            auth.authorized,
          );

      if (!auth.authorized) {
        throw StateError(
          'Health Connect permission was not granted.',
        );
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

  Future<void> sync() async {
    state = const AsyncLoading();
    try {
      await _sync();
      state = const AsyncData(null);
    } catch (error, stack) {
      ref.read(appStateProvider.notifier).setHealthError(error.toString());
      state = AsyncError(error, stack);
    }
  }

  Future<void> _sync({bool? historyOverride}) async {
    final app = ref.read(appStateProvider);
    final snapshot = await _service.sync(
      historicalAccess:
          historyOverride ?? app.health.historicalAccess,
      metricSources: app.metricSources,
    );
    ref.read(appStateProvider.notifier).setHealthSnapshot(snapshot);
  }

  Future<void> disconnect() async {
    state = const AsyncLoading();
    try {
      await _service.revoke();
      ref.read(appStateProvider.notifier).setHealthSnapshot(
            const HealthSnapshot(),
          );
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }
}

final healthSyncProvider =
    AsyncNotifierProvider<HealthSyncNotifier, void>(
  HealthSyncNotifier.new,
);
