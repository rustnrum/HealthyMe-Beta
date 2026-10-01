import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/state/app_state.dart';

void main() {
  test('connected weight wins over manual weight for current display', () {
    const state = HealthyMeState(
      profile: UserProfile(manualCurrentWeightLb: 200),
      health: HealthSnapshot(weightLb: 194.2),
    );
    expect(state.currentWeightLb, 194.2);
  });

  test('manual weight is used when connected weight is unavailable', () {
    const state = HealthyMeState(
      profile: UserProfile(manualCurrentWeightLb: 200),
    );
    expect(state.currentWeightLb, 200);
  });

  test('planned sleep duration crosses midnight correctly', () {
    const profile = UserProfile(
      sleepBedtimeMinutes: 23 * 60,
      sleepWakeMinutes: 7 * 60,
    );
    expect(profile.plannedSleepMinutes, 8 * 60);
  });

}
