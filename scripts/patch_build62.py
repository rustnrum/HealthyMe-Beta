"""Build 62: do not treat unverified short Garmin R-R traces as overnight RMSSD.

Retain the raw previous short-estimate history under a separate experimental
metric, but exclude it from validated HRV, overnight comparisons, and Recovery.
Preserve notification transport, stored app data, signing, and other metrics.
Idempotent across repeated CI builds.
"""
from pathlib import Path


def replace(path: str, old: str, new: str):
    p = Path(path)
    src = p.read_text(encoding="utf-8")
    if new in src:
        return
    n = src.count(old)
    if n != 1:
        raise RuntimeError(f"{path}: expected one patch anchor, found {n}: {old[:110]!r}")
    p.write_text(src.replace(old, new, 1), encoding="utf-8")


native = "native/android/SalusProtocolReader.kt"
replace(native, "import kotlin.math.sqrt\n", "// Short Garmin R-R telemetry is not a validated overnight RMSSD measurement.\n")
replace(native,
'''            if (garminRrMs.size >= 3 && !metrics.containsKey("HRV")) {
                var sumSquares = 0.0
                for (index in 1 until garminRrMs.size) {
                    val delta = garminRrMs[index] - garminRrMs[index - 1]
                    sumSquares += delta * delta
                }
                metrics["HRV"] =
                    sqrt(sumSquares / (garminRrMs.size - 1))
            }''',
'''            // A 14-second BLE poll with only a few R-R intervals cannot be
            // treated as Garmin's overnight HRV Status / validated RMSSD.
            // Keep the transport observations for diagnostics, not Recovery.
            if (mode == "garmin" && garminRrMs.isNotEmpty()) {
                notes.add("Garmin supplied ${garminRrMs.size} R-R intervals during a brief poll. Short HRV estimate excluded from Recovery.")
            }''')

model = "lib/models/models.dart"
replace(model,
'''    double? hrvMs,
    List<WeightPoint>? weightHistory,''',
'''    double? hrvMs,
    bool clearHrv = false,
    List<WeightPoint>? weightHistory,''')
replace(model,
'''      hrvMs: hrvMs ?? this.hrvMs,
      weightHistory:''',
'''      hrvMs: clearHrv ? null : (hrvMs ?? this.hrvMs),
      weightHistory:''')

direct = "lib/services/direct_metric_service.dart"
replace(direct,
'''  // NEVER change this key: existing user history must survive upgrades.
  static const _storageKey = 'salus_direct_metric_samples_v1';''',
'''  // NEVER change this key: existing user history must survive upgrades.
  static const _storageKey = 'salus_direct_metric_samples_v1';
  static const experimentalGarminHrv = 'Unverified Garmin short HRV';

  // Old Garmin BLE HRV was computed from a handful of R-R intervals. Preserve
  // those records for diagnostics, but never use them as validated RMSSD.
  static bool _looksLikeGarmin(String name) {
    final n = name.toLowerCase();
    return n.contains('garmin') || n.contains('voactive') ||
        n.contains('forerunner') || n.contains('fenix') ||
        n.contains('fēnix') || n.contains('venu') ||
        n.contains('instinct') || n.contains('epix');
  }

  static bool isLegacyGarminHrv(DirectMetricSample s) =>
      s.metric == 'HRV' && s.sourceId.startsWith('ble:') &&
      _looksLikeGarmin(s.deviceName);

  static bool _garminBleSource(
    String? source,
    List<DirectMetricSample> samples,
    List<SavedDirectDevice> devices,
    Map<String, String> labels,
  ) {
    if (source == null || !source.startsWith('ble:')) return false;
    if (_looksLikeGarmin(labels[source] ?? '')) return true;
    if (devices.any((d) => 'ble:${d.id}' == source &&
        (d.protocolId ?? '').contains('garmin'))) return true;
    return samples.any((s) => s.sourceId == source &&
        _looksLikeGarmin(s.deviceName));
  }''')
replace(direct,
'''      final values = decoded.whereType<Map<String, dynamic>>()
          .map(DirectMetricSample.fromJson)
          .where((s) => s.sourceId.isNotEmpty && s.metric.isNotEmpty && s.value.isFinite)''',
'''      final values = decoded.whereType<Map<String, dynamic>>()
          .map(DirectMetricSample.fromJson)
          .map((s) => isLegacyGarminHrv(s)
              ? DirectMetricSample(
                  sourceId: s.sourceId, deviceId: s.deviceId,
                  deviceName: s.deviceName, metric: experimentalGarminHrv,
                  value: s.value, unit: s.unit, capturedAt: s.capturedAt)
              : s)
          .where((s) => s.sourceId.isNotEmpty && s.metric.isNotEmpty && s.value.isFinite)''')
replace(direct,
'''        if (metric.isEmpty || metric == 'Raw motion' ||
            metric == 'Battery' || metric == 'Device information') continue;''',
'''        if (metric.isEmpty || metric == 'Raw motion' ||
            metric == 'Battery' || metric == 'Device information' ||
            (metric == 'HRV' && (device.protocolId ?? '').contains('garmin'))) continue;''')
