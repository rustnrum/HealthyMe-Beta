import 'dart:io';
import 'dart:math';

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import 'source_name_service.dart';
import 'health_origin_registry_service.dart';

// HEALTHY_ME_SOURCE_HUB_V010
// Health Connect is an import transport. Salus routes metrics by the
// original record provider exposed by Health Connect DataOrigin metadata.
// HEALTHY_ME_SOURCE_REGISTRY_V011
class HealthConnectService {
  final Health _health = Health();
  final HealthOriginRegistryService _originRegistry =
      HealthOriginRegistryService();

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
    HealthDataType.BODY_WATER_MASS,
    HealthDataType.LEAN_BODY_MASS,
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
    // Never dedupe across providers. Cross-provider dedupe can erase the
    // very DataOrigin Salus needs for source routing. Dedupe only inside
    // each provider bucket.
    final providerBuckets = <String, List<HealthDataPoint>>{};
    for (final point in points) {
      final sourceId = point.sourceId.trim();
      final sourceName = point.sourceName.trim();
      final providerKey = sourceId.isNotEmpty ? sourceId : sourceName;
      providerBuckets.putIfAbsent(providerKey, () => <HealthDataPoint>[]).add(point);
    }
    points = [
      for (final bucket in providerBuckets.values)
        ..._health.removeDuplicates(bucket),
    ];

    final nativeRegistry = await _originRegistry.scan(
      startTime: queryStart,
      endTime: now,
    );

    String originKey(HealthDataPoint point) => SourceNameService.key(
          sourceId: point.sourceId,
          sourceName: point.sourceName,
        );

    String originLabel(HealthDataPoint point) => SourceNameService.displayFor(
          sourceId: point.sourceId,
          sourceName: point.sourceName,
        );

    final sourceLabels = <String, String>{};
    final sourceLastSeen = <String, DateTime>{};
    for (final point in points) {
      final key = originKey(point);
      if (key.isEmpty) continue;
      sourceLabels[key] = originLabel(point);
      final previous = sourceLastSeen[key];
      if (previous == null || point.dateTo.isAfter(previous)) {
        sourceLastSeen[key] = point.dateTo;
      }
    }

    // Native Android Health Connect scans the underlying Record.metadata
    // DataOrigin package name. This registry is independent from Flutter's
    // cross-provider dedupe behavior and is the source of truth for discovery.
    for (final stat in nativeRegistry.allStats()) {
      final key = stat.packageName;
      if (key.isEmpty || SourceNameService.isTransportOnly(key)) continue;
      sourceLabels[key] = stat.label.isEmpty
          ? SourceNameService.friendly(key)
          : SourceNameService.friendly(stat.label);
      final seen = stat.lastSeen;
      final previous = sourceLastSeen[key];
      if (seen != null && (previous == null || seen.isAfter(previous))) {
        sourceLastSeen[key] = seen;
      }
    }

    final sources = sourceLabels.keys
        .where((source) => !SourceNameService.isTransportOnly(source))
        .toList()
      ..sort((a, b) => (sourceLabels[a] ?? a).compareTo(sourceLabels[b] ?? b));

    bool sourceMatches(HealthDataPoint point, String? selectedSource) {
      if (selectedSource == null || selectedSource == 'Auto') return true;
      return SourceNameService.pointMatches(
        selected: selectedSource,
        sourceId: point.sourceId,
        sourceName: point.sourceName,
      );
    }

    final resolvedSources = <String, String>{};

    String? latestOriginForTypes(Iterable<HealthDataType> types) {
      final allowed = types.toSet();
      HealthDataPoint? latest;
      for (final point in points) {
        final origin = originKey(point);
        if (!allowed.contains(point.type) ||
            origin.isEmpty ||
            SourceNameService.isTransportOnly(origin)) {
          continue;
        }
        if (latest == null || point.dateTo.isAfter(latest.dateTo)) {
          latest = point;
        }
      }
      return latest == null ? null : originKey(latest);
    }

    String? resolvedOrigin(
      String metric,
      Iterable<HealthDataType> types,
    ) {
      final selected = metricSources[metric];
      if (selected != null && selected != 'Auto') {
        final matching = points
            .where((p) => types.contains(p.type) && sourceMatches(p, selected))
            .toList()
          ..sort((a, b) => a.dateTo.compareTo(b.dateTo));
        if (matching.isNotEmpty) {
          final key = originKey(matching.last);
          if (key.isNotEmpty && !SourceNameService.isTransportOnly(key)) {
            resolvedSources[metric] = key;
            return key;
          }
        }

        // A manual source choice is authoritative. Never silently fall back to
        // another provider when the selected provider has no records.
        return null;
      }

      final auto = latestOriginForTypes(types);
      if (auto != null) {
        resolvedSources[metric] = auto;
        return auto;
      }
      return null;
    }

