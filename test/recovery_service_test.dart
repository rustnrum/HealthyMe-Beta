import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/recovery_service.dart';
import 'package:healthy_me/state/app_state.dart';

void main() {
  test('recovery uses real available signals without inventing nutrition', () {
    final now = DateTime.now();
    final report = RecoveryService.build(
      HealthyMeState(
        profile: UserProfile(birthday: DateTime(1972, 1, 1)),
        health: HealthSnapshot(
          authorized: true,
          sleepMinutes: 420,
          sleepMinutes7: const [450, 440, 430, 420],
          restingHeartRate: 64,
          restingHeartRate30: const [65, 64, 65, 64],
          respiratoryRate: 14,
          respiratoryRate30: const [14, 14, 14, 14],
          workouts: [
            WorkoutEntry(
              type: 'Walk',
              start: now.subtract(const Duration(hours: 3)),
              end: now.subtract(const Duration(hours: 2)),
              source: 'Garmin Connect',
            ),
          ],
        ),
      ),
    );

    expect(report.score, isNotNull);
    expect(report.confidence, greaterThan(0));
    final nutrition =
        report.contributors.firstWhere((item) => item.name == 'Nutrition');
    expect(nutrition.available, isFalse);
    expect(nutrition.score, isNull);
  });

  test('missing workout history is missing, not a fake perfect recovery signal', () {
    final report = RecoveryService.build(
      HealthyMeState(
        profile: UserProfile(birthday: DateTime(1972, 1, 1)),
        health: const HealthSnapshot(
          authorized: true,
          sleepMinutes: 480,
          restingHeartRate: 64,
        ),
      ),
    );

    final training = report.contributors
        .firstWhere((item) => item.name == 'Training load');
    expect(training.available, isFalse);
    expect(training.score, isNull);
  });

  test('sleep by itself does not inflate to a near-perfect recovery score', () {
    final report = RecoveryService.build(
      HealthyMeState(
        profile: UserProfile(birthday: DateTime(1972, 1, 1)),
        health: const HealthSnapshot(
          authorized: true,
          sleepMinutes: 480,
        ),
      ),
    );

    expect(report.score, isNull);
    expect(report.label, 'Building');
    expect(report.confidence, 35);
  });

  test('recovery produces a numeric score when objective coverage is useful', () {
    final report = RecoveryService.build(
      HealthyMeState(
        profile: UserProfile(birthday: DateTime(1972, 1, 1)),
        health: const HealthSnapshot(
          authorized: true,
          sleepMinutes: 450,
          sleepMinutes7: [440, 445, 455, 450],
          restingHeartRate: 64,
          restingHeartRate30: [65, 64, 65, 64],
          respiratoryRate: 14,
          respiratoryRate30: [14, 14.2, 14.1, 14],
          hrvMs: 42,
          hrv30: [40, 41, 42, 42],
        ),
      ),
    );
    expect(report.score, isNotNull);
    expect(report.score!, inInclusiveRange(0, 100));
    expect(report.confidence, greaterThanOrEqualTo(80));
  });
}
