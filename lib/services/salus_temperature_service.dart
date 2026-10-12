import 'dart:convert';
import 'dart:io';

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'direct_metric_service.dart';

/// Source-attributed temperature history. Skin != core body temperature.
/// This service never fills gaps with invented or extrapolated readings.
class SalusTemperatureService {
  static const storageKey = 'salus_temperature_healthconnect_v1';
  const SalusTemperatureService();

  static bool valid(DirectMetricSample s) {
    if (!s.value.isFinite) return false;
    if (s.metric == 'Skin temperature') return s.value >= 20 && s.value <= 42;
    if (s.metric == 'Body temperature') return s.value >= 30 && s.value <= 43;
    if (s.metric == 'Skin temperature delta') return s.value >= -15 && s.value <= 15;
    return false;
  }

  static List<DirectMetricSample> distinct(Iterable<DirectMetricSample> items) {
    final byKey = <String, DirectMetricSample>{};
    for (final item in items) {
      if (!valid(item) || item.sourceId.isEmpty) continue;
      byKey['${item.sourceId}|${item.metric}|${item.capturedAt.millisecondsSinceEpoch}'] = item;
    }
    final result = byKey.values.toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return result;
  }

  Future<List<DirectMetricSample>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(storageKey);
    final stored = <DirectMetricSample>[];
    if (encoded != null) {
      try {
        final json = jsonDecode(encoded);
        if (json is List) {
          for (final raw in json.whereType<Map>()) {
            stored.add(DirectMetricSample.fromJson(Map<String, dynamic>.from(raw)));
          }
        }
      } catch (_) { /* damaged imported data cannot overwrite direct readings */ }
    }
    final direct = await const DirectMetricService().loadSamples();
    return distinct([...stored, ...direct]);
  }

  /// Invoked only by an explicit user action; asks for separate HC permissions.
  /// Health Connect may not implement SKIN_TEMPERATURE on older Android builds.
  Future<({int imported, List<String> warnings})> importHealthConnect() async {
    if (!Platform.isAndroid) return (imported: 0, warnings: ['Android only.']);
    final hc = Health();
    await hc.configure();
    if (!await hc.isHealthConnectAvailable()) {
      return (imported: 0, warnings: ['Health Connect unavailable.']);
    }
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final added = <DirectMetricSample>[];
    final warnings = <String>[];
    for (final type in [HealthDataType.SKIN_TEMPERATURE, HealthDataType.BODY_TEMPERATURE]) {
      try {
        final permitted = await hc.requestAuthorization(
          [type], permissions: [HealthDataAccess.READ],
        );
        if (!permitted) {
          warnings.add('${type.name}: read permission not granted.');
          continue;
        }
        final points = await hc.getHealthDataFromTypes(
          types: [type], startTime: start, endTime: now,
        );
        for (final point in points) {
          final origin = point.sourceId.isNotEmpty ? point.sourceId : point.sourceName;
          if (origin.isEmpty) continue;
          final value = point.value;
          double? number;
          String metric;
          if (type == HealthDataType.SKIN_TEMPERATURE) {
            metric = 'Skin temperature';
            if (value is SkinTemperatureHealthValue) {
              number = value.temperature;
              if (number == null) {
                // A delta without a baseline is not an absolute body temperature.
                metric = 'Skin temperature delta';
                number = value.temperatureDelta;
              }
            }
          } else {
            metric = 'Body temperature';
            if (value is NumericHealthValue) number = value.numericValue.toDouble();
          }
          if (number == null) continue;
          final s = DirectMetricSample(
            sourceId: 'hc:$origin', deviceId: origin,
            deviceName: point.sourceName.isNotEmpty ? point.sourceName : origin,
            metric: metric, value: number, unit: '°C', capturedAt: point.dateFrom,
          );
          if (valid(s)) added.add(s);
        }
      } catch (e) {
        warnings.add('${type.name}: no readable records (${e.runtimeType}).');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final old = await load();
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final merged = distinct([...old.where((s) => s.sourceId.startsWith('hc:')), ...added])
        .where((s) => !s.capturedAt.isBefore(cutoff)).toList();
    final ok = await prefs.setString(storageKey,
        jsonEncode(merged.map((s) => s.toJson()).toList()));
    if (!ok) throw StateError('Temperature history could not be saved.');
    return (imported: added.length, warnings: warnings);
  }

  static double? baselineDelta(List<DirectMetricSample> samples) {
    // Compare daily means, not tens of same-night half-hour points vs one point.
    final skin = distinct(samples).where((s) => s.metric == 'Skin temperature').toList();
    if (skin.isEmpty) return null;
    final source = skin.last.sourceId;
    final readings = skin.where((s) => s.sourceId == source).toList();
    if (readings.length < 4) return null;
    final daily = <String, List<double>>{};
    for (final s in readings) {
      final d = s.capturedAt.toLocal();
      final key = '${d.year}-${d.month}-${d.day}';
      (daily[key] ??= []).add(s.value);
    }
    if (daily.length < 4) return null;
    final means = daily.values.map((v) => v.reduce((a,b)=>a+b) / v.length).toList();
    final previous = means.sublist(0, means.length - 1);
    final baseline = previous.reduce((a,b)=>a+b) / previous.length;
    return means.last - baseline;
  }
}