    List<HealthDataPoint> filtered(
      HealthDataType type,
      String metric,
    ) {
      final resolved = resolvedOrigin(metric, [type]);
      if (resolved == null) return <HealthDataPoint>[];
      return points.where((p) {
        if (p.type != type) return false;
        return originKey(p) == resolved;
      }).toList()
        ..sort((a, b) => a.dateTo.compareTo(b.dateTo));
    }

    List<HealthDataPoint> filteredForSource(
      HealthDataType type,
      String? selectedSource,
    ) {
      return points.where((p) {
        if (p.type != type) return false;
        if (selectedSource == null) return true;
        return originKey(p) == selectedSource || sourceMatches(p, selectedSource);
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

    final selectedStepSource = metricSources['Steps'];
    final resolvedStepSource = resolvedOrigin(
      'Steps',
      [HealthDataType.STEPS],
    );
    final rawSteps = points
        .where(
          (p) => p.type == HealthDataType.STEPS &&
              resolvedStepSource != null &&
              originKey(p) == resolvedStepSource,
        )
        .toList()
      ..sort((a, b) => a.dateTo.compareTo(b.dateTo));

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
      // Salus deliberately totals one provider at a time so the value and
      // attribution stay aligned. Health Connect remains transport only.
      return rawStepTotal(start, end);
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

    // Motion metrics can be written by several apps at once. Anchor activity
    // values to the same provider Salus resolved for Steps so provenance
    // and totals do not mix multiple apps together.
    final resolvedMotionSource =
        selectedStepSource != null && selectedStepSource != 'Auto'
            ? selectedStepSource
            : resolvedSources['Steps'] ??
                latestOriginForTypes([
                  HealthDataType.STEPS,
                  HealthDataType.DISTANCE_DELTA,
                ]);

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

    final sleepStageTypes = <HealthDataType>[
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
    ];
    final sleepTypes = <HealthDataType>[
      HealthDataType.SLEEP_ASLEEP,
      ...sleepStageTypes,
    ];

    final sleepResolved = resolvedOrigin('Sleep', sleepTypes);
    final sleepStageResolved = resolvedOrigin('Sleep Stages', sleepStageTypes);
    final sleepPoints = points.where((p) {
      if (!sleepTypes.contains(p.type)) return false;
      return sleepResolved != null && originKey(p) == sleepResolved;
    }).toList();
    final sleepStagePoints = points.where((p) {
      if (!sleepStageTypes.contains(p.type)) return false;
      return sleepStageResolved != null && originKey(p) == sleepStageResolved;
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

    final sleepStagesByDay = <String, Map<String, int>>{};
    for (final p in sleepStagePoints) {
      final key = dayKey(p.dateTo);
      final map = sleepStagesByDay.putIfAbsent(
        key,
        () => {'awake': 0, 'rem': 0, 'light': 0, 'deep': 0},
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
    final sleepStageKeys = sleepStagesByDay.keys.toList()..sort();
    final latestSleepStageKey = sleepStageKeys.isEmpty ? null : sleepStageKeys.last;
    final latestSleepStages = latestSleepStageKey == null
        ? null
        : sleepStagesByDay[latestSleepStageKey];

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
      'Resting heart rate',
    );
    final restingValues = resting
        .map(number)
        .whereType<double>()
        .where((v) => v > 0)
        .toList();

    final hrv = filtered(
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
      'HRV',
    );
    final respiratory = filtered(
      HealthDataType.RESPIRATORY_RATE,
      'Respiratory rate',
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
      'SpO2',
    );

    final weight = filtered(HealthDataType.WEIGHT, 'Weight');
    final bodyFat = filtered(
      HealthDataType.BODY_FAT_PERCENTAGE,
      'Body fat',
    );
    final bodyWater = filtered(
      HealthDataType.BODY_WATER_MASS,
      'Body water',
    );
    final leanBodyMass = filtered(
      HealthDataType.LEAN_BODY_MASS,
      'Lean body mass',
    );

    final weightHistory = weight
        .where((p) => number(p) != null)
        .map(
          (p) => WeightPoint(
            date: p.dateTo,
            pounds: number(p)!,
            source: originLabel(p),
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
        source: originLabel(p),
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
    addFresh('Sleep Stages', sleepStagePoints);
    addFresh('Heart rate', heart);
    addFresh('Resting heart rate', resting);
    addFresh('HRV', hrv);
    addFresh('Respiratory rate', respiratory);
    addFresh('SpO2', oxygen);
    addFresh('Weight', weight);
    addFresh('Body fat', bodyFat);
    addFresh('Body water', bodyWater);
    addFresh('Lean body mass', leanBodyMass);
    addFresh('Workouts', workoutPoints);

    double? lastNumber(List<HealthDataPoint> list) {
      if (list.isEmpty) return null;
      for (final p in list.reversed) {
        final value = number(p);
        if (value != null) return value;
      }
      return null;
    }

    Map<String, int> recordCountsFor(
      String metric,
      Iterable<HealthDataType> types,
    ) {
      final counts = <String, int>{};
      final native = nativeRegistry.metrics[metric];
      if (native != null) {
        for (final entry in native.entries) {
          final source = entry.key;
          if (source.isEmpty || SourceNameService.isTransportOnly(source)) continue;
          counts[source] = entry.value.recordCount;
        }
      }

      final allowed = types.toSet();
      for (final point in points) {
        if (!allowed.contains(point.type)) continue;
        final source = originKey(point);
        if (source.isEmpty || SourceNameService.isTransportOnly(source)) continue;
        // Native count wins when present; plugin raw points provide fallback on
        // Android versions where the platform registry is unavailable.
        if (native != null &&
            native.keys.any((key) => SourceNameService.sameProvider(key, source))) {
          continue;
        }
        counts[source] = (counts[source] ?? 0) + 1;
      }
      return counts;
    }

    List<String> sourcesFromCounts(Map<String, int> counts) {
      final values = counts.keys.toList();
      values.sort(
        (a, b) => (sourceLabels[a] ?? SourceNameService.friendly(a))
            .compareTo(sourceLabels[b] ?? SourceNameService.friendly(b)),
      );
      return values;
    }

    final sourceRecordCounts = <String, Map<String, int>>{
      'Steps': recordCountsFor('Steps', [HealthDataType.STEPS]),
      'Sleep': recordCountsFor('Sleep', sleepTypes),
      'Sleep Stages': recordCountsFor('Sleep Stages', sleepStageTypes),
      'Heart rate': recordCountsFor('Heart rate', [HealthDataType.HEART_RATE]),
      'Resting heart rate': recordCountsFor(
        'Resting heart rate',
        [HealthDataType.RESTING_HEART_RATE],
      ),
      'HRV': recordCountsFor(
        'HRV',
        [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
      ),
      'Respiratory rate': recordCountsFor(
        'Respiratory rate',
        [HealthDataType.RESPIRATORY_RATE],
      ),
      'SpO2': recordCountsFor('SpO2', [HealthDataType.BLOOD_OXYGEN]),
      'Weight': recordCountsFor('Weight', [HealthDataType.WEIGHT]),
      'Body fat': recordCountsFor(
        'Body fat',
        [HealthDataType.BODY_FAT_PERCENTAGE],
      ),
      'Body water': recordCountsFor(
        'Body water',
        [HealthDataType.BODY_WATER_MASS],
      ),
      'Lean body mass': recordCountsFor(
        'Lean body mass',
        [HealthDataType.LEAN_BODY_MASS],
      ),
      'Workouts': recordCountsFor('Workouts', [HealthDataType.WORKOUT]),
    };

    final availableSources = <String, List<String>>{
      for (final entry in sourceRecordCounts.entries)
        entry.key: sourcesFromCounts(entry.value),
    };

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
      sleepAwakeMinutes: latestSleepStages?['awake'] ?? 0,
      sleepRemMinutes: latestSleepStages?['rem'] ?? 0,
      sleepLightMinutes: latestSleepStages?['light'] ?? 0,
      sleepDeepMinutes: latestSleepStages?['deep'] ?? 0,
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
      bodyWaterMassKg: lastNumber(bodyWater),
      leanBodyMassKg: lastNumber(leanBodyMass),
      bloodOxygenPercent: lastNumber(oxygen),
      respiratoryRate: lastNumber(respiratory),
      hrvMs: lastNumber(hrv),
      weightHistory: weightHistory,
      workouts: workouts,
      detectedSources: sources,
      availableSources: availableSources,
      sourceLabels: sourceLabels,
      resolvedSources: resolvedSources,
      sourceLastSeen: sourceLastSeen,
      freshness: freshness,
      sourceRecordCounts: sourceRecordCounts,
      nativeSourceRegistry: nativeRegistry.nativeSupported,
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
