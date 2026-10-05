class UserProfile {
  final bool completed;
  final String firstName;
  final String sex;
  final DateTime? birthday;
  final double? heightIn;
  final double? startingWeightLb;
  final double? manualCurrentWeightLb;
  final double? goalWeightLb;
  final String primaryGoal;
  final String activityLevel;
  final int stepGoal;
  final int workoutGoalPerWeek;
  final int sleepBedtimeMinutes;
  final int sleepWakeMinutes;

  const UserProfile({
    this.completed = false,
    this.firstName = '',
    this.sex = 'Male',
    this.birthday,
    this.heightIn,
    this.startingWeightLb,
    this.manualCurrentWeightLb,
    this.goalWeightLb,
    this.primaryGoal = 'Fat loss',
    this.activityLevel = 'Mostly seated',
    this.stepGoal = 10000,
    this.workoutGoalPerWeek = 4,
    this.sleepBedtimeMinutes = 23 * 60,
    this.sleepWakeMinutes = 7 * 60,
  });

  int? get age {
    if (birthday == null) return null;
    final now = DateTime.now();
    var value = now.year - birthday!.year;
    final passed = now.month > birthday!.month ||
        (now.month == birthday!.month && now.day >= birthday!.day);
    if (!passed) value--;
    return value;
  }

  int get plannedSleepMinutes {
    final raw = sleepWakeMinutes - sleepBedtimeMinutes;
    return raw > 0 ? raw : raw + (24 * 60);
  }

  UserProfile copyWith({
    bool? completed,
    String? firstName,
    String? sex,
    DateTime? birthday,
    double? heightIn,
    double? startingWeightLb,
    double? manualCurrentWeightLb,
    double? goalWeightLb,
    String? primaryGoal,
    String? activityLevel,
    int? stepGoal,
    int? workoutGoalPerWeek,
    int? sleepBedtimeMinutes,
    int? sleepWakeMinutes,
  }) {
    return UserProfile(
      completed: completed ?? this.completed,
      firstName: firstName ?? this.firstName,
      sex: sex ?? this.sex,
      birthday: birthday ?? this.birthday,
      heightIn: heightIn ?? this.heightIn,
      startingWeightLb: startingWeightLb ?? this.startingWeightLb,
      manualCurrentWeightLb:
          manualCurrentWeightLb ?? this.manualCurrentWeightLb,
      goalWeightLb: goalWeightLb ?? this.goalWeightLb,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      activityLevel: activityLevel ?? this.activityLevel,
      stepGoal: stepGoal ?? this.stepGoal,
      workoutGoalPerWeek:
          workoutGoalPerWeek ?? this.workoutGoalPerWeek,
      sleepBedtimeMinutes:
          sleepBedtimeMinutes ?? this.sleepBedtimeMinutes,
      sleepWakeMinutes: sleepWakeMinutes ?? this.sleepWakeMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'completed': completed,
        'firstName': firstName,
        'sex': sex,
        'birthday': birthday?.toIso8601String(),
        'heightIn': heightIn,
        'startingWeightLb': startingWeightLb,
        'manualCurrentWeightLb': manualCurrentWeightLb,
        'goalWeightLb': goalWeightLb,
        'primaryGoal': primaryGoal,
        'activityLevel': activityLevel,
        'stepGoal': stepGoal,
        'workoutGoalPerWeek': workoutGoalPerWeek,
        'sleepBedtimeMinutes': sleepBedtimeMinutes,
        'sleepWakeMinutes': sleepWakeMinutes,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      completed: json['completed'] == true,
      firstName: json['firstName']?.toString() ?? '',
      sex: json['sex']?.toString() ?? 'Male',
      birthday: DateTime.tryParse(json['birthday']?.toString() ?? ''),
      heightIn: (json['heightIn'] as num?)?.toDouble(),
      startingWeightLb: (json['startingWeightLb'] as num?)?.toDouble(),
      manualCurrentWeightLb:
          (json['manualCurrentWeightLb'] as num?)?.toDouble(),
      goalWeightLb: (json['goalWeightLb'] as num?)?.toDouble(),
      primaryGoal: json['primaryGoal']?.toString() ?? 'Fat loss',
      activityLevel: json['activityLevel']?.toString() ?? 'Mostly seated',
      stepGoal: (json['stepGoal'] as num?)?.toInt() ?? 10000,
      workoutGoalPerWeek:
          (json['workoutGoalPerWeek'] as num?)?.toInt() ?? 4,
      sleepBedtimeMinutes:
          (json['sleepBedtimeMinutes'] as num?)?.toInt() ?? 23 * 60,
      sleepWakeMinutes:
          (json['sleepWakeMinutes'] as num?)?.toInt() ?? 7 * 60,
    );
  }
}

