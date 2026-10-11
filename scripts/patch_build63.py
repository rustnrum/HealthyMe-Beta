"""Build 63: selected-device Steps refresh and honest Garmin HRV display.

Preserve Garmin notification transport, signing, package name, and existing
HealthSnapshot/direct sample storage. Idempotent after source is committed.
"""
from pathlib import Path


def replace(path: str, old: str, new: str) -> None:
    file = Path(path)
    value = file.read_text(encoding='utf-8')
    if new in value:
        return
    n = value.count(old)
    if n != 1:
        raise RuntimeError(f'{path}: expected 1 old anchor, found {n}: {old[:95]!r}')
    file.write_text(value.replace(old, new, 1), encoding='utf-8')

sync='lib/state/health_sync_provider.dart'
replace(sync,
'''  BleDeviceCandidate _candidate(SavedDirectDevice device) =>''',
'''  /// Unlike the broad background sync, this is the exact selected BLE Steps
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

  BleDeviceCandidate _candidate(SavedDirectDevice device) =>''')
replace(sync,
'''    final snapshot = app.health.authorized
        ? await _service.sync(''',
'''    final samples = await _directService.loadSamples();
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
        ? await _service.sync(''')
replace(sync,
'''        : app.health;
    final samples = await _directService.loadSamples();
    final merged = _directService.mergeIntoSnapshot(''',
'''        : directSnapshot;
    final merged = _directService.mergeIntoSnapshot(''')

activity='lib/screens/activity_screen.dart'
replace(activity,
'''class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String _range = 'Day';''',
'''class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String _range = 'Day';
  bool _refreshingSteps = false;

  Future<void> _refreshSteps() async {
    if (_refreshingSteps) return;
    setState(() => _refreshingSteps = true);
    try {
      final app = ref.read(appStateProvider);
      final route = app.metricSources['Steps'];
      final selected = route != null && route != 'Auto'
          ? route : app.health.resolvedSources['Steps'];
      String result;
      if (selected?.startsWith('ble:') == true) {
        result = await ref.read(healthSyncProvider.notifier)
            .refreshSelectedDirectSteps();
      } else {
        await ref.read(healthSyncProvider.notifier).sync();
        result = ref.read(healthSyncProvider).hasError
            ? 'Steps sync failed. Check Connections.'
            : 'Health Connect Steps sync completed. Check the source timestamp.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), duration: const Duration(seconds: 6)),
      );
    } finally {
      if (mounted) setState(() => _refreshingSteps = false);
    }
  }''')
replace(activity,
'''            icon: syncState.isLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            onPressed: syncState.isLoading ? null : () =>
                ref.read(healthSyncProvider.notifier).sync(forceDirect: true),''',
'''            icon: syncState.isLoading || _refreshingSteps
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            onPressed: syncState.isLoading || _refreshingSteps
                ? null : _refreshSteps,''')

# The previous experimental Garmin R-R estimates remain available but should
# not dominate the HRV screen or masquerade as an overnight trend.
metric='lib/screens/metric_detail_screen.dart'
replace(metric,
'''              if (widget.metric == 'HRV' &&
                  snapshot.data?.excludedGarminHrv.isNotEmpty == true) ...[
                const Text('Previous short Garmin Bluetooth HRV estimates',
                    style: TextStyle(color: AppTheme.amber,
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const Text('These experimental values came from brief R–R samples, '
                    'not verified overnight HRV. They are preserved below for '
                    'reference but excluded from the graph, statistics and Recovery.',
                    style: TextStyle(color: AppTheme.textSecondary,
                        fontSize: 12.5)),
                for (final entry in snapshot.data!.excludedGarminHrv.reversed.take(5))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${entry.value.toStringAsFixed(1)} ms · '
                        '${_time(entry.capturedAt)} · ${entry.deviceName}',
                        style: const TextStyle(color: AppTheme.textMuted,
                            fontSize: 12)),
                  ),
                const SizedBox(height: 16),
              ],''',
'''              if (widget.metric == 'HRV' && sources.isEmpty) ...[
                const Text('No validated HRV available yet',
                    style: TextStyle(color: AppTheme.amber,
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                    'The vívoactive 6 Bluetooth stream does not supply a '
                    'verified overnight HRV average through this Salus reader. '
                    'Your previous brief R–R estimates cannot establish a '
                    'reliable HRV baseline. Recovery will exclude them. '
                    'A source that provides timestamped RMSSD records is needed.',
                    style: TextStyle(color: AppTheme.textSecondary,
                        fontSize: 12.5)),
                const SizedBox(height: 15),
              ],
              if (widget.metric == 'HRV' &&
                  snapshot.data?.excludedGarminHrv.isNotEmpty == true) ...[
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Unverified old Garmin HRV samples',
                      style: TextStyle(color: AppTheme.textSecondary,
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Preserved, not included in Recovery or charts',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  children: [
                    for (final entry in snapshot.data!.excludedGarminHrv.reversed.take(20))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('${entry.value.toStringAsFixed(1)} ms · '
                              '${_time(entry.capturedAt)} · ${entry.deviceName}',
                              style: const TextStyle(color: AppTheme.textMuted,
                                  fontSize: 12)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],''')

# Don't advertise unavailable validated Garmin HRV just because it has an
# R-R transport service. Preserve the full source identity and other metrics.
ble='lib/services/ble_protocol_profiles.dart'
replace(ble,
'''      capabilities: [
        'Steps',
        'Heart rate',
        'HRV',
        'SpO2',''',
'''      capabilities: [
        'Steps',
        'Heart rate',
        'SpO2',''')
connections='lib/screens/connections_screen.dart'
replace(connections,
'''    final capabilities = device.capabilities
        .where((item) => item != 'Raw motion' && item != 'Device information')
        .toList();''',
'''    final capabilities = device.capabilities
        .where((item) => item != 'Raw motion' && item != 'Device information' &&
            !(item == 'HRV' && (device.protocolId ?? '').contains('garmin')))
        .toList();''')

replace('pubspec.yaml', 'version: 0.21.24+62', 'version: 0.21.25+63')
print('Build 63: Activity refreshes selected Steps device; Garmin HRV remains unverified.')
