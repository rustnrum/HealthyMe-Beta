import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/recovery_service.dart';
import 'package:healthy_me/services/salus_energy_service.dart';
import 'package:healthy_me/state/app_state.dart';

void main() {
  test('A single good night of sleep cannot create an energy number', () {
    final now = DateTime(2026, 10, 12, 12);
    final report = SalusEnergyService.estimate(
      HealthSnapshot(sleepMinutes: 480,
        freshness: {'Sleep': now}),
      const UserProfile(), now: now);
    expect(report.score, isNull);
    expect(report.missing, contains('Resting HR baseline'));
  });

  test('Energy uses source-independent health data and remains provisional', () {
    final now = DateTime(2026, 10, 12, 12);
    final report = SalusEnergyService.estimate(
      HealthSnapshot(
        sleepMinutes: 480, restingHeartRate: 57,
        restingHeartRate30: const [61, 62, 57],
        stepsToday: 3300,
        resolvedSources: const {
          'Sleep':'com.healthconnect.watch',
          'Resting heart rate':'com.some.other.watch',
          'Steps':'com.android.fitness',
        },
        freshness: {'Sleep':now, 'Resting heart rate':now, 'Steps':now},
      ),
      const UserProfile(stepGoal:10000), now:now);
    expect(report.score, isNotNull);
    expect(report.score!, inInclusiveRange(5,100));
    expect(report.coverage, 70);
    expect(report.score!, lessThan(80), reason: 'Three-day baselines should not imply certainty');
    expect(report.quality, 'Provisional estimate');
    expect(report.missing, contains('HRV baseline'));
  });

  test('Stale measurements do not create a plausible-looking energy score', () {
    final now = DateTime(2026,10,12,12);
    final report = SalusEnergyService.estimate(
      HealthSnapshot(
        sleepMinutes:480, restingHeartRate:59,
        restingHeartRate30:const [61,60,59],
        freshness:{
          'Sleep':now.subtract(const Duration(days:5)),
          'Resting heart rate':now.subtract(const Duration(days:5)),
        }), const UserProfile(), now:now);
    expect(report.score, isNull);
  });

  test('Three RHR readings and sleep give preliminary Recovery, not full coverage', () {
    // Age is required for evidence-based sleep guidance. Without a birthday
    // Recovery correctly excludes sleep instead of assigning a guessed target.
    final report = RecoveryService.build(HealthyMeState(
      profile: UserProfile(birthday: DateTime(1972, 1, 1)),
      health: const HealthSnapshot(sleepMinutes:495,
        restingHeartRate:57,restingHeartRate30:[61,62,57]),
    ));
    expect(report.label, 'Preliminary');
    expect(report.score, isNotNull);
    expect(report.confidence, 45);
    expect(report.score!, lessThan(80), reason: 'Preliminary score needs confidence shrinkage');
  });

  test('The mountain art and cross-device Salus Energy are part of Home', () {
    final home = File('lib/screens/premium/salus_home_77.dart').readAsStringSync();
    expect(home, contains('SalusMountainBackdrop('));
    expect(File('lib/widgets/salus77_design.dart').readAsStringSync(), contains('salus_mountain_79.webp'));
    expect(home, contains('SalusEnergyService.estimate'));
    expect(home, isNot(contains("s.metric == 'Body battery'")));
    expect(home, contains("'Salus Energy'"));
    expect(home, contains('Activity Load'));
    expect(File('assets/premium/salus_mountain_79.webp').lengthSync(), greaterThan(10000));
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.48+86'));
  });

  test('A profile without age does not invent an adult sleep score', () {
    final report = RecoveryService.build(HealthyMeState(
      profile: UserProfile(),
      health: HealthSnapshot(sleepMinutes:495,
        restingHeartRate:57,restingHeartRate30:[61,62,57]),
    ));
    expect(report.score, isNull);
    expect(report.label, 'Building');
    final sleep = report.contributors.firstWhere((c) => c.name == 'Sleep');
    expect(sleep.available, isFalse);
  });
}