class WeightPoint {
  final DateTime date;
  final double pounds;
  final String source;

  const WeightPoint({
    required this.date,
    required this.pounds,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'pounds': pounds,
        'source': source,
      };

  factory WeightPoint.fromJson(Map<String, dynamic> json) {
    return WeightPoint(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      pounds: (json['pounds'] as num?)?.toDouble() ?? 0,
      source: json['source']?.toString() ?? 'Manual',
    );
  }
}

class HeartPoint {
  final DateTime date;
  final double bpm;

  const HeartPoint({required this.date, required this.bpm});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'bpm': bpm,
      };

  factory HeartPoint.fromJson(Map<String, dynamic> json) {
    return HeartPoint(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      bpm: (json['bpm'] as num?)?.toDouble() ?? 0,
    );
  }
}

class WorkoutEntry {
  final String type;
  final DateTime start;
  final DateTime end;
  final String source;

  const WorkoutEntry({
    required this.type,
    required this.start,
    required this.end,
    required this.source,
  });

  int get minutes => end.difference(start).inMinutes;

  Map<String, dynamic> toJson() => {
        'type': type,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'source': source,
      };

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) {
    return WorkoutEntry(
      type: json['type']?.toString() ?? 'Workout',
      start: DateTime.tryParse(json['start']?.toString() ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(json['end']?.toString() ?? '') ?? DateTime.now(),
      source: json['source']?.toString() ?? 'Health Connect',
    );
  }
}

class HealthSnapshot {
  final bool authorized;
  final bool historicalAccess;
  final DateTime? lastSync;
  final String? error;
  final int stepsToday;
  final double activeCaloriesToday;
  final double distanceMilesToday;
  final List<int> hourlySteps;
  final List<int> dailySteps30;
  final List<int> monthlySteps12;
  final int sleepMinutes;
  final int sleepAwakeMinutes;
  final int sleepRemMinutes;
  final int sleepLightMinutes;
  final int sleepDeepMinutes;
  final List<int> sleepMinutes7;
  final double? latestHeartRate;
  final double? restingHeartRate;
  final double? averageHeartRate;
  final double? minimumHeartRate;
  final double? maximumHeartRate;
  final List<HeartPoint> heartSeries;
  final List<double> restingHeartRate30;
  final List<double> respiratoryRate30;
  final List<double> hrv30;
  final double? weightLb;
  final double? bodyFatPercent;
  final double? bodyWaterMassKg;
  final double? leanBodyMassKg;
  final double? bloodOxygenPercent;
  final double? respiratoryRate;
  final double? hrvMs;
  final List<WeightPoint> weightHistory;
  final List<WorkoutEntry> workouts;
  final List<String> detectedSources;
  final Map<String, List<String>> availableSources;
  final Map<String, String> sourceLabels;
  final Map<String, String> resolvedSources;
  final Map<String, DateTime> sourceLastSeen;
  final Map<String, DateTime> freshness;
  final Map<String, Map<String, int>> sourceRecordCounts;
  final bool nativeSourceRegistry;

  const HealthSnapshot({
    this.authorized = false,
    this.historicalAccess = false,
    this.lastSync,
    this.error,
    this.stepsToday = 0,
    this.activeCaloriesToday = 0,
    this.distanceMilesToday = 0,
    this.hourlySteps = const [],
    this.dailySteps30 = const [],
    this.monthlySteps12 = const [],
    this.sleepMinutes = 0,
    this.sleepAwakeMinutes = 0,
    this.sleepRemMinutes = 0,
    this.sleepLightMinutes = 0,
    this.sleepDeepMinutes = 0,
    this.sleepMinutes7 = const [],
    this.latestHeartRate,
    this.restingHeartRate,
    this.averageHeartRate,
    this.minimumHeartRate,
    this.maximumHeartRate,
    this.heartSeries = const [],
    this.restingHeartRate30 = const [],
    this.respiratoryRate30 = const [],
    this.hrv30 = const [],
    this.weightLb,
    this.bodyFatPercent,
    this.bodyWaterMassKg,
    this.leanBodyMassKg,
    this.bloodOxygenPercent,
    this.respiratoryRate,
    this.hrvMs,
    this.weightHistory = const [],
    this.workouts = const [],
    this.detectedSources = const [],
    this.availableSources = const {},
    this.sourceLabels = const {},
    this.resolvedSources = const {},
    this.sourceLastSeen = const {},
    this.freshness = const {},
    this.sourceRecordCounts = const {},
    this.nativeSourceRegistry = false,
  });

