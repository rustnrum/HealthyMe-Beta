import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/models/workout_models.dart';
import 'package:healthy_me/services/direct_metric_service.dart';
import 'package:healthy_me/services/recovery_service.dart';
import 'package:healthy_me/state/app_state.dart';

void main() {
  DirectMetricSample sample(String source, String metric, double value, DateTime time) =>
      DirectMetricSample(
        sourceId: source,
        deviceId: source.substring(4),
        deviceName: source == 'ble:a' ? 'Watch A' : 'Watch B',
        metric: metric,
        value: value,
        unit: metric == 'HRV' ? 'ms' : 'bpm',
        capturedAt: time,
      );

  test('BLE baseline uses 4 distinct calendar days of the selected device only', () {
    final now = DateTime.now();
    final readings = <DirectMetricSample>[
      for (var days = 4; days >= 1; days--)
        sample('ble:a', 'HRV', 39.0 + (4 - days),
            DateTime(now.year, now.month, now.day - days, 12)),
      sample('ble:a', 'HRV', 44,
          DateTime(now.year, now.month, now.day - 1, 18)),
      sample('ble:b', 'HRV', 400,
          DateTime(now.year, now.month, now.day - 1, 19)),
    ];
    final merged = const DirectMetricService().mergeIntoSnapshot(
      const HealthSnapshot(
        authorized: true,
        hrvMs: 400,
        hrv30: [400, 401, 402, 403],
        resolvedSources: {'HRV': 'other.provider'},
      ),
      samples: readings,
      metricSources: const {'HRV': 'ble:a'},
    );
    expect(merged.hrv30, [39, 40, 41, 44]);
    expect(merged.hrvMs, 44);
    expect(merged.resolvedSources['HRV'], 'ble:a');
    expect(merged.hrv30.contains(400), isFalse);
  });

  test('recovery shows a measured number with no score when history is short', () {
    final report = RecoveryService.build(
      HealthyMeState(
        profile: UserProfile(birthday: DateTime(1972, 1, 1)),
        health: const HealthSnapshot(
          hrvMs: 42,
          hrv30: [40],
          restingHeartRate: 64,
          restingHeartRate30: [63],
          respiratoryRate: 14.5,
          respiratoryRate30: [14.5],
        ),
      ),
    );
    final hrv = report.contributors.firstWhere((c) => c.name == 'HRV');
    final rhr = report.contributors.firstWhere((c) => c.name == 'Resting HR');
    final breath = report.contributors.firstWhere((c) => c.name == 'Breathing');
    expect(hrv.score, isNull);
    expect(hrv.reading, '42 ms');
    expect(rhr.reading, '64 bpm');
    expect(breath.reading, '14.5 br/min');
    expect(hrv.detail, contains('1 of 4'));
  });

  test('completed Salus workout is recognized without inventing duration', () {
    final completed = CompletedPlannedWorkout(
      id: 'w1', name: 'Gym', completedAt: DateTime.now(),
      exercises: const [WorkoutExercise(id: 'e1', name: 'Squats')],
    );
    final report = RecoveryService.build(
      HealthyMeState(profile: UserProfile(birthday: DateTime(1972, 1, 1))),
      completedWorkouts: [completed],
    );
    final training = report.contributors.firstWhere((c) => c.name == 'Training load');
    expect(training.reading, '1 saved');
    expect(training.score, isNull);
    expect(training.detail, contains('not guessed'));
  });
}
