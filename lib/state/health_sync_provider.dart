import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import '../services/ble_discovery_service.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../services/health_connect_service.dart';
import '../services/source_name_service.dart';
import 'app_state.dart';

class HealthSyncNotifier extends AsyncNotifier<void> {
  final _service = HealthConnectService();
  final _directService = DirectMetricService();
  final _savedDevices = DirectDeviceStore();
  final Map<String, DateTime> _lastDirectAttempt = {};

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

  Future<void> sync() async {
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

  BleDeviceCandidate _candidate(SavedDirectDevice device) =>
      BleDeviceCandidate(
        id: device.id,
        name: device.name,
        rssi: -127,
        advertisedServices: const [],
        capabilities: device.capabilities,
        protocolProfile: device.protocolLabel,
        protocolId: device.protocolId,
        protocolNote: null,
        deviceKind: device.deviceKind,
        manufacturerDataHex: '',
        bondState: device.bonded ? 'bonded' : device.pairState,
      );

  Future<List<SavedDirectDevice>> _refreshSavedDirectDevices() async {
    final devices = await _savedDevices.load();
    if (devices.isEmpty) return devices;
    // Never cause an unexpected Android permissions prompt on app resume.
    if (!await Permission.bluetoothConnect.isGranted ||
        !await Permission.bluetoothScan.isGranted) {
      return devices;
    }
    for (final device in devices) {
      // CPAP has a separate read-only pairing and history workflow. Never
      // hammer its secure therapy interface on the 5-minute app timer.
      if (device.protocolId == 'cpap-family') continue;
      final now = DateTime.now();
      final previous = _lastDirectAttempt[device.id];
      if (previous != null && now.difference(previous) <
          const Duration(minutes: 5)) continue;
      _lastDirectAttempt[device.id] = now;
      try {
        await _directService.readAndStore(
          _candidate(device),
          protocolId: device.protocolId,
        );
      } catch (_) {
        // Offline/low-battery devices do not block other devices or HC.
        // Existing timestamped data stays available with its true age.
      }
    }
    return devices;
  }

  Future<void> _sync({bool? historyOverride}) async {
    final app = ref.read(appStateProvider);
    final savedDevices = await _refreshSavedDirectDevices();
    final routedSources = Map<String, String>.from(app.metricSources);

    // Clean up legacy entries representing a transport, rather than a real
    // provider. Never discard a valid user-selected source just because it
    // did not submit a reading during this refresh.
    final invalidLegacy = routedSources.entries
        .where((entry) => SourceNameService.isTransportOnly(entry.value))
        .map((entry) => entry.key)
        .toList();
    for (final metric in invalidLegacy) {
      routedSources.remove(metric);
      ref.read(appStateProvider.notifier).setMetricSource(metric, 'Auto');
    }

    final snapshot = await _service.sync(
      historicalAccess: historyOverride ?? app.health.historicalAccess,
      metricSources: routedSources,
    );
    final samples = await _directService.loadSamples();
    final merged = _directService.mergeIntoSnapshot(
      snapshot,
      metricSources: routedSources,
      samples: samples,
      registeredDevices: savedDevices,
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

final healthSyncProvider = AsyncNotifierProvider<HealthSyncNotifier, void>(
  HealthSyncNotifier.new,
);
