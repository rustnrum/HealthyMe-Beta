class WorkoutExercise {
  final String id;
  final String name;
  final int sets;
  final int reps;
  final double? weight;
  final int restSeconds;
  final String notes;
  final String catalogSource;
  final String? externalId;
  final String? mediaUrl;

  const WorkoutExercise({
    required this.id,
    required this.name,
    this.sets = 3,
    this.reps = 10,
    this.weight,
    this.restSeconds = 60,
    this.notes = '',
    this.catalogSource = 'Manual',
    this.externalId,
    this.mediaUrl,
  });

  WorkoutExercise copyWith({
    String? id,
    String? name,
    int? sets,
    int? reps,
    double? weight,
    bool clearWeight = false,
    int? restSeconds,
    String? notes,
    String? catalogSource,
    String? externalId,
    String? mediaUrl,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: clearWeight ? null : (weight ?? this.weight),
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
      catalogSource: catalogSource ?? this.catalogSource,
      externalId: externalId ?? this.externalId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'restSeconds': restSeconds,
        'notes': notes,
        'catalogSource': catalogSource,
        'externalId': externalId,
        'mediaUrl': mediaUrl,
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Exercise',
      sets: (json['sets'] as num?)?.toInt() ?? 3,
      reps: (json['reps'] as num?)?.toInt() ?? 10,
      weight: (json['weight'] as num?)?.toDouble(),
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 60,
      notes: json['notes']?.toString() ?? '',
      catalogSource: json['catalogSource']?.toString() ?? 'Manual',
      externalId: json['externalId']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
    );
  }
}

class WorkoutTemplate {
  final String id;
  final String name;
  final List<WorkoutExercise> exercises;
  final String source;
  final String? externalId;
  final String? mediaBaseUrl;

  const WorkoutTemplate({
    required this.id,
    required this.name,
    this.exercises = const [],
    this.source = 'Manual',
    this.externalId,
    this.mediaBaseUrl,
  });

  WorkoutTemplate copyWith({
    String? id,
    String? name,
    List<WorkoutExercise>? exercises,
    String? source,
    String? externalId,
    String? mediaBaseUrl,
  }) {
    return WorkoutTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      mediaBaseUrl: mediaBaseUrl ?? this.mediaBaseUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'source': source,
        'externalId': externalId,
        'mediaBaseUrl': mediaBaseUrl,
      };

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Workout',
      exercises: (json['exercises'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkoutExercise.fromJson)
          .toList(),
      source: json['source']?.toString() ?? 'Manual',
      externalId: json['externalId']?.toString(),
      mediaBaseUrl: json['mediaBaseUrl']?.toString(),
    );
  }
}

class ScheduledWorkout {
  final String id;
  final String name;
  final DateTime scheduledFor;
  final String? templateId;
  final List<WorkoutExercise> exercises;
  final String notes;

  const ScheduledWorkout({
    required this.id,
    required this.name,
    required this.scheduledFor,
    this.templateId,
    this.exercises = const [],
    this.notes = '',
  });

  ScheduledWorkout copyWith({
    String? id,
    String? name,
    DateTime? scheduledFor,
    String? templateId,
    List<WorkoutExercise>? exercises,
    String? notes,
  }) {
    return ScheduledWorkout(
      id: id ?? this.id,
      name: name ?? this.name,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      templateId: templateId ?? this.templateId,
      exercises: exercises ?? this.exercises,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'scheduledFor': scheduledFor.toIso8601String(),
        'templateId': templateId,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'notes': notes,
      };

  factory ScheduledWorkout.fromJson(Map<String, dynamic> json) {
    return ScheduledWorkout(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Workout',
      scheduledFor: DateTime.tryParse(json['scheduledFor']?.toString() ?? '') ??
          DateTime.now(),
      templateId: json['templateId']?.toString(),
      exercises: (json['exercises'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkoutExercise.fromJson)
          .toList(),
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class CompletedPlannedWorkout {
  final String id;
  final String name;
  final DateTime completedAt;
  final List<WorkoutExercise> exercises;
  final String notes;

  const CompletedPlannedWorkout({
    required this.id,
    required this.name,
    required this.completedAt,
    this.exercises = const [],
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'completedAt': completedAt.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'notes': notes,
      };

  factory CompletedPlannedWorkout.fromJson(Map<String, dynamic> json) {
    return CompletedPlannedWorkout(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Workout',
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? '') ??
          DateTime.now(),
      exercises: (json['exercises'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkoutExercise.fromJson)
          .toList(),
      notes: json['notes']?.toString() ?? '',
    );
  }
}
