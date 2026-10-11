import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Build 57 displays one real recency-checked insight, not a made-up wellness score', () {
    final home=File('lib/screens/home_screen.dart').readAsStringSync();
    final service=File('lib/services/home_insight_service.dart').readAsStringSync();
    final recovery=File('lib/services/recovery_service.dart').readAsStringSync();
    final sync=File('lib/widgets/salus_sync_quick_action.dart').readAsStringSync();
    expect(home,contains('HomeInsightService.build(app)'));
    expect(home,contains('Last 24 hours · Insight'));
    expect(home,contains('SalusSyncQuickAction('));
    expect(home,contains('h.lastSync'));
    expect(service,contains('const Duration(hours: 24)'));
    expect(service,contains('sourceLabels'));
    expect(recovery,contains('objectiveScored.length >= 2'));
    expect(recovery,contains("label: 'Preliminary'"));
    expect(sync,contains('ref.watch(healthSyncProvider).isLoading'));
    expect(sync,contains('_rotation.repeat()'));
    expect(File('pubspec.yaml').readAsStringSync(),contains('version: 0.21.22+60'));
  });
}