  HealthSnapshot copyWith({
    bool? authorized,
    bool? historicalAccess,
    DateTime? lastSync,
    String? error,
    bool clearError = false,
    int? stepsToday,
    double? activeCaloriesToday,
    double? distanceMilesToday,
    List<int>? hourlySteps,
    List<int>? dailySteps30,
    List<int>? monthlySteps12,
    int? sleepMinutes,
    int? sleepAwakeMinutes,
    int? sleepRemMinutes,
    int? sleepLightMinutes,
    int? sleepDeepMinutes,
    List<int>? sleepMinutes7,
    double? latestHeartRate,
    double? restingHeartRate,
    double? averageHeartRate,
    double? minimumHeartRate,
    double? maximumHeartRate,
    List<HeartPoint>? heartSeries,
    List<double>? restingHeartRate30,
    List<double>? respiratoryRate30,
    List<double>? hrv30,
    double? weightLb,
    double? bodyFatPercent,
    double? bodyWaterMassKg,
    double? leanBodyMassKg,
    double? bloodOxygenPercent,
    double? respiratoryRate,
    double? hrvMs,
    List<WeightPoint>? weightHistory,
    List<WorkoutEntry>? workouts,
    List<String>? detectedSources,
    Map<String, List<String>>? availableSources,
    Map<String, String>? sourceLabels,
    Map<String, String>? resolvedSources,
    Map<String, DateTime>? sourceLastSeen,
    Map<String, DateTime>? freshness,
    Map<String, Map<String, int>>? sourceRecordCounts,
    bool? nativeSourceRegistry,
  }) {
    return HealthSnapshot(
      authorized: authorized ?? this.authorized,
      historicalAccess: historicalAccess ?? this.historicalAccess,
      lastSync: lastSync ?? this.lastSync,
      error: clearError ? null : (error ?? this.error),
      stepsToday: stepsToday ?? this.stepsToday,
      activeCaloriesToday:
          activeCaloriesToday ?? this.activeCaloriesToday,
      distanceMilesToday: distanceMilesToday ?? this.distanceMilesToday,
      hourlySteps: hourlySteps ?? this.hourlySteps,
      dailySteps30: dailySteps30 ?? this.dailySteps30,
      monthlySteps12: monthlySteps12 ?? this.monthlySteps12,
      sleepMinutes: sleepMinutes ?? this.sleepMinutes,
      sleepAwakeMinutes: sleepAwakeMinutes ?? this.sleepAwakeMinutes,
      sleepRemMinutes: sleepRemMinutes ?? this.sleepRemMinutes,
      sleepLightMinutes: sleepLightMinutes ?? this.sleepLightMinutes,
      sleepDeepMinutes: sleepDeepMinutes ?? this.sleepDeepMinutes,
      sleepMinutes7: sleepMinutes7 ?? this.sleepMinutes7,
      latestHeartRate: latestHeartRate ?? this.latestHeartRate,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      minimumHeartRate: minimumHeartRate ?? this.minimumHeartRate,
      maximumHeartRate: maximumHeartRate ?? this.maximumHeartRate,
      heartSeries: heartSeries ?? this.heartSeries,
      restingHeartRate30: restingHeartRate30 ?? this.restingHeartRate30,
      respiratoryRate30: respiratoryRate30 ?? this.respiratoryRate30,
      hrv30: hrv30 ?? this.hrv30,
      weightLb: weightLb ?? this.weightLb,
      bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
      bodyWaterMassKg: bodyWaterMassKg ?? this.bodyWaterMassKg,
      leanBodyMassKg: leanBodyMassKg ?? this.leanBodyMassKg,
      bloodOxygenPercent: bloodOxygenPercent ?? this.bloodOxygenPercent,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      hrvMs: hrvMs ?? this.hrvMs,
      weightHistory: weightHistory ?? this.weightHistory,
      workouts: workouts ?? this.workouts,
      detectedSources: detectedSources ?? this.detectedSources,
      availableSources: availableSources ?? this.availableSources,
      sourceLabels: sourceLabels ?? this.sourceLabels,
      resolvedSources: resolvedSources ?? this.resolvedSources,
      sourceLastSeen: sourceLastSeen ?? this.sourceLastSeen,
      freshness: freshness ?? this.freshness,
      sourceRecordCounts: sourceRecordCounts ?? this.sourceRecordCounts,
      nativeSourceRegistry:
          nativeSourceRegistry ?? this.nativeSourceRegistry,
    );
  }

