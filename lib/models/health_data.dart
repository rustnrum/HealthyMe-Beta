class WeightEntry {
  final DateTime date;
  final double weightLb;

  const WeightEntry({
    required this.date,
    required this.weightLb,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weightLb': weightLb,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      weightLb: (json['weightLb'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BodyMeasurements {
  final double? waist;
  final double? chest;
  final double? hips;
  final double? neck;
  final double? leftArm;
  final double? rightArm;
  final double? leftThigh;
  final double? rightThigh;

  const BodyMeasurements({
    this.waist,
    this.chest,
    this.hips,
    this.neck,
    this.leftArm,
    this.rightArm,
    this.leftThigh,
    this.rightThigh,
  });

  Map<String, dynamic> toJson() => {
        'waist': waist,
        'chest': chest,
        'hips': hips,
        'neck': neck,
        'leftArm': leftArm,
        'rightArm': rightArm,
        'leftThigh': leftThigh,
        'rightThigh': rightThigh,
      };

  factory BodyMeasurements.fromJson(Map<String, dynamic> json) {
    double? value(String key) => (json[key] as num?)?.toDouble();
    return BodyMeasurements(
      waist: value('waist'),
      chest: value('chest'),
      hips: value('hips'),
      neck: value('neck'),
      leftArm: value('leftArm'),
      rightArm: value('rightArm'),
      leftThigh: value('leftThigh'),
      rightThigh: value('rightThigh'),
    );
  }

  BodyMeasurements copyWith({
    double? waist,
    double? chest,
    double? hips,
    double? neck,
    double? leftArm,
    double? rightArm,
    double? leftThigh,
    double? rightThigh,
  }) {
    return BodyMeasurements(
      waist: waist ?? this.waist,
      chest: chest ?? this.chest,
      hips: hips ?? this.hips,
      neck: neck ?? this.neck,
      leftArm: leftArm ?? this.leftArm,
      rightArm: rightArm ?? this.rightArm,
      leftThigh: leftThigh ?? this.leftThigh,
      rightThigh: rightThigh ?? this.rightThigh,
    );
  }
}

class HealthDataState {
  final List<WeightEntry> weightHistory;
  final BodyMeasurements measurements;
  final Map<String, int> recentSteps;
  final double? bodyFatPercent;

  const HealthDataState({
    this.weightHistory = const [],
    this.measurements = const BodyMeasurements(),
    this.recentSteps = const {},
    this.bodyFatPercent,
  });

  Map<String, dynamic> toJson() => {
        'weightHistory': weightHistory.map((e) => e.toJson()).toList(),
        'measurements': measurements.toJson(),
        'recentSteps': recentSteps,
        'bodyFatPercent': bodyFatPercent,
      };

  factory HealthDataState.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['weightHistory'] as List<dynamic>? ?? const [];
    final rawMeasurements =
        json['measurements'] as Map<String, dynamic>? ?? const {};
    final rawSteps = json['recentSteps'] as Map<String, dynamic>? ?? const {};

    return HealthDataState(
      weightHistory: rawHistory
          .whereType<Map<String, dynamic>>()
          .map(WeightEntry.fromJson)
          .toList(),
      measurements: BodyMeasurements.fromJson(rawMeasurements),
      recentSteps: rawSteps.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
    );
  }

  HealthDataState copyWith({
    List<WeightEntry>? weightHistory,
    BodyMeasurements? measurements,
    Map<String, int>? recentSteps,
    double? bodyFatPercent,
    bool clearBodyFat = false,
  }) {
    return HealthDataState(
      weightHistory: weightHistory ?? this.weightHistory,
      measurements: measurements ?? this.measurements,
      recentSteps: recentSteps ?? this.recentSteps,
      bodyFatPercent:
          clearBodyFat ? null : (bodyFatPercent ?? this.bodyFatPercent),
    );
  }
}
