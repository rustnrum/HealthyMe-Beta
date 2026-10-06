import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/health_connect_service.dart';
import '../services/direct_metric_service.dart';
import '../services/source_name_service.dart';
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
    // HEALTHY_ME_SOURCE_HUB_ROUTE_SANITIZER_V010
    // Old betas allowed transport pseudo-sources to be saved as metric routes.
    // Convert those back to Automatic before querying provider-specific data.
    final routedSources = Map<String, String>.from(app.metricSources);
    final obsoleteRoutes = routedSources.entries
        .where((entry) => SourceNameService.isTransportOnly(entry.value))
        .map((entry) => entry.key)
        .toList();
    for (final metric in obsoleteRoutes) {
      routedSources.remove(metric);
      ref.read(appStateProvider.notifier).setMetricSource(metric, 'Auto');
    }

    // Drop a manual Health Connect route that is no longer one of the current
    // providers for that metric. Direct BLE routes are retained because their
    // samples live in Salus rather than Health Connect.
    final stalePreviousRoutes = routedSources.entries.where((entry) {
      if (entry.value.startsWith('ble:')) return false;
      final choices = app.health.availableSources[entry.key] ?? const <String>[];
      return choices.isNotEmpty &&
          !choices.any(
            (source) => SourceNameService.sameProvider(source, entry.value),
          );
    }).map((entry) => entry.key).toList();
    for (final metric in stalePreviousRoutes) {
      routedSources.remove(metric);
      ref.read(appStateProvider.notifier).setMetricSource(metric, 'Auto');
    }

    var snapshot = await _service.sync(
      historicalAccess:
          historyOverride ?? app.health.historicalAccess,
      metricSources: routedSources,
    );
    // SALUS_BUILD26_CURRENT_SOURCE_STATE
    // The old implementation unioned every provider ever seen into the next
    // snapshot. That is why removed QRing/Garmin app origins never disappeared.
    final directMetricService = DirectMetricService();
    final directSamples = await directMetricService.loadSamples();
    var merged = directMetricService.mergeIntoSnapshot(
      snapshot,
      metricSources: routedSources,
      samples: directSamples,
    );

    // If a provider vanished during this refresh, switch that metric back to
    // Automatic immediately and refresh once more so the visible value is not
    // left blank behind an obsolete manual route.
    final staleAfterRefresh = routedSources.entries.where((entry) {
      if (entry.value.startsWith('ble:')) return false;
      final choices = merged.availableSources[entry.key] ?? const <String>[];
      return !choices.any(
        (source) => SourceNameService.sameProvider(source, entry.value),
      );
    }).map((entry) => entry.key).toList();

    if (staleAfterRefresh.isNotEmpty) {
      for (final metric in staleAfterRefresh) {
        routedSources.remove(metric);
        ref.read(appStateProvider.notifier).setMetricSource(metric, 'Auto');
      }
      snapshot = await _service.sync(
        historicalAccess:
            historyOverride ?? app.health.historicalAccess,
        metricSources: routedSources,
      );
      merged = directMetricService.mergeIntoSnapshot(
        snapshot,
        metricSources: routedSources,
        samples: directSamples,
      );
    }

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