  Map<String, dynamic> toJson() => {
        'authorized': authorized,
        'historicalAccess': historicalAccess,
        'lastSync': lastSync?.toIso8601String(),
        'error': error,
        'stepsToday': stepsToday,
        'activeCaloriesToday': activeCaloriesToday,
        'distanceMilesToday': distanceMilesToday,
        'hourlySteps': hourlySteps,
        'dailySteps30': dailySteps30,
        'monthlySteps12': monthlySteps12,
        'sleepMinutes': sleepMinutes,
        'sleepAwakeMinutes': sleepAwakeMinutes,
        'sleepRemMinutes': sleepRemMinutes,
        'sleepLightMinutes': sleepLightMinutes,
        'sleepDeepMinutes': sleepDeepMinutes,
        'sleepMinutes7': sleepMinutes7,
        'latestHeartRate': latestHeartRate,
        'restingHeartRate': restingHeartRate,
        'averageHeartRate': averageHeartRate,
        'minimumHeartRate': minimumHeartRate,
        'maximumHeartRate': maximumHeartRate,
        'heartSeries': heartSeries.map((e) => e.toJson()).toList(),
        'restingHeartRate30': restingHeartRate30,
        'respiratoryRate30': respiratoryRate30,
        'hrv30': hrv30,
        'weightLb': weightLb,
        'bodyFatPercent': bodyFatPercent,
        'bodyWaterMassKg': bodyWaterMassKg,
        'leanBodyMassKg': leanBodyMassKg,
        'bloodOxygenPercent': bloodOxygenPercent,
        'respiratoryRate': respiratoryRate,
        'hrvMs': hrvMs,
        'weightHistory': weightHistory.map((e) => e.toJson()).toList(),
        'workouts': workouts.map((e) => e.toJson()).toList(),
        'detectedSources': detectedSources,
        'availableSources': availableSources,
        'sourceLabels': sourceLabels,
        'resolvedSources': resolvedSources,
        'sourceLastSeen': sourceLastSeen.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        ),
        'freshness': freshness.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        ),
        'sourceRecordCounts': sourceRecordCounts,
        'nativeSourceRegistry': nativeSourceRegistry,
      };

  factory HealthSnapshot.fromJson(Map<String, dynamic> json) {
    List<int> ints(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((e) => (e as num).toInt())
            .toList();

    List<double> doubles(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((e) => (e as num).toDouble())
            .toList();

    final rawFresh =
        json['freshness'] as Map<String, dynamic>? ?? const {};
    final rawSources =
        json['availableSources'] as Map<String, dynamic>? ?? const {};
    final rawSourceLabels =
        json['sourceLabels'] as Map<String, dynamic>? ?? const {};
    final rawResolvedSources =
        json['resolvedSources'] as Map<String, dynamic>? ?? const {};
    final rawSourceLastSeen =
        json['sourceLastSeen'] as Map<String, dynamic>? ?? const {};
    final rawSourceRecordCounts =
        json['sourceRecordCounts'] as Map<String, dynamic>? ?? const {};

    return HealthSnapshot(
      authorized: json['authorized'] == true,
      historicalAccess: json['historicalAccess'] == true,
      lastSync: DateTime.tryParse(json['lastSync']?.toString() ?? ''),
      error: json['error']?.toString(),
      stepsToday: (json['stepsToday'] as num?)?.toInt() ?? 0,
      activeCaloriesToday:
          (json['activeCaloriesToday'] as num?)?.toDouble() ?? 0,
      distanceMilesToday:
          (json['distanceMilesToday'] as num?)?.toDouble() ?? 0,
      hourlySteps: ints('hourlySteps'),
      dailySteps30: ints('dailySteps30'),
      monthlySteps12: ints('monthlySteps12'),
      sleepMinutes: (json['sleepMinutes'] as num?)?.toInt() ?? 0,
      sleepAwakeMinutes:
          (json['sleepAwakeMinutes'] as num?)?.toInt() ?? 0,
      sleepRemMinutes: (json['sleepRemMinutes'] as num?)?.toInt() ?? 0,
      sleepLightMinutes:
          (json['sleepLightMinutes'] as num?)?.toInt() ?? 0,
      sleepDeepMinutes:
          (json['sleepDeepMinutes'] as num?)?.toInt() ?? 0,
      sleepMinutes7: ints('sleepMinutes7'),
      latestHeartRate: (json['latestHeartRate'] as num?)?.toDouble(),
      restingHeartRate: (json['restingHeartRate'] as num?)?.toDouble(),
      averageHeartRate: (json['averageHeartRate'] as num?)?.toDouble(),
      minimumHeartRate: (json['minimumHeartRate'] as num?)?.toDouble(),
      maximumHeartRate: (json['maximumHeartRate'] as num?)?.toDouble(),
      heartSeries:
          (json['heartSeries'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(HeartPoint.fromJson)
              .toList(),
      restingHeartRate30: doubles('restingHeartRate30'),
      respiratoryRate30: doubles('respiratoryRate30'),
      hrv30: doubles('hrv30'),
      weightLb: (json['weightLb'] as num?)?.toDouble(),
      bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
      bodyWaterMassKg: (json['bodyWaterMassKg'] as num?)?.toDouble(),
      leanBodyMassKg: (json['leanBodyMassKg'] as num?)?.toDouble(),
      bloodOxygenPercent:
          (json['bloodOxygenPercent'] as num?)?.toDouble(),
      respiratoryRate: (json['respiratoryRate'] as num?)?.toDouble(),
      hrvMs: (json['hrvMs'] as num?)?.toDouble(),
      weightHistory:
          (json['weightHistory'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(WeightPoint.fromJson)
              .toList(),
      workouts:
          (json['workouts'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(WorkoutEntry.fromJson)
              .toList(),
      detectedSources:
          (json['detectedSources'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      availableSources: rawSources.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
        ),
      ),
      sourceLabels: rawSourceLabels.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      resolvedSources: rawResolvedSources.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      sourceLastSeen: rawSourceLastSeen.map(
        (key, value) => MapEntry(
          key,
          DateTime.tryParse(value.toString()) ?? DateTime.now(),
        ),
      ),
      freshness: rawFresh.map(
        (key, value) => MapEntry(
          key,
          DateTime.tryParse(value.toString()) ?? DateTime.now(),
        ),
      ),
      sourceRecordCounts: rawSourceRecordCounts.map(
        (metric, value) => MapEntry(
          metric,
          (value as Map<String, dynamic>? ?? const {}).map(
            (source, count) =>
                MapEntry(source, (count as num?)?.toInt() ?? 0),
          ),
        ),
      ),
      nativeSourceRegistry: json['nativeSourceRegistry'] == true,
    );
  }
}

class BodyMeasurements {
  final double? neck;
  final double? chest;
  final double? waist;
  final double? hips;
  final double? leftArm;
  final double? rightArm;
  final double? leftThigh;
  final double? rightThigh;
  final double? leftCalf;
  final double? rightCalf;

  const BodyMeasurements({
    this.neck,
    this.chest,
    this.waist,
    this.hips,
    this.leftArm,
    this.rightArm,
    this.leftThigh,
    this.rightThigh,
    this.leftCalf,
    this.rightCalf,
  });

  Map<String, dynamic> toJson() => {
        'neck': neck,
        'chest': chest,
        'waist': waist,
        'hips': hips,
        'leftArm': leftArm,
        'rightArm': rightArm,
        'leftThigh': leftThigh,
        'rightThigh': rightThigh,
        'leftCalf': leftCalf,
        'rightCalf': rightCalf,
      };

  factory BodyMeasurements.fromJson(Map<String, dynamic> json) {
    double? v(String key) => (json[key] as num?)?.toDouble();
    return BodyMeasurements(
      neck: v('neck'),
      chest: v('chest'),
      waist: v('waist'),
      hips: v('hips'),
      leftArm: v('leftArm'),
      rightArm: v('rightArm'),
      leftThigh: v('leftThigh'),
      rightThigh: v('rightThigh'),
      leftCalf: v('leftCalf'),
      rightCalf: v('rightCalf'),
    );
  }
}

class LabResult {
  final String id;
  final String name;
  final String value;
  final String unit;
  final DateTime? date;
  final String source;

  const LabResult({
    required this.id,
    required this.name,
    required this.value,
    this.unit = '',
    this.date,
    this.source = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'value': value,
        'unit': unit,
        'date': date?.toIso8601String(),
        'source': source,
      };

  factory LabResult.fromJson(Map<String, dynamic> json) {
    return LabResult(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      source: json['source']?.toString() ?? '',
    );
  }
}

class ProgressPhoto {
  final String id;
  final String path;
  final DateTime date;
  final String view;

  const ProgressPhoto({
    required this.id,
    required this.path,
    required this.date,
    required this.view,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'date': date.toIso8601String(),
        'view': view,
      };

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) {
    return ProgressPhoto(
      id: json['id']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      view: json['view']?.toString() ?? 'Front',
    );
  }
}
