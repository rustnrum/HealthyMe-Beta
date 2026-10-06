import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'ble_discovery_service.dart';

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
        'sourceId': sourceId,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'metric': metric,
        'value': value,
        'unit': unit,
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
        capturedAt:
            DateTime.tryParse(json['capturedAt']?.toString() ?? '') ??
                DateTime.now(),
      );
}

class DirectMetricReadResult {
  final Map<String, double> metrics;
  final String message;

  const DirectMetricReadResult({
    required this.metrics,
    required this.message,
  });

  bool get hasMetrics => metrics.isNotEmpty;

  String get summary {
    if (metrics.isEmpty) return message;
    return metrics.entries.map((entry) {
      final unit = switch (entry.key) {
        'Heart rate' => ' bpm',
        'HRV' => ' ms',
        _ => '',
      };
      final decimals = entry.key == 'HRV' ? 1 : 0;
      return '${entry.key} ${entry.value.toStringAsFixed(decimals)}$unit';
    }).join(' • ');
  }
}

class DirectMetricService {
  static const _channel =
      MethodChannel('com.rustnrum.healthyme/source_discovery');
  static const _storageKey = 'salus_direct_metric_samples_v1';

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    final statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (statuses[Permission.bluetoothScan] != PermissionStatus.granted ||
        statuses[Permission.bluetoothConnect] != PermissionStatus.granted) {
      throw StateError(
        'Bluetooth scan/connect permission is required to read a direct device.',
      );
    }
  }

  Future<DirectMetricReadResult> readAndStore(
    BleDeviceCandidate device, {
    Duration duration = const Duration(seconds: 8),
  }) async {
    if (!Platform.isAndroid) {
      return const DirectMetricReadResult(
        metrics: {},
        message: 'Direct Bluetooth metric reading is only enabled on Android.',
      );
    }
    await _requestPermissions();

    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'readStandardMetrics',
      <String, dynamic>{
        'deviceId': device.id,
        'durationMs': duration.inMilliseconds,
      },
    );
    final map = raw ?? const <dynamic, dynamic>{};
    final rawMetrics = map['metrics'];
    final metrics = <String, double>{};
    if (rawMetrics is Map) {
      for (final entry in rawMetrics.entries) {
        final number = entry.value;
        if (number is num) {
          metrics[entry.key.toString()] = number.toDouble();
        }
      }
    }

    final message = map['message']?.toString() ??
        (metrics.isEmpty
            ? 'No readable standard Bluetooth health metric was returned.'
            : 'Direct Bluetooth data read successfully.');

    if (metrics.isNotEmpty) {
      final now = DateTime.now();
      final sourceId = 'ble:${device.id}';
      final samples = <DirectMetricSample>[
        for (final entry in metrics.entries)
          DirectMetricSample(
            sourceId: sourceId,
            deviceId: device.id,
            deviceName: device.name,
            metric: entry.key,
            value: entry.value,
            unit: switch (entry.key) {
              'Heart rate' => 'bpm',
              'HRV' => 'ms',
              _ => '',
            },
            capturedAt: now,
          ),
      ];
      await _append(samples);
    }

    return DirectMetricReadResult(metrics: metrics, message: message);
  }

  Future<List<DirectMetricSample>> loadSamples() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final values = decoded
          .whereType<Map<String, dynamic>>()
          .map(DirectMetricSample.fromJson)
          .where(
            (sample) =>
                sample.sourceId.isNotEmpty &&
                sample.metric.isNotEmpty &&
                sample.value.isFinite,
          )
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
    final next = <DirectMetricSample>[
      for (final sample in existing)
        if (sample.capturedAt.isAfter(cutoff)) sample,
      ...incoming,
    ];
    if (next.length > 600) {
      next.removeRange(0, next.length - 600);
    }
    await prefs.setString(
      _storageKey,
      jsonEncode(next.map((sample) => sample.toJson()).toList()),
    );
  }

  HealthSnapshot mergeIntoSnapshot(
    HealthSnapshot base, {
    required Map<String, String> metricSources,
    required List<DirectMetricSample> samples,
  }) {
    if (samples.isEmpty) return base;

    final available = <String, List<String>>{
      for (final entry in base.availableSources.entries)
        entry.key: List<String>.from(entry.value),
    };
    final labels = <String, String>{...base.sourceLabels};
    final lastSeen = <String, DateTime>{...base.sourceLastSeen};
    final counts = <String, Map<String, int>>{
      for (final entry in base.sourceRecordCounts.entries)
        entry.key: Map<String, int>.from(entry.value),
    };
    final detected = <String>{...base.detectedSources};
    final resolved = <String, String>{...base.resolvedSources};
    final freshness = <String, DateTime>{...base.freshness};

    for (final sample in samples) {
      detected.add(sample.sourceId);
      labels[sample.sourceId] = sample.deviceName;
      final previousSeen = lastSeen[sample.sourceId];
      if (previousSeen == null || sample.capturedAt.isAfter(previousSeen)) {
        lastSeen[sample.sourceId] = sample.capturedAt;
      }
      final sourceList =
          available.putIfAbsent(sample.metric, () => <String>[]);
      if (!sourceList.contains(sample.sourceId)) {
        sourceList.add(sample.sourceId);
      }
      final metricCounts =
          counts.putIfAbsent(sample.metric, () => <String, int>{});
      metricCounts[sample.sourceId] =
          (metricCounts[sample.sourceId] ?? 0) + 1;
    }

    DirectMetricSample? chosen(String metric) {
      final matching = samples
          .where((sample) => sample.metric == metric)
          .toList()
        ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
      if (matching.isEmpty) return null;

      final selected = metricSources[metric];
      if (selected != null && selected != 'Auto') {
        if (!selected.startsWith('ble:')) return null;
        final selectedSamples =
            matching.where((sample) => sample.sourceId == selected).toList();
        return selectedSamples.isEmpty ? null : selectedSamples.last;
      }

      final latest = matching.last;
      final currentFreshness = base.freshness[metric];
      if (currentFreshness == null ||
          latest.capturedAt.isAfter(currentFreshness)) {
        return latest;
      }
      return null;
    }

    final heart = chosen('Heart rate');
    final hrv = chosen('HRV');

    var heartSeries = List<HeartPoint>.from(base.heartSeries);
    if (heart != null) {
      resolved['Heart rate'] = heart.sourceId;
      freshness['Heart rate'] = heart.capturedAt;
      final duplicate = heartSeries.any(
        (point) =>
            point.date == heart.capturedAt &&
            (point.bpm - heart.value).abs() < 0.01,
      );
      if (!duplicate) {
        heartSeries.add(
          HeartPoint(date: heart.capturedAt, bpm: heart.value),
        );
        heartSeries.sort((a, b) => a.date.compareTo(b.date));
        if (heartSeries.length > 1000) {
          heartSeries = heartSeries.sublist(heartSeries.length - 1000);
        }
      }
    }
    if (hrv != null) {
      resolved['HRV'] = hrv.sourceId;
      freshness['HRV'] = hrv.capturedAt;
    }

    return base.copyWith(
      latestHeartRate: heart?.value,
      hrvMs: hrv?.value,
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
}
