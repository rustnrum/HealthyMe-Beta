import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'ble_discovery_service.dart';
import 'direct_device_store.dart';
import 'local_device_driver.dart';

/// Source-preserving direct measurement record; serialized schema unchanged.
class DirectMetricSample {
  final String sourceId;
  final String deviceId;
  final String deviceName;
  final String metric;
  final double value;
  final String unit;
  final DateTime capturedAt;
  const DirectMetricSample({
    required this.sourceId,
    required this.deviceId,
    required this.deviceName,
    required this.metric,
    required this.value,
    required this.unit,
    required this.capturedAt,
  });
  Map<String, dynamic> toJson() => {
    'sourceId': sourceId, 'deviceId': deviceId, 'deviceName': deviceName,
    'metric': metric, 'value': value, 'unit': unit,
    'capturedAt': capturedAt.toIso8601String(),
  };
  factory DirectMetricSample.fromJson(Map<String, dynamic> json) =>
      DirectMetricSample(
        sourceId: json['sourceId']?.toString() ?? '',
        deviceId: json['deviceId']?.toString() ?? '',
        deviceName: json['deviceName']?.toString() ?? 'Bluetooth device',
        metric: json['metric']?.toString() ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        unit: json['unit']?.toString() ?? '',
        capturedAt: DateTime.tryParse(json['capturedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class DirectMetricReadResult {
  final Map<String, double> metrics;
  final String message;
  final String reader;
  final List<String> observations;
  final Map<String, int> diagnostics;
  final List<DirectMetricSample> history;

  const DirectMetricReadResult({
    required this.metrics,
    required this.message,
    this.reader = 'generic',
    this.observations = const [],
    this.diagnostics = const {},
    this.history = const [],
  });
  bool get hasMetrics => metrics.isNotEmpty;

  static String _unit(String metric) => switch (metric) {
    'Heart rate' || 'Resting heart rate' => ' bpm',
    'HRV' => ' ms', 'SpO2' => '%',
    'Respiratory rate' => ' br/min',
    'Steps' => ' steps',
    'Sleep' || 'Sleep light' || 'Sleep deep' || 'Sleep REM' ||
    'Sleep awake' => ' min',
    'Battery' => '%', 'Active calories' => ' kcal',
    'Usage time' => ' min', 'AHI' => ' events/hour',
    'Leak rate' => ' L/min', 'Therapy pressure' => ' cmH₂O',
    _ => '',
  };

  String get summary {
    if (metrics.isEmpty) return message;
    const preferred = <String>[
      'Steps', 'Sleep', 'Heart rate', 'Resting heart rate', 'HRV',
      'SpO2', 'Respiratory rate', 'Usage time', 'AHI', 'Leak rate',
      'Therapy pressure', 'Battery', 'Body battery', 'Stress',
      'Ring HRV proxy',
    ];
    final keys = <String>[
      ...preferred.where(metrics.containsKey),
      ...metrics.keys.where((key) => !preferred.contains(key)),
    ];
    return keys.take(7).map((key) {
      final value = metrics[key]!;
      final decimals = key == 'HRV' ? 1 : 0;
      return '$key ${value.toStringAsFixed(decimals)}${_unit(key)}';
    }).join(' • ');
  }
}

class DirectMetricService {
  static const _channel =
      MethodChannel('com.rustnrum.healthyme/source_discovery');
  // NEVER change this key: existing user history must survive upgrades.
  static const _storageKey = 'salus_direct_metric_samples_v1';
  const DirectMetricService();

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    final statuses = await <Permission>[
      Permission.bluetoothScan, Permission.bluetoothConnect,
    ].request();
    if (statuses[Permission.bluetoothScan] != PermissionStatus.granted ||
        statuses[Permission.bluetoothConnect] != PermissionStatus.granted) {
      throw StateError('Bluetooth scan/connect permission is required to read a direct device.');
    }
  }

  static bool isValidCpapPasskey(String value) =>
      RegExp(r'^\d{4}$').hasMatch(value.trim());

  Future<bool> submitCpapPasskey(String deviceId, String passkey) async {
    final code = passkey.trim();
    if (deviceId.isEmpty || !isValidCpapPasskey(code)) return false;
    return await _channel.invokeMethod<bool>('submitCpapPasskey', {
      'deviceId': deviceId, 'cpapPasskey': code,
    }) ?? false;
  }

  static bool isTherapyOnlyProtocol(String? protocolId) =>
      protocolId == 'cpap-family';

  Future<DirectMetricReadResult> readAndStore(
    BleDeviceCandidate device, {
    String? protocolId,
    Duration duration = const Duration(seconds: 14),
    String? cpapPasskey,
  }) async {
    final resolvedProtocolId = protocolId ?? device.protocolId;
    if (!Platform.isAndroid) {
      return const DirectMetricReadResult(
        metrics: {},
        message: 'Direct Bluetooth metric reading is only enabled on Android.',
      );
    }
    await _requestPermissions();
    final map = await const SalusLocalDeviceDrivers().read(
      deviceId: device.id,
      deviceName: device.name,
      protocolId: resolvedProtocolId,
      deviceKind: device.deviceKind,
      advertisedServices: device.advertisedServices,
      duration: duration,
      cpapPasskey: cpapPasskey,
    );

    final metrics = <String, double>{};
    final rawMetrics = map['metrics'];
    if (rawMetrics is Map) {
      for (final entry in rawMetrics.entries) {
        final number = entry.value;
        if (number is num && number.toDouble().isFinite) {
          metrics[entry.key.toString()] = number.toDouble();
        }
      }
    }
    final reader = map['reader']?.toString() ?? 'generic';
    final message = map['message']?.toString() ??
        (metrics.isEmpty ? 'No readable direct-device metric was returned.' :
          'Direct device data read successfully.');
    final observations = <String>[];
    final rawObservations = map['observations'];
    if (rawObservations is List) {
      for (final item in rawObservations.whereType<Map>()) {
        final label = item['label']?.toString() ?? '';
        final hex = item['hex']?.toString() ?? '';
        if (label.isNotEmpty && hex.isNotEmpty) {
          observations.add('$label = $hex');
        }
      }
    }
    final diagnostics = <String, int>{};
    final rawDiagnostics = map['diagnostics'];
    if (rawDiagnostics is Map) {
      for (final entry in rawDiagnostics.entries) {
        final value = entry.value;
        if (value is num) diagnostics[entry.key.toString()] = value.toInt();
      }
    }
    final sourceId = 'ble:${device.id}';
    final history = <DirectMetricSample>[];
    final rawHistory = map['history'];
    if (rawHistory is List) {
      for (final item in rawHistory.whereType<Map>()) {
        final metric = item['metric']?.toString() ?? '';
        final value = item['value'];
        final capturedAtMs = item['capturedAtMs'];
        if (metric.isEmpty || value is! num || capturedAtMs is! num) continue;
        final numeric = value.toDouble();
        if (!numeric.isFinite) continue;
        history.add(DirectMetricSample(
          sourceId: sourceId, deviceId: device.id,
          deviceName: device.name, metric: metric, value: numeric,
          unit: _unitForMetric(metric),
          capturedAt: DateTime.fromMillisecondsSinceEpoch(capturedAtMs.toInt()),
        ));
      }
    }
    final current = <DirectMetricSample>[];
    if (metrics.isNotEmpty) {
      final now = DateTime.now();
      for (final entry in metrics.entries) {
        current.add(DirectMetricSample(
          sourceId: sourceId, deviceId: device.id,
          deviceName: device.name, metric: entry.key,
          value: entry.value, unit: _unitForMetric(entry.key), capturedAt: now,
        ));
      }
    }
    if (history.isNotEmpty || current.isNotEmpty) {
      await _append([...history, ...current]);
    }
    return DirectMetricReadResult(
      metrics: metrics, message: message, reader: reader,
      observations: observations, diagnostics: diagnostics, history: history,
    );
  }

  static double rmssd(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.length < 2) return 0;
    var sumSquares = 0.0;
    for (var index = 1; index < rrIntervalsMs.length; index++) {
      final delta = rrIntervalsMs[index] - rrIntervalsMs[index - 1];
      sumSquares += delta * delta;
    }
    return math.sqrt(sumSquares / (rrIntervalsMs.length - 1));
  }

  static String _unitForMetric(String metric) => switch (metric) {
    'Heart rate' || 'Resting heart rate' => 'bpm',
    'HRV' => 'ms', 'SpO2' => '%',
    'Respiratory rate' => 'br/min', 'Steps' => 'count',
    'Sleep' || 'Sleep light' || 'Sleep deep' || 'Sleep REM' ||
      'Sleep awake' => 'min',
    'Battery' => '%', 'Active calories' => 'kcal',
    'Usage time' => 'min', 'AHI' => 'events/hour',
    'Leak rate' => 'L/min', 'Therapy pressure' => 'cmH₂O',
    'Mask on/off' => 'state', 'Ring HRV proxy' => 'firmware-proxy',
    _ => '',
  };

  Future<List<DirectMetricSample>> loadSamples() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final values = decoded.whereType<Map<String, dynamic>>()
          .map(DirectMetricSample.fromJson)
          .where((s) => s.sourceId.isNotEmpty && s.metric.isNotEmpty && s.value.isFinite)
          .toList()
        ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
      return values;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _append(List<DirectMetricSample> incoming) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSamples();
    final cutoff = DateTime.now().subtract(const Duration(days: 35));
    final deduped = <String, DirectMetricSample>{};
    for (final sample in [...existing, ...incoming]) {
      if (sample.capturedAt.isBefore(cutoff)) continue;
      final key = '${sample.sourceId}|${sample.metric}|'
          '${sample.capturedAt.millisecondsSinceEpoch}';
      deduped[key] = sample;
    }
    final next = deduped.values.toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    if (next.length > 3200) {
      next.removeRange(0, next.length - 3200);
    }
    await prefs.setString(
      _storageKey, jsonEncode(next.map((s) => s.toJson()).toList()),
    );
  }

