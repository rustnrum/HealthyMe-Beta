import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/recovery_service.dart';
import 'package:healthy_me/state/app_state.dart';

void main() {
  test('recovery uses sleep, cardio and training without inventing nutrition', () {
    final now = DateTime.now();
    final report = RecoveryService.build(
      HealthyMeState(
        profile: UserProfile(
          birthday: DateTime(1972, 1, 1),
        ),
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
              start: now.subtract(const Duration(hours: 2, minutes: 30)),
              end: now.subtract(const Duration(hours: 2)),
              source: 'Garmin Connect',
            ),
          ],
        ),
      ),
    );

    expect(report.score, isNotNull);
    expect(report.confidence, greaterThan(0));
    final nutrition = report.contributors.firstWhere((item) => item.name == 'Nutrition');
    expect(nutrition.available, isFalse);
    expect(nutrition.score, isNull);
  });

  test('hard recent training lowers training recovery contribution', () {
    final now = DateTime.now();
    final light = RecoveryService.build(
      HealthyMeState(
        profile: UserProfile(birthday: DateTime(1972, 1, 1)),
        health: const HealthSnapshot(
          authorized: true,
          sleepMinutes: 480,
          restingHeartRate: 64,
        ),
      ),
    );
    final hard = RecoveryService.build(
      HealthyMeState(
        profile: UserProfile(birthday: DateTime(1972, 1, 1)),
        health: HealthSnapshot(
          authorized: true,
          sleepMinutes: 480,
          restingHeartRate: 64,
          workouts: [
            WorkoutEntry(
              type: 'Running',
              start: now.subtract(const Duration(hours: 2, minutes: 90)),
              end: now.subtract(const Duration(hours: 2)),
              source: 'Garmin Connect',
            ),
          ],
        ),
      ),
    );

    final lightTraining = light.contributors.firstWhere((item) => item.name == 'Training load');
    final hardTraining = hard.contributors.firstWhere((item) => item.name == 'Training load');
    expect(hardTraining.score!, lessThan(lightTraining.score!));
  });
}
