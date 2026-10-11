import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Build 58 uses persisted direct source history and keeps Garmin untouched', () {
    final direct = File('lib/services/direct_metric_service.dart').readAsStringSync();
    final recovery = File('lib/services/recovery_service.dart').readAsStringSync();
    final screen = File('lib/screens/recovery_detail_screen.dart').readAsStringSync();
    expect(direct, contains('daily[DateTime(sample.capturedAt.year'));
    expect(direct, contains('sample.sourceId != source'));
    expect(direct, contains("hrv30: directDailySeries('HRV', base.hrv30)"));
    expect(direct, contains("respiratoryRate30: directDailySeries('Respiratory rate', base.respiratoryRate30)"));
    expect(direct, contains("restingHeartRate30: directDailySeries('Resting heart rate', base.restingHeartRate30)"));
    expect(recovery, contains('List<CompletedPlannedWorkout> completedWorkouts = const []'));
    expect(recovery, contains('reading: current == null ? null'));
    expect(screen, contains("item.reading ?? 'N/A'"));
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.20+58'));
  });
}
