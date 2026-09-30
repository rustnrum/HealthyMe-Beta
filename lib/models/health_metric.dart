enum HealthMetric {
  steps,
  sleep,
  heartRate,
  weight,
  bodyFat,
  workouts,
}

extension HealthMetricLabel on HealthMetric {
  String get label {
    switch (this) {
      case HealthMetric.steps:
        return 'Steps';
      case HealthMetric.sleep:
        return 'Sleep';
      case HealthMetric.heartRate:
        return 'Heart rate';
      case HealthMetric.weight:
        return 'Weight';
      case HealthMetric.bodyFat:
        return 'Body fat';
      case HealthMetric.workouts:
        return 'Workouts';
    }
  }
}
