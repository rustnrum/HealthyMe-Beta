"""Build 59: avoid repeated Garmin daily resting-HR rows and timestamps.

Use one latest-observed BLE resting-heart-rate value per device per calendar
 day, while preserving normal heart-rate time-series and multi-provider data.
 Existing values are not changed, nor is the local storage schema/key.
"""
from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    content = p.read_text(encoding='utf-8')
    if new in content:
        return
    n = content.count(old)
    if n != 1:
        raise RuntimeError(f'{path}: expected 1 replacement anchor, got {n}: {old[:110]!r}')
    p.write_text(content.replace(old, new, 1), encoding='utf-8')


# During each Garmin BLE poll, native code returns the current daily RHR field.
# It has no individual measurement timestamp. Re-polling that daily value must
# not create fake distinct samples. Collapse prior stored duplicates on the
# next successful write, preserving only the latest value per day/source.
replace('lib/services/direct_metric_service.dart',
'''      final key = '${sample.sourceId}|${sample.metric}|'
          '${sample.capturedAt.millisecondsSinceEpoch}';''',
'''      // BLE resting heart rate is a daily summary, not the live pulse.
      // Poll time is last observed, never a new independent RHR measurement.
      final isDailyResting = sample.sourceId.startsWith('ble:') &&
          sample.metric == 'Resting heart rate';
      final key = isDailyResting
          ? '${sample.sourceId}|${sample.metric}|'
              '${sample.capturedAt.year}-${sample.capturedAt.month}-${sample.capturedAt.day}'
          : '${sample.sourceId}|${sample.metric}|'
              '${sample.capturedAt.millisecondsSinceEpoch}';''')

# Read-time grouping removes existing duplicate rows even before the next BLE
# sync. Sort first so the latest received value survives within each date.
replace('lib/services/metric_history_service.dart',
'''    final unique = <String, DirectMetricSample>{};
    for (final sample in samples) {''',
'''    final unique = <String, DirectMetricSample>{};
    final ordered = samples.toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    for (final sample in ordered) {''')
replace('lib/services/metric_history_service.dart',
'''      final key = '${sample.sourceId}|${sample.capturedAt.millisecondsSinceEpoch}|${sample.value}';''',
'''      final isDailyResting = metric == 'Resting heart rate' &&
          sample.sourceId.startsWith('ble:');
      final key = isDailyResting
          ? '${sample.sourceId}|${sample.capturedAt.year}-${sample.capturedAt.month}-${sample.capturedAt.day}'
          : '${sample.sourceId}|${sample.capturedAt.millisecondsSinceEpoch}|${sample.value}';''')

# The Garmin reader does not supply the time at which the watch determined
# resting HR. Do not label the last BLE polling time as measurement time.
replace('lib/screens/metric_detail_screen.dart',
'''                Text('Latest • ${_time(last.capturedAt)} • ${last.deviceName}',
                    style: const TextStyle(color: AppTheme.textSecondary,
                        fontSize: 12.5)),''',
'''                Text(widget.metric == 'Resting heart rate' &&
                        last.sourceId.startsWith('ble:')
                    ? 'Daily resting HR • last synced ${_time(last.capturedAt)} • ${last.deviceName}'
                    : 'Latest • ${_time(last.capturedAt)} • ${last.deviceName}',
                    style: const TextStyle(color: AppTheme.textSecondary,
                        fontSize: 12.5)),''')
replace('lib/screens/metric_detail_screen.dart',
'''                    subtitle: Text(_time(sample.capturedAt),
                        style: const TextStyle(color: AppTheme.textSecondary)),''',
'''                    subtitle: Text(widget.metric == 'Resting heart rate' &&
                            sample.sourceId.startsWith('ble:')
                        ? 'Daily value • last synced ${_time(sample.capturedAt)}'
                        : _time(sample.capturedAt),
                        style: const TextStyle(color: AppTheme.textSecondary)),''')

replace('pubspec.yaml', 'version: 0.21.20+58', 'version: 0.21.21+59')
for path in Path('test').glob('*.dart'):
    before = path.read_text(encoding='utf-8')
    after = before.replace('version: 0.21.20+58', 'version: 0.21.21+59')
    if before != after:
        path.write_text(after, encoding='utf-8')
print('Build 59: BLE daily-RHR history correctly grouped by source/date; normal HR time-series preserved.')