replace(direct,
'''    final direct = samples.where((s) => s.sourceId.startsWith('ble:')).toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));''',
'''    final direct = samples.where((s) =>
        s.sourceId.startsWith('ble:') && !isLegacyGarminHrv(s)).toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    // Previously cached BLE Garmin HRV must not survive as a current value
    // or baseline just because a newly validated value wasn't available.
    final excludeGarminHrv = _garminBleSource(
          metricSources['HRV'], samples, registeredDevices, base.sourceLabels) ||
        _garminBleSource(base.resolvedSources['HRV'],
            samples, registeredDevices, base.sourceLabels);
    if (excludeGarminHrv) freshness.remove('HRV');''')
replace(direct,
'''      hrv30: directDailySeries('HRV', base.hrv30),
      hrvMs: hrv?.value,''',
'''      hrv30: excludeGarminHrv ? const [] : directDailySeries('HRV', base.hrv30),
      hrvMs: hrv?.value,
      clearHrv: excludeGarminHrv,''')

history = "lib/services/metric_history_service.dart"
replace(history,
'''  final List<DirectMetricSample> readings;
  final String? warning;
  const MetricHistoryResult({required this.readings, this.warning});''',
'''  final List<DirectMetricSample> readings;
  final String? warning;
  /// Prior short Garmin BLE estimates; displayed but excluded from all stats.
  final List<DirectMetricSample> excludedGarminHrv;
  const MetricHistoryResult({required this.readings, this.warning,
      this.excludedGarminHrv = const []});''')
replace(history,
'''    final readings = <DirectMetricSample>[...stored];
    String? warning;''',
'''    final readings = <DirectMetricSample>[...stored];
    final excludedGarmin = metric == 'HRV'
        ? stored.where((s) => s.metric ==
            DirectMetricService.experimentalGarminHrv).toList()
        : <DirectMetricSample>[];
    String? warning;''')
replace(history,
'''    return MetricHistoryResult(
      readings: normalize(metric, readings),
      warning: warning,
    );''',
'''    return MetricHistoryResult(
      readings: normalize(metric, readings),
      warning: warning,
      excludedGarminHrv: excludedGarmin,
    );''')

screen = "lib/screens/metric_detail_screen.dart"
replace(screen,
'''              if (sources.isNotEmpty)
                DropdownButtonFormField<String>(''',
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
              ],
              if (sources.isNotEmpty)
                DropdownButtonFormField<String>(''')

# Immediately quarantine the prior cached Garmin BLE HRV on app startup.
# Otherwise the persisted 132 ms value could affect the home screen before sync.
app = "lib/state/app_state.dart"
replace(app,
'''  factory HealthyMeState.fromJson(Map<String, dynamic> json) {
    return HealthyMeState(''',
'''  static HealthSnapshot _safeRestoredHealth(Map<String, dynamic> raw) {
    final saved = HealthSnapshot.fromJson(raw);
    final source = saved.resolvedSources['HRV'];
    final label = (source == null ? '' : saved.sourceLabels[source] ?? '')
        .toLowerCase();
    final garminBleHrv = source?.startsWith('ble:') == true &&
        (label.contains('garmin') || label.contains('voactive') ||
         label.contains('forerunner') || label.contains('fenix') ||
         label.contains('fēnix') || label.contains('venu') ||
         label.contains('instinct') || label.contains('epix'));
    if (!garminBleHrv) return saved;
    final resolved = Map<String, String>.from(saved.resolvedSources)
      ..remove('HRV');
    final freshness = Map<String, DateTime>.from(saved.freshness)
      ..remove('HRV');
    return saved.copyWith(clearHrv: true, hrv30: const [],
        resolvedSources: resolved, freshness: freshness);
  }

  factory HealthyMeState.fromJson(Map<String, dynamic> json) {
    return HealthyMeState(''')
replace(app,
'''      health: HealthSnapshot.fromJson(
        json['health'] as Map<String, dynamic>? ?? const {},
      ),''',
'''      health: _safeRestoredHealth(
        json['health'] as Map<String, dynamic>? ?? const {},
      ),''')

# Earlier test assumed a short Garmin R-R reading was validated HRV;
# now assert source is still available for real pulse/steps, not unverified HRV.
replace('test/build27_direct_metrics_test.dart',
        '    expect(merged.hrvMs, 42);',
        '    expect(merged.hrvMs, isNull);')
replace('test/build27_direct_metrics_test.dart',
        "    expect(merged.availableSources['HRV'], contains(source));",
        "    expect(merged.availableSources['HRV']?.contains(source) ?? false, isFalse);")

replace("pubspec.yaml", "version: 0.21.23+61", "version: 0.21.24+62")
print("Build 62: preserve legacy Garmin HRV as unverified, stop short-sample scoring, clear cached Recovery contribution.")
