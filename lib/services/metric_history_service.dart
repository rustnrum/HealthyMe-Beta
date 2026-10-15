import 'dart:io';
import 'package:health/health.dart';

import 'direct_metric_service.dart';
import 'source_name_service.dart';

class MetricHistoryResult {
  final List<DirectMetricSample> readings;
  final String? warning;
  const MetricHistoryResult({required this.readings, this.warning});
}

/// Reads timestamped Health Connect records, retaining their original app ID.
class MetricHistoryService {
  const MetricHistoryService();

  static const healthTypes = <String, HealthDataType>{
    'Heart rate': HealthDataType.HEART_RATE,
    'Resting heart rate': HealthDataType.RESTING_HEART_RATE,
    'HRV': HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    'Respiratory rate': HealthDataType.RESPIRATORY_RATE,
    'SpO2': HealthDataType.BLOOD_OXYGEN,
    'Weight': HealthDataType.WEIGHT,
    'Steps': HealthDataType.STEPS,
    'Active calories': HealthDataType.ACTIVE_ENERGY_BURNED,
    'Distance': HealthDataType.DISTANCE_DELTA,
  };

  static String unitFor(String metric) => switch(metric) {
    'Heart rate' || 'Resting heart rate' => 'bpm',
    'HRV' => 'ms', 'SpO2' => '%', 'Respiratory rate' => '/min',
    'Weight' => 'lb', 'Steps' => 'steps', 'Active calories' => 'kcal',
    'Distance' => 'mi', _ => '',
  };

  static String labelFor(String metric) => switch(metric) {
    'SpO2' => 'Blood oxygen (SpO₂)',
    'HRV' => 'Heart-rate variability',
    'Resting heart rate' => 'Resting heart rate',
    'Respiratory rate' => 'Respiratory rate',
    'Heart rate' => 'Heart rate',
    _ => metric,
  };

  static bool validValue(String metric, double value) {
    if (!value.isFinite || value < 0) return false;
    if (metric == 'SpO2') return value <= 100;
    if (metric == 'Heart rate' || metric == 'Resting heart rate') {
      return value > 0 && value <= 300;
    }
    if (metric == 'HRV') return value > 0 && value <= 1500;
    if (metric == 'Respiratory rate') return value > 0 && value <= 100;
    return true;
  }

  static List<DirectMetricSample> normalize(String metric, Iterable<DirectMetricSample> readings) {
    final unique = <String,DirectMetricSample>{};
    for (final item in readings) {
      if (item.metric != metric || !validValue(metric,item.value) ||
          item.sourceId.trim().isEmpty || item.sourceId.startsWith('ble:') ||
          SourceNameService.isTransportOnly(item.sourceId)) continue;
      final key = '${item.sourceId}|${item.capturedAt.millisecondsSinceEpoch}|${item.value}';
      unique[key] = item;
    }
    return unique.values.toList()..sort((a,b)=>a.capturedAt.compareTo(b.capturedAt));
  }

  Future<MetricHistoryResult> load(String metric, {required bool healthConnectAuthorized}) async {
    if (!healthConnectAuthorized || !Platform.isAndroid) {
      return const MetricHistoryResult(readings: [],
          warning:'Authorize Health Connect to view measured history.');
    }
    final type = healthTypes[metric];
    if(type == null) return const MetricHistoryResult(readings: []);
    try {
      final health = Health();
      await health.configure();
      final now = DateTime.now();
      final points = await health.getHealthDataFromTypes(
        types:[type], startTime:now.subtract(const Duration(days:30)), endTime:now,
        preferredUnits: const {
          HealthDataType.BLOOD_OXYGEN: HealthDataUnit.PERCENT,
          HealthDataType.WEIGHT: HealthDataUnit.POUND,
          HealthDataType.ACTIVE_ENERGY_BURNED: HealthDataUnit.KILOCALORIE,
          HealthDataType.DISTANCE_DELTA: HealthDataUnit.MILE,
        });
      final records = <DirectMetricSample>[];
      for(final point in points) {
        if(point.type != type || point.value is! NumericHealthValue) continue;
        final value = (point.value as NumericHealthValue).numericValue.toDouble();
        if (!validValue(metric,value)) continue;
        final sourceId = SourceNameService.key(sourceId:point.sourceId,sourceName:point.sourceName);
        if(sourceId.startsWith('ble:') || SourceNameService.isTransportOnly(sourceId)) continue;
        records.add(DirectMetricSample(sourceId:sourceId,deviceId:sourceId,
          deviceName:SourceNameService.displayFor(sourceId:point.sourceId,sourceName:point.sourceName),
          metric:metric,value:value,unit:unitFor(metric),capturedAt:point.dateTo));
      }
      return MetricHistoryResult(readings:normalize(metric,records));
    } catch (error) {
      return MetricHistoryResult(readings:const [],warning:'Health Connect history unavailable: $error');
    }
  }
}
