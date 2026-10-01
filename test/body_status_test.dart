import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/body_status_service.dart';
import 'package:healthy_me/state/app_state.dart';

void main() {
  test('empty state reports limited data instead of pretending body is good', () {
    final report = BodyStatusService.build(const HealthyMeState());
    expect(report.overall, 'Limited data');
  });

  test('labs use freshness rather than interpreting the numeric result', () {
    final now = DateTime.now();
    final report = BodyStatusService.build(
      HealthyMeState(
        labs: [
          LabResult(
            id: '1',
            name: 'A1C',
            value: '5.4',
            unit: '%',
            date: now.subtract(const Duration(days: 30)),
          ),
        ],
      ),
    );

    final labs = report.systems.firstWhere((item) => item.name == 'Labs');
    expect(labs.level, StatusLevel.good);
  });

  test('body trend is green only when weight moves toward a lower goal', () {
    final now = DateTime.now();
    final state = HealthyMeState(
      profile: const UserProfile(goalWeightLb: 150),
      manualWeights: [
        WeightPoint(
          date: now.subtract(const Duration(days: 7)),
          pounds: 200,
          source: 'Manual',
        ),
        WeightPoint(date: now, pounds: 198.8, source: 'Manual'),
      ],
    );
    final trend = BodyStatusService.weightTrend(state);
    expect(trend.level, StatusLevel.good);
    expect(trend.weeklyDeltaLb, closeTo(-1.2, 0.01));
  });

  test('body trend turns watch when weight moves away from lower goal', () {
    final now = DateTime.now();
    final state = HealthyMeState(
      profile: const UserProfile(goalWeightLb: 150),
      manualWeights: [
        WeightPoint(
          date: now.subtract(const Duration(days: 7)),
          pounds: 200,
          source: 'Manual',
        ),
        WeightPoint(date: now, pounds: 201, source: 'Manual'),
      ],
    );
    final trend = BodyStatusService.weightTrend(state);
    expect(trend.level, StatusLevel.watch);
  });
}
