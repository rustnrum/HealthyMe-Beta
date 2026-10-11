import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/home_insight_service.dart';
import 'package:healthy_me/services/recovery_service.dart';
import 'package:healthy_me/state/app_state.dart';

void main() {
  final clock = DateTime(2026, 10, 11, 12, 0);

  test('fresh sleep produces grounded one-card advice with origin', () {
    final insight = HomeInsightService.build(
      HealthyMeState(
        profile: UserProfile(birthday: DateTime(1972, 1, 1)),
        health: HealthSnapshot(
          sleepMinutes: 300,
          freshness: {'Sleep': clock.subtract(const Duration(hours: 5))},
          resolvedSources: const {'Sleep': 'com.watch.source'},
          sourceLabels: const {'com.watch.source': 'Watch'},
        ),
      ),
      now: clock,
    );
    expect(insight.hasFreshData, isTrue);
    expect(insight.message, contains('age-based minimum'));
    expect(insight.source, contains('Watch'));
  });

  test('stale 26-hour measurement is NEVER presented as last 24 hours', () {
    final insight = HomeInsightService.build(
      HealthyMeState(
        profile: UserProfile(birthday: DateTime(1972, 1, 1)),
        health: HealthSnapshot(
          sleepMinutes: 200,
          hrvMs: 22,
          freshness: {
            'Sleep': clock.subtract(const Duration(hours: 26)),
            'HRV': clock.subtract(const Duration(hours: 26)),
          },
        ),
      ),
      now: clock,
    );
    expect(insight.hasFreshData, isFalse);
    expect(insight.message, contains('No fresh'));
  });

  test('HRV low relative to past readings only if timestamp recent', () {
    final insight = HomeInsightService.build(
      HealthyMeState(
        health: HealthSnapshot(
          hrvMs: 24,
          hrv30: const [40, 41, 39, 40, 38, 40, 24],
          freshness: {'HRV': clock.subtract(const Duration(hours: 1))},
        ),
      ), now: clock,
    );
    expect(insight.message, contains('HRV is lower'));
  });

  test('single sleep signal stays unscored to avoid fabricated high recovery', () {
    final report = RecoveryService.build(
      HealthyMeState(
        profile: UserProfile(birthday: DateTime(1972, 1, 1)),
        health: const HealthSnapshot(sleepMinutes: 480),
      ),
    );
    expect(report.score, isNull);
    expect(report.confidence, 35);
    expect(report.summary, contains('35%'));
  });

  test('two independent real recovery signals can create labelled preliminary estimate', () {
    final report = RecoveryService.build(
      HealthyMeState(
        profile: UserProfile(birthday: DateTime(1972, 1, 1)),
        health: const HealthSnapshot(
          sleepMinutes: 420,
          respiratoryRate: 14,
          respiratoryRate30: [14, 14, 14, 14],
        ),
      ),
    );
    expect(report.score, isNotNull);
    expect(report.label, 'Preliminary');
    expect(report.confidence, 45);
    expect(report.summary, contains('Preliminary'));
  });
}
