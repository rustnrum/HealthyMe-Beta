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
    Map<String, List<String>> mergeSourceLists(
      Map<String, List<String>> oldValues,
      Map<String, List<String>> newValues,
    ) {
      final result = <String, List<String>>{};
      for (final key in {...oldValues.keys, ...newValues.keys}) {
        final merged = <String>{
          ...?oldValues[key],
          ...?newValues[key],
        }.toList();
        result[key] = merged;
      }
      return result;
    }

    final previous = app.health;
    final lastSeen = <String, DateTime>{...previous.sourceLastSeen};
    for (final entry in snapshot.sourceLastSeen.entries) {
      final old = lastSeen[entry.key];
      if (old == null || entry.value.isAfter(old)) {
        lastSeen[entry.key] = entry.value;
      }
    }

    final merged = snapshot.copyWith(
      detectedSources: <String>{
        ...previous.detectedSources,
        ...snapshot.detectedSources,
      }.toList(),
      availableSources: mergeSourceLists(
        previous.availableSources,
        snapshot.availableSources,
      ),
      sourceLabels: {
        ...previous.sourceLabels,
        ...snapshot.sourceLabels,
      },
      sourceLastSeen: lastSeen,
    );
    ref.read(appStateProvider.notifier).setHealthSnapshot(merged);
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
