import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/direct_metric_service.dart';
import 'package:healthy_me/services/salus_temperature_service.dart';
import 'package:healthy_me/services/salus_backup_service.dart';

void main() {
  DirectMetricSample sample(String metric, double value, DateTime at,
      {String source = 'ble:ring'}) => DirectMetricSample(
        sourceId: source, deviceId: source, deviceName: 'Ring',
        metric: metric, value: value, unit: '°C', capturedAt: at);

  test('rejects invented, physiologically impossible temperature samples', () {
    final t = DateTime(2026, 10, 12);
    final items = SalusTemperatureService.distinct([
      sample('Skin temperature', 33.0, t),
      sample('Skin temperature', 33.0, t),
      sample('Skin temperature', 102, t),
      sample('Body temperature', 37.0, t),
      sample('Skin temperature delta', -0.5, t),
      sample('Skin temperature', double.nan, t),
    ]);
    expect(items.length, 3);
    expect(items.where((s) => s.metric == 'Skin temperature').length, 1);
  });

  test('requires four days and preserves source isolation for baseline trend', () {
    final d = DateTime(2026, 10, 12);
    expect(SalusTemperatureService.baselineDelta([
      for (var i = 0; i < 3; i++) sample('Skin temperature', 32 + i.toDouble(), d.add(Duration(days: i))),
    ]), isNull);
    final baseline = SalusTemperatureService.baselineDelta([
      for (var i = 0; i < 3; i++) sample('Skin temperature', 32, d.add(Duration(days: i))),
      sample('Skin temperature', 33, d.add(const Duration(days: 3))),
    ]);
    expect(baseline, closeTo(1.0, .0001));
  });

  test('backup excludes credentials and respects preference types', () {
    expect(SalusBackupService.includedKey('salus_diet_log_v1'), true);
    expect(SalusBackupService.includedKey('salus_direct_metric_samples_v1'), true);
    expect(SalusBackupService.includedKey('salus_oauth_token'), false);
    expect(SalusBackupService.includedKey('another_app_account'), false);
    expect(SalusBackupService.validPreference({'type': 'strings', 'value': ['one', 'two']}), true);
    expect(SalusBackupService.validPreference({'type': 'strings', 'value': ['ok', 2]}), false);
    expect(SalusBackupService.validPreference({'type': 'double', 'value': double.nan}), false);
  });
}
