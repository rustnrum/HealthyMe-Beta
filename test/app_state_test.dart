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
}