  HealthSnapshot mergeIntoSnapshot(
    HealthSnapshot base, {
    required Map<String, String> metricSources,
    required List<DirectMetricSample> samples,
    List<SavedDirectDevice> registeredDevices = const [],
  }) {
    final available = <String, List<String>>{
      for (final entry in base.availableSources.entries)
        entry.key: entry.value.where((id) => !id.startsWith('ble:')).toList(),
    };
    final labels = <String, String>{
      for (final entry in base.sourceLabels.entries)
        if (!entry.key.startsWith('ble:')) entry.key: entry.value,
    };
    final lastSeen = <String, DateTime>{
      for (final entry in base.sourceLastSeen.entries)
        if (!entry.key.startsWith('ble:')) entry.key: entry.value,
    };
    final counts = <String, Map<String, int>>{
      for (final entry in base.sourceRecordCounts.entries)
        entry.key: {
          for (final source in entry.value.entries)
            if (!source.key.startsWith('ble:')) source.key: source.value,
        },
    };
    final detected = <String>{
      ...base.detectedSources.where((id) => !id.startsWith('ble:')),
    };
    final resolved = <String, String>{
      for (final entry in base.resolvedSources.entries)
        if (!entry.value.startsWith('ble:')) entry.key: entry.value,
    };
    final freshness = <String, DateTime>{...base.freshness};

    for (final device in registeredDevices) {
      final sourceId = 'ble:${device.id}';
      detected.add(sourceId);
      labels[sourceId] = device.name;
      final providerMetrics = device.protocolId == 'cpap-family'
          ? const ['Usage time', 'AHI', 'Leak rate', 'Therapy pressure', 'Mask on/off']
          : device.capabilities;
      for (final rawMetric in providerMetrics) {
        final metric = rawMetric == 'SpO₂' ? 'SpO2' : rawMetric;
        if (metric.isEmpty || metric == 'Raw motion' ||
            metric == 'Battery' || metric == 'Device information') continue;
        final sourceList = available.putIfAbsent(metric, () => <String>[]);
        if (!sourceList.contains(sourceId)) sourceList.add(sourceId);
        counts.putIfAbsent(metric, () => <String, int>{})
            .putIfAbsent(sourceId, () => 0);
      }
    }
    final direct = samples.where((s) => s.sourceId.startsWith('ble:')).toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    for (final sample in direct) {
      detected.add(sample.sourceId);
      labels[sample.sourceId] = sample.deviceName;
      final prior = lastSeen[sample.sourceId];
      if (prior == null || sample.capturedAt.isAfter(prior)) {
        lastSeen[sample.sourceId] = sample.capturedAt;
      }
      final sources = available.putIfAbsent(sample.metric, () => <String>[]);
      if (!sources.contains(sample.sourceId)) sources.add(sample.sourceId);
      final sourceCounts = counts.putIfAbsent(sample.metric, () => <String, int>{});
      sourceCounts[sample.sourceId] = (sourceCounts[sample.sourceId] ?? 0) + 1;
      if (_isSleepStageMetric(sample.metric)) {
        final stageSources = available.putIfAbsent('Sleep Stages', () => <String>[]);
        if (!stageSources.contains(sample.sourceId)) stageSources.add(sample.sourceId);
        final stageCounts = counts.putIfAbsent('Sleep Stages', () => <String, int>{});
        stageCounts[sample.sourceId] = (stageCounts[sample.sourceId] ?? 0) + 1;
      }
    }
    DirectMetricSample? chosen(String sampleMetric, {String? routeMetric}) {
      final routingMetric = routeMetric ?? sampleMetric;
      final matching = direct.where((s) => s.metric == sampleMetric).toList();
      if (matching.isEmpty) return null;
      final selected = metricSources[routingMetric];
      if (selected != null && selected != 'Auto') {
        if (!selected.startsWith('ble:')) return null;
        final selectedSamples = matching.where((s) => s.sourceId == selected).toList();
        return selectedSamples.isEmpty ? null : selectedSamples.last;
      }
      final latest = matching.last;
      final currentFreshness = base.freshness[routingMetric];
      return currentFreshness == null || latest.capturedAt.isAfter(currentFreshness)
          ? latest : null;
    }
    final steps = chosen('Steps');
    final sleep = chosen('Sleep');
    final heart = chosen('Heart rate');
    final restingHeart = chosen('Resting heart rate');
    final hrv = chosen('HRV');
    final oxygen = chosen('SpO2');
    final respiratory = chosen('Respiratory rate');
    final activeCalories = chosen('Active calories');
    final sleepLight = chosen('Sleep light', routeMetric: 'Sleep Stages');
    final sleepDeep = chosen('Sleep deep', routeMetric: 'Sleep Stages');
    final sleepRem = chosen('Sleep REM', routeMetric: 'Sleep Stages');
    final sleepAwake = chosen('Sleep awake', routeMetric: 'Sleep Stages');

    void resolve(String metric, DirectMetricSample? sample) {
      if (sample == null) return;
      resolved[metric] = sample.sourceId;
      freshness[metric] = sample.capturedAt;
    }
    resolve('Steps', steps);
    resolve('Sleep', sleep);
    resolve('Heart rate', heart);
    resolve('Resting heart rate', restingHeart);
    resolve('HRV', hrv);
    resolve('SpO2', oxygen);
    resolve('Respiratory rate', respiratory);
    final stages = [sleepLight, sleepDeep, sleepRem, sleepAwake]
        .whereType<DirectMetricSample>().toList();
    if (stages.isNotEmpty) {
      final newest = stages.reduce(
        (a, b) => a.capturedAt.isAfter(b.capturedAt) ? a : b,
      );
      resolve('Sleep Stages', newest);
    }
    var heartSeries = List<HeartPoint>.from(base.heartSeries);
    if (heart != null) {
      final duplicate = heartSeries.any((p) =>
          p.date == heart.capturedAt && (p.bpm - heart.value).abs() < 0.01);
      if (!duplicate) {
        heartSeries.add(HeartPoint(date: heart.capturedAt, bpm: heart.value));
        heartSeries.sort((a, b) => a.date.compareTo(b.date));
        if (heartSeries.length > 1000) {
          heartSeries = heartSeries.sublist(heartSeries.length - 1000);
        }
      }
    }
    return base.copyWith(
      stepsToday: steps?.value.round(),
      sleepMinutes: sleep?.value.round(),
      sleepLightMinutes: sleepLight?.value.round(),
      sleepDeepMinutes: sleepDeep?.value.round(),
      sleepRemMinutes: sleepRem?.value.round(),
      sleepAwakeMinutes: sleepAwake?.value.round(),
      latestHeartRate: heart?.value,
      restingHeartRate: restingHeart?.value,
      hrvMs: hrv?.value,
      bloodOxygenPercent: oxygen?.value,
      respiratoryRate: respiratory?.value,
      activeCaloriesToday: activeCalories?.value,
      heartSeries: heartSeries,
      detectedSources: detected.toList(),
      availableSources: available,
      sourceLabels: labels,
      resolvedSources: resolved,
      sourceLastSeen: lastSeen,
      freshness: freshness,
      sourceRecordCounts: counts,
    );
  }

  static bool _isSleepStageMetric(String metric) =>
      metric == 'Sleep light' || metric == 'Sleep deep' ||
      metric == 'Sleep REM' || metric == 'Sleep awake';
}
