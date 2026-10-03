import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/daily_state.dart';
import 'package:healthy_me/services/daily_state_service.dart';
import 'package:healthy_me/state/app_state.dart';

void main() {
  test('morning check-in is controlled by configured start time', () {
    const app = HealthyMeState(
      dailyStateEnabled: true,
      dailyStateStartMinutes: 8 * 60,
    );

    expect(
      DailyStateService.isDue(
        app.copyWith(profile: app.profile.copyWith(completed: true)),
        now: DateTime(2026, 10, 3, 7, 59),
      ),
      isFalse,
    );
    expect(
      DailyStateService.isDue(
        app.copyWith(profile: app.profile.copyWith(completed: true)),
        now: DateTime(2026, 10, 3, 8, 0),
      ),
      isTrue,
    );
  });

  test('completed check-in prevents another prompt that day', () {
    final entry = DailyStateEntry(
      date: DateTime(2026, 10, 3, 8, 5),
      physicalCapability: 4,
      mentalCapability: 4,
      emotionalBalance: 4,
      overallRecovery: 4,
      muscularStress: 2,
      lackActivation: 2,
      negativeEmotionalState: 1,
      overallStress: 2,
    );
    final app = HealthyMeState(
      profile: const HealthyMeState().profile.copyWith(completed: true),
      dailyStates: [entry],
    );

    expect(
      DailyStateService.isDue(app, now: DateTime(2026, 10, 3, 10)),
      isFalse,
    );
  });

  test('subjective estimate falls when recovery is low and stress is high', () {
    final rough = DailyStateEntry(
      date: DateTime(2026, 10, 3),
      physicalCapability: 1,
      mentalCapability: 2,
      emotionalBalance: 2,
      overallRecovery: 1,
      muscularStress: 5,
      lackActivation: 5,
      negativeEmotionalState: 4,
      overallStress: 5,
    );
    final good = DailyStateEntry(
      date: DateTime(2026, 10, 4),
      physicalCapability: 5,
      mentalCapability: 5,
      emotionalBalance: 5,
      overallRecovery: 5,
      muscularStress: 1,
      lackActivation: 1,
      negativeEmotionalState: 1,
      overallStress: 1,
    );

    expect(
      DailyStateService.recoveryEstimate(rough)!,
      lessThan(DailyStateService.recoveryEstimate(good)!),
    );
  });
}
