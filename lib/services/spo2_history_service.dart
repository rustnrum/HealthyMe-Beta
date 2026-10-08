import 'dart:io';

import 'package:health/health.dart';

import 'direct_metric_service.dart';
import 'source_name_service.dart';

/// A recorded SpO2 measurement with its original provider ID, timestamp, and
/// value. Salus never blends measurements from different providers.
class SpO2HistoryResult {
  final List<DirectMetricSample> readings;
  final String? warning;

  const SpO2HistoryResult({required this.readings, this.warning});
}

class SpO2HistoryService {
  const SpO2HistoryService();

  Future<SpO2HistoryResult> load({
    required bool healthConnectAuthorized,
  }) async {
    final readings = <DirectMetricSample>[
      ...await DirectMetricService().loadSamples(),
    ];
    String? warning;

    // Health Connect is a transport, not a source. Preserve each record's
    // DataOrigin so a selected watch/app cannot silently use another source.
    if (healthConnectAuthorized && Platform.isAndroid) {
      try {
        final health = Health();
        await health.configure();
        final now = DateTime.now();
        final points = await health.getHealthDataFromTypes(
          types: const [HealthDataType.BLOOD_OXYGEN],
          startTime: now.subtract(const Duration(days: 30)),
          endTime: now,
          preferredUnits: const {
            HealthDataType.BLOOD_OXYGEN: HealthDataUnit.PERCENT,
          },
        );
        for (final point in points) {
          if (point.type != HealthDataType.BLOOD_OXYGEN ||
              point.value is! NumericHealthValue) {
            continue;
          }
          final numeric =
              (point.value as NumericHealthValue).numericValue.toDouble();
          if (!numeric.isFinite || numeric < 0 || numeric > 100) continue;
          final sourceId = SourceNameService.key(
            sourceId: point.sourceId,
            sourceName: point.sourceName,
          );
          if (SourceNameService.isTransportOnly(sourceId)) continue;
          readings.add(
            DirectMetricSample(
              sourceId: sourceId,
              deviceId: sourceId,
              deviceName: SourceNameService.displayFor(
                sourceId: point.sourceId,
                sourceName: point.sourceName,
              ),
              metric: 'SpO2',
              value: numeric,
              unit: '%',
              capturedAt: point.dateTo,
            ),
          );
        }
      } catch (_) {
        warning = 'Health Connect SpO₂ history could not be loaded. '
            'Direct-device readings are still shown.';
      }
    }
    return SpO2HistoryResult(readings: normalized(readings), warning: warning);
  }

  /// Deduplicate within each source, never across providers, then time-sort.
  /// This also prevents an invalid reading from entering the chart.
  static List<DirectMetricSample> normalized(
    Iterable<DirectMetricSample> samples,
  ) {
    final unique = <String, DirectMetricSample>{};
    for (final sample in samples) {
      if (sample.metric != 'SpO2' && sample.metric != 'SpO₂') continue;
      if (!sample.value.isFinite || sample.value < 0 || sample.value > 100) {
        continue;
      }
      if (sample.sourceId.isEmpty ||
          SourceNameService.isTransportOnly(sample.sourceId)) {
        continue;
      }
      final key = '${sample.sourceId}|'
          '${sample.capturedAt.millisecondsSinceEpoch}|${sample.value}';
      unique[key] = sample;
    }
    return unique.values.toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
  }
}
