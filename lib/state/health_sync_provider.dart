import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import '../services/ble_discovery_service.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../services/garmin_battery_service.dart';
import '../services/health_connect_service.dart';
import '../services/source_name_service.dart';
import 'app_state.dart';

class HealthSyncNotifier extends AsyncNotifier<void> {
  final _service = HealthConnectService();
  final _directService = DirectMetricService();
  final _savedDevices = DirectDeviceStore();
  final _garminBattery = GarminBatteryService();
  final Map<String, DateTime> _lastBatteryAttempt = {};
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

  Future<void> sync({bool forceDirect = false}) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await _sync(forceDirect: forceDirect);
      state = const AsyncData(null);
    } catch (error, stack) {
      ref.read(appStateProvider.notifier).setHealthError(error.toString());
      state = AsyncError(error, stack);
    }
  }

  /// Unlike the broad background sync, this is the exact selected BLE Steps
  /// device path used by Connections. It does not wait for Health Connect or
  /// attempt to connect to the ring before updating the displayed total.
  /// Return a user-visible result; a completed BLE session is not necessarily
  /// a successful Steps read.
  Future<String> refreshSelectedDirectSteps() async {
    if (state.isLoading) {
      return 'Another health sync is in progress. Try again shortly.';
    }
    state = const AsyncLoading();
    try {
      final app = ref.read(appStateProvider);
      final configured = app.metricSources['Steps'];
      final source = configured != null && configured != 'Auto'
          ? configured : app.health.resolvedSources['Steps'];
      if (source == null || !source.startsWith('ble:')) {
        state = const AsyncData(null);
        return 'Steps is not using a direct Bluetooth device. Check its data source in Connections.';
      }
      final saved = await _savedDevices.load();
      SavedDirectDevice? selected;
      for (final device in saved) {
        if ('ble:${device.id}' == source) {
          selected = device;
          break;
        }
      }
      if (selected == null) {
        state = const AsyncData(null);
        return 'The selected Steps device is not saved. Check Connections.';
      }
      if (!await Permission.bluetoothConnect.isGranted ||
          !await Permission.bluetoothScan.isGranted) {
        state = const AsyncData(null);
        return 'Bluetooth permissions are missing. Check Android permissions for Salus.';
      }
      final reading = await _directService.readAndStore(
        _candidate(selected),
        protocolId: selected.protocolId,
        duration: const Duration(seconds: 23),
      );
      // Connections refreshes the snapshot directly; Activity must do the
      // same. Never make this dependent on a separate HC query succeeding.
      final stored = await _directService.loadSamples();
      final latest = ref.read(appStateProvider);
      final merged = _directService.mergeIntoSnapshot(
        latest.health,
        metricSources: latest.metricSources,
        samples: stored,
        registeredDevices: saved,
      );
      ref.read(appStateProvider.notifier).setHealthSnapshot(merged);
      state = const AsyncData(null);
      final steps = reading.metrics['Steps'];
      if (steps == null || !steps.isFinite || steps < 0) {
        return '${selected.name} connected but returned no new Steps total. ' 
            'The last saved reading was retained. ${reading.message}';
      }
      return '${selected.name}: received ${steps.round()} steps from the watch.';
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return 'Steps sync failed: $error';
    }
  }

  Future<String> refreshSelectedHrv() async {
    if (state.isLoading) return 'A health sync is already running. Try again shortly.';
    final app = ref.read(appStateProvider);
    final source = app.metricSources['HRV'];
    if (source == null || !source.startsWith('ble:')) {
      return 'The selected HRV provider is not a direct Bluetooth device.';
    }
    state = const AsyncLoading();
    try {
      final saved = await _savedDevices.load();
      SavedDirectDevice? selected;
      for (final device in saved) {
        if ('ble:${device.id}' == source) { selected = device; break; }
      }
      if (selected == null) {
        state = const AsyncData(null);
        return 'The selected HRV device is not saved in Connections.';
      }
      if (!await Permission.bluetoothConnect.isGranted ||
          !await Permission.bluetoothScan.isGranted) {
        state = const AsyncData(null);
        return 'Bluetooth permissions are missing for Salus.';
      }
      final reading = await _directService.readAndStore(
        _candidate(selected), protocolId: selected.protocolId,
        duration: const Duration(seconds: 30),
      );
      final stored = await _directService.loadSamples();
      final latest = ref.read(appStateProvider);
      final merged = _directService.mergeIntoSnapshot(latest.health,
        metricSources: latest.metricSources, samples: stored,
        registeredDevices: saved);
      ref.read(appStateProvider.notifier).setHealthSnapshot(merged);
      final qualified = stored.where((s) =>
          s.sourceId == source && s.metric == 'HRV').length;
      final indexed = stored.where((s) =>
          s.sourceId == source && s.metric == 'Ring HRV proxy').length;
      state = const AsyncData(null);
      return '${selected.name}: $qualified RMSSD records, $indexed firmware-index records saved. '
          'Reader: ${reading.reader}. ${reading.message} '
          'Diagnostics: ${reading.diagnostics}';
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return 'Selected HRV device refresh failed: $error';
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

  Future<List<SavedDirectDevice>> _refreshSavedDirectDevices({bool force = false}) async {
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
      if (!force && previous != null && now.difference(previous) <
          const Duration(minutes: 5)) continue;
      _lastDirectAttempt[device.id] = now;
      try {
        await _directService.readAndStore(
          _candidate(device),
          protocolId: device.protocolId,
        );
        // Only poll Garmin hardware battery automatically if a previous
        // user-requested check proved its standard GATT battery is readable.
        // Unsupported firmware should not suffer repeated extra BLE sessions.
        if ((device.protocolId ?? '').contains('garmin') &&
            await _garminBattery.knownStandardBattery(device.id)) {
          final last = _lastBatteryAttempt[device.id];
          if (last == null || now.difference(last) >=
              const Duration(minutes: 30)) {
            _lastBatteryAttempt[device.id] = now;
            await _garminBattery.check(device.id, device.name);
          }
        }
      } catch (_) {
        // Offline/low-battery devices do not block other devices or HC.
        // Existing timestamped data stays available with its true age.
      }
    }
    return devices;
  }

  Future<void> _sync({bool? historyOverride, bool forceDirect = false}) async {
    final app = ref.read(appStateProvider);
    final savedDevices = await _refreshSavedDirectDevices(force: forceDirect);
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

    // Salus direct BLE works independently of Health Connect authorization.
    // Do not block real Garmin step reads just because a third-party import
    // permission is off. Keep the last-known HC snapshot when disconnected.
    final samples = await _directService.loadSamples();
    // Commit the direct-device result BEFORE querying Health Connect.
    // An unrelated HC error must not hide fresh Garmin Steps.
    final directSnapshot = _directService.mergeIntoSnapshot(
      ref.read(appStateProvider).health,
      metricSources: routedSources,
      samples: samples,
      registeredDevices: savedDevices,
    );
    ref.read(appStateProvider.notifier).setHealthSnapshot(directSnapshot);
    final snapshot = app.health.authorized
        ? await _service.sync(
            historicalAccess: historyOverride ?? app.health.historicalAccess,
            metricSources: routedSources,
          )
        : directSnapshot;
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
