import 'dart:io';
import 'dart:math';

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import 'source_name_service.dart';

class HealthConnectService {
  final Health _health = Health();

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.WORKOUT,
  ];

  static final List<HealthDataAccess> _permissions =
      List<HealthDataAccess>.filled(_types.length, HealthDataAccess.READ);

  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    await _health.configure();
    return _health.isHealthConnectAvailable();
  }

  Future<({bool authorized, bool history})> authorize() async {
    if (!Platform.isAndroid) {
      return (authorized: false, history: false);
    }

    await _health.configure();

    final available = await _health.isHealthConnectAvailable();
    if (!available) {
      return (authorized: false, history: false);
    }

    await Permission.activityRecognition.request();

    final authorized = await _health.requestAuthorization(
      _types,
      permissions: _permissions,
    );

    var history = false;
    if (authorized) {
      try {
        final historyAvailable = await _health.isHealthDataHistoryAvailable();
        if (historyAvailable) {
          history = await _health.requestHealthDataHistoryAuthorization();
        }
      } catch (_) {
        history = false;
      }
    }

    return (authorized: authorized, history: history);
  }

  Future<void> revoke() async {
    if (!Platform.isAndroid) return;
    await _health.configure();
    await _health.revokePermissions();
  }

  Future<HealthSnapshot> sync({
    required bool historicalAccess,
    required Map<String, String> metricSources,
  }) async {
    if (!Platform.isAndroid) {
      throw StateError('Health Connect is only enabled for Android in this beta.');
    }

    await _health.configure();
    final available = await _health.isHealthConnectAvailable();
    if (!available) {
      throw StateError('Health Connect is not available on this device.');
    }

    final now = DateTime.now();
    final queryStart = historicalAccess
        ? DateTime(now.year - 1, now.month, now.day)
        : now.subtract(const Duration(days: 30));

    var points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: queryStart,
      endTime: now,
      preferredUnits: const {
        HealthDataType.WEIGHT: HealthDataUnit.POUND,
        HealthDataType.ACTIVE_ENERGY_BURNED: HealthDataUnit.KILOCALORIE,
        HealthDataType.BODY_FAT_PERCENTAGE: HealthDataUnit.PERCENT,
        HealthDataType.BLOOD_OXYGEN: HealthDataUnit.PERCENT,
      },
    );
    points = _health.removeDuplicates(points);

    final sources = points
        .map((p) => p.sourceName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    bool sourceMatches(HealthDataPoint point, String? selectedSource) {
      if (selectedSource == null || selectedSource == 'Auto') return true;
      return SourceNameService.sameProvider(point.sourceName, selectedSource);
    }

    List<HealthDataPoint> filtered(
      HealthDataType type,
      String metric,
    ) {
      final source = metricSources[metric];
      return points.where((p) {
        if (p.type != type) return false;
        return sourceMatches(p, source);
      }).toList()
        ..sort((a, b) => a.dateTo.compareTo(b.dateTo));
    }

    List<HealthDataPoint> filteredForSource(
      HealthDataType type,
      String? selectedSource,
    ) {
      return points.where((p) {
        if (p.type != type) return false;
        return sourceMatches(p, selectedSource);
      }).toList()
        ..sort((a, b) => a.dateTo.compareTo(b.dateTo));
    }

    double? number(HealthDataPoint p) {
      final value = p.value;
      if (value is NumericHealthValue) {
        return value.numericValue.toDouble();
      }
      return null;
    }

    double sumNumeric(
      List<HealthDataPoint> list, {
      DateTime? start,
      DateTime? end,
    }) {
      var total = 0.0;
      for (final p in list) {
        if (start != null && p.dateTo.isBefore(start)) continue;
        if (end != null && p.dateFrom.isAfter(end)) continue;
        total += number(p) ?? 0;
      }
      return total;
    }

    final today = DateTime(now.year, now.month, now.day);

    final rawSteps = filtered(HealthDataType.STEPS, 'Steps');

    int rawStepTotal(DateTime start, DateTime end) {
      var total = 0.0;
      for (final p in rawSteps) {
        if (p.dateTo.isBefore(start) || !p.dateFrom.isBefore(end)) continue;
        final value = number(p);
        if (value == null || value <= 0) continue;

        final overlapStart = p.dateFrom.isAfter(start) ? p.dateFrom : start;
        final overlapEnd = p.dateTo.isBefore(end) ? p.dateTo : end;
        if (!overlapEnd.isAfter(overlapStart)) continue;

        final recordMs = p.dateTo.difference(p.dateFrom).inMilliseconds;
        if (recordMs <= 0) {
          total += value;
          continue;
        }
        final overlapMs = overlapEnd.difference(overlapStart).inMilliseconds;
        final ratio = (overlapMs / recordMs).clamp(0.0, 1.0).toDouble();
        total += value * ratio;
      }
      return total.round();
    }

    Future<int> stepTotal(DateTime start, DateTime end) async {
      final source = metricSources['Steps'];
      if (source != null && source != 'Auto') {
        return rawStepTotal(start, end);
      }
      return await _health.getTotalStepsInInterval(start, end) ?? 0;
    }

    final stepsToday = await stepTotal(today, now);

    final hourlySteps = <int>[];
    for (var hour = 0; hour < 24; hour++) {
      final start = DateTime(now.year, now.month, now.day, hour);
      final end = start.add(const Duration(hours: 1));
      if (start.isAfter(now)) {
        hourlySteps.add(0);
      } else {
        hourlySteps.add(await stepTotal(start, end.isAfter(now) ? now : end));
      }
    }

    final dailySteps30 = <int>[];
    for (var offset = 29; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      final end = day.add(const Duration(days: 1));
      dailySteps30.add(
        await stepTotal(day, end.isAfter(now) ? now : end),
      );
    }

    final monthlySteps12 = <int>[];
    for (var offset = 11; offset >= 0; offset--) {
      final start = DateTime(now.year, now.month - offset, 1);
      final end = DateTime(start.year, start.month + 1, 1);
      if (!historicalAccess &&
          start.isBefore(now.subtract(const Duration(days: 30)))) {
        monthlySteps12.add(0);
      } else {
        monthlySteps12.add(
          await stepTotal(start, end.isAfter(now) ? now : end),
        );
      }
    }

    // Motion metrics can be written by several apps at once. For Auto steps,
    // Health Connect's aggregate API resolves step duplication. Distance and
    // active calories do not have the same aggregate helper in this plugin, so
    // anchor them to one actual motion origin rather than summing Samsung +
    // Garmin + phone records together.
    final selectedStepSource = metricSources['Steps'];
    final resolvedMotionSource =
        selectedStepSource != null && selectedStepSource != 'Auto'
            ? selectedStepSource
            : _latestSourceFor(points, HealthDataType.STEPS) ??
                _latestSourceFor(points, HealthDataType.DISTANCE_DELTA);

    final calories = filteredForSource(
      HealthDataType.ACTIVE_ENERGY_BURNED,
      resolvedMotionSource,
    );
    final distance = filteredForSource(
      HealthDataType.DISTANCE_DELTA,
      resolvedMotionSource,
    );
    final activeCaloriesToday = sumNumeric(calories, start: today, end: now);
    final distanceMilesToday = _sumDistanceMiles(
      distance,
      start: today,
      end: now,
    );

    final sleepSource = metricSources['Sleep'];
    final sleepTypes = <HealthDataType>[
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
    ];

    final sleepPoints = points.where((p) {
      if (!sleepTypes.contains(p.type)) return false;
      return sourceMatches(p, sleepSource);
    }).toList();

    Map<String, Map<String, int>> sleepByDay = {};
    String dayKey(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

    for (final p in sleepPoints) {
      final key = dayKey(p.dateTo);
      final map = sleepByDay.putIfAbsent(
        key,
        () => {
          'generic': 0,
          'awake': 0,
          'rem': 0,
          'light': 0,
          'deep': 0,
        },
      );
      final minutes = max(0, p.dateTo.difference(p.dateFrom).inMinutes);

      switch (p.type) {
        case HealthDataType.SLEEP_AWAKE:
          map['awake'] = (map['awake'] ?? 0) + minutes;
          break;
        case HealthDataType.SLEEP_REM:
          map['rem'] = (map['rem'] ?? 0) + minutes;
          break;
        case HealthDataType.SLEEP_LIGHT:
          map['light'] = (map['light'] ?? 0) + minutes;
          break;
        case HealthDataType.SLEEP_DEEP:
          map['deep'] = (map['deep'] ?? 0) + minutes;
          break;
        case HealthDataType.SLEEP_ASLEEP:
          map['generic'] = (map['generic'] ?? 0) + minutes;
          break;
        default:
          break;
      }
    }

    int totalFor(Map<String, int>? map) {
      if (map == null) return 0;
      final staged =
          (map['rem'] ?? 0) + (map['light'] ?? 0) + (map['deep'] ?? 0);
      return staged > 0 ? staged : (map['generic'] ?? 0);
    }

    final sleepKeys = sleepByDay.keys.toList()..sort();
    final latestSleepKey = sleepKeys.isEmpty ? null : sleepKeys.last;
    final latestSleep = latestSleepKey == null
        ? null
        : sleepByDay[latestSleepKey];

    final sleepMinutes7 = <int>[];
    for (var offset = 6; offset >= 0; offset--) {
      final date = today.subtract(Duration(days: offset));
      sleepMinutes7.add(totalFor(sleepByDay[dayKey(date)]));
    }

    final heart = filtered(HealthDataType.HEART_RATE, 'Heart rate');
    final last24Start = now.subtract(const Duration(hours: 24));
    final heart24 = heart
        .where((p) => p.dateTo.isAfter(last24Start))
        .where((p) => number(p) != null)
        .toList();

    final heartValues =
        heart24.map((p) => number(p)!).where((v) => v > 0).toList();

    double? average(List<double> values) {
      if (values.isEmpty) return null;
      return values.reduce((a, b) => a + b) / values.length;
    }

    final heartSeries = <HeartPoint>[];
    if (heart24.isNotEmpty) {
      final stride = max(1, (heart24.length / 60).ceil());
      for (var i = 0; i < heart24.length; i += stride) {
        final value = number(heart24[i]);
        if (value != null) {
          heartSeries.add(
            HeartPoint(date: heart24[i].dateTo, bpm: value),
          );
        }
      }
    }

    final resting = filtered(
      HealthDataType.RESTING_HEART_RATE,
      'Heart rate',
    );
    final restingValues = resting
        .map(number)
        .whereType<double>()
        .where((v) => v > 0)
        .toList();

    final hrv = filtered(
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
      'Heart rate',
    );
    final respiratory = filtered(
      HealthDataType.RESPIRATORY_RATE,
      'Heart rate',
    );
    final hrvValues = hrv
        .map(number)
        .whereType<double>()
        .where((v) => v > 0)
        .toList();
    final respiratoryValues = respiratory
        .map(number)
        .whereType<double>()
        .where((v) => v > 0)
        .toList();
    final oxygen = filtered(
      HealthDataType.BLOOD_OXYGEN,
      'Heart rate',
    );

    final weight = filtered(HealthDataType.WEIGHT, 'Weight');
    final bodyFat = filtered(
      HealthDataType.BODY_FAT_PERCENTAGE,
      'Body fat',
    );

    final weightHistory = weight
        .where((p) => number(p) != null)
        .map(
          (p) => WeightPoint(
            date: p.dateTo,
            pounds: number(p)!,
            source: p.sourceName.isEmpty ? 'Health Connect' : p.sourceName,
          ),
        )
        .toList();

    final workoutPoints = filtered(HealthDataType.WORKOUT, 'Workouts');
    final workouts = workoutPoints.reversed.take(20).map((p) {
      final type = p.workoutSummary?.workoutType ?? 'Workout';
      return WorkoutEntry(
        type: _friendlyWorkout(type),
        start: p.dateFrom,
        end: p.dateTo,
        source: p.sourceName.isEmpty ? 'Health Connect' : p.sourceName,
      );
    }).toList();

    DateTime? latestDate(List<HealthDataPoint> list) {
      if (list.isEmpty) return null;
      return list.reduce(
        (a, b) => a.dateTo.isAfter(b.dateTo) ? a : b,
      ).dateTo;
    }

    final freshness = <String, DateTime>{};
    void addFresh(String name, List<HealthDataPoint> list) {
      final date = latestDate(list);
      if (date != null) freshness[name] = date;
    }

    addFresh('Steps', rawSteps);
    addFresh('Activity', [...calories, ...distance]);
    addFresh('Sleep', sleepPoints);
    addFresh('Heart rate', [...heart, ...resting]);
    addFresh('Weight', weight);
    addFresh('Body fat', bodyFat);
    addFresh('Workouts', workoutPoints);

    double? lastNumber(List<HealthDataPoint> list) {
      if (list.isEmpty) return null;
      for (final p in list.reversed) {
        final value = number(p);
        if (value != null) return value;
      }
      return null;
    }

    return HealthSnapshot(
      authorized: true,
      historicalAccess: historicalAccess,
      lastSync: now,
      stepsToday: stepsToday,
      activeCaloriesToday: activeCaloriesToday,
      distanceMilesToday: distanceMilesToday,
      hourlySteps: hourlySteps,
      dailySteps30: dailySteps30,
      monthlySteps12: monthlySteps12,
      sleepMinutes: totalFor(latestSleep),
      sleepAwakeMinutes: latestSleep?['awake'] ?? 0,
      sleepRemMinutes: latestSleep?['rem'] ?? 0,
      sleepLightMinutes: latestSleep?['light'] ?? 0,
      sleepDeepMinutes: latestSleep?['deep'] ?? 0,
      sleepMinutes7: sleepMinutes7,
      latestHeartRate: heartValues.isEmpty ? null : heartValues.last,
      restingHeartRate: restingValues.isEmpty ? null : restingValues.last,
      averageHeartRate: average(heartValues),
      minimumHeartRate:
          heartValues.isEmpty ? null : heartValues.reduce((a, b) => a < b ? a : b),
      maximumHeartRate:
          heartValues.isEmpty ? null : heartValues.reduce((a, b) => a > b ? a : b),
      heartSeries: heartSeries,
      restingHeartRate30: restingValues,
      respiratoryRate30: respiratoryValues,
      hrv30: hrvValues,
      weightLb: lastNumber(weight),
      bodyFatPercent: lastNumber(bodyFat),
      bloodOxygenPercent: lastNumber(oxygen),
      respiratoryRate: lastNumber(respiratory),
      hrvMs: lastNumber(hrv),
      weightHistory: weightHistory,
      workouts: workouts,
      detectedSources: sources,
      freshness: freshness,
    );
  }

  static double distanceValueToMiles(double value, HealthDataUnit unit) {
    final name = unit.name.toUpperCase();
    if (name.contains('MILE')) return value;
    if (name.contains('KILOMETER')) return value * 0.6213711922;
    if (name.contains('YARD')) return value / 1760.0;
    if (name.contains('FOOT') || name.contains('FEET')) return value / 5280.0;
    if (name.contains('CENTIMETER')) return value / 160934.4;
    // Health Connect's canonical distance storage is meters. Unknown units from
    // Android are therefore treated as meters instead of being displayed raw.
    return value / 1609.344;
  }

  static String? _latestSourceFor(
    List<HealthDataPoint> points,
    HealthDataType type,
  ) {
    HealthDataPoint? latest;
    for (final point in points) {
      if (point.type != type || point.sourceName.trim().isEmpty) continue;
      if (latest == null || point.dateTo.isAfter(latest.dateTo)) {
        latest = point;
      }
    }
    return latest?.sourceName;
  }

  static double _sumDistanceMiles(
    List<HealthDataPoint> list, {
    DateTime? start,
    DateTime? end,
  }) {
    var total = 0.0;
    for (final p in list) {
      if (start != null && p.dateTo.isBefore(start)) continue;
      if (end != null && p.dateFrom.isAfter(end)) continue;
      final value = p.value;
      if (value is NumericHealthValue) {
        total += distanceValueToMiles(value.numericValue.toDouble(), p.unit);
      }
    }
    return total;
  }

  static String _friendlyWorkout(String value) {
    final cleaned = value
        .replaceAll('WorkoutActivityType.', '')
        .replaceAll('_', ' ')
        .toLowerCase();
    if (cleaned.isEmpty) return 'Workout';
    return cleaned
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? ''
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}
