"""Build 59 follow-up: real Garmin daily-step snapshots and useful refresh.

Only source and display plumbing changes. Do not modify Garmin GFDI packets,
signing keys, package id, or pre-existing settings keys.
"""
from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    source = p.read_text(encoding='utf-8')
    if new in source:
        return
    n = source.count(old)
    if n != 1:
        raise RuntimeError(f'{path}: expected 1 anchor, got {n}: {old[:100]!r}')
    p.write_text(source.replace(old, new, 1), encoding='utf-8')


direct='lib/services/direct_metric_service.dart'
# The earlier Build 59 fix already collapses BLE daily resting HR. Extend it
# to daily-cumulative step snapshots. Never sum step totals across polls.
replace(direct,
'''      final isDailyResting = sample.sourceId.startsWith('ble:') &&
          sample.metric == 'Resting heart rate';
      final key = isDailyResting
''',
'''      final isDailyResting = sample.sourceId.startsWith('ble:') &&
          (sample.metric == 'Resting heart rate' || sample.metric == 'Steps');
      final key = isDailyResting
''')
replace(direct,
'''      deduped[key] = sample;
    }
    final next = deduped.values.toList()''',
'''      // Garmin Steps is cumulative for the calendar day. A later poll may
      // report the same count; it is not an additional walking event.
      final old = deduped[key];
      if (sample.metric == 'Steps' && old != null &&
          old.value > sample.value) continue;
      deduped[key] = sample;
    }
    final next = deduped.values.toList()''')
replace(direct,
'''    var heartSeries = List<HeartPoint>.from(base.heartSeries);''',
'''    // Garmin direct Steps is a cumulative daily total, not a sequence of
    // individual step events. Use saved snapshots from the chosen device only.
    // Never invent hourly walking activity from an occasional phone poll.
    final stepSource = resolved['Steps'];
    final hasDirectStepSource = stepSource != null && stepSource.startsWith('ble:');
    final stepNow = DateTime.now();
    String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
    final validDirectStepSamples = hasDirectStepSource
        ? direct.where((s) => s.metric == 'Steps' &&
            s.sourceId == stepSource && s.value.isFinite &&
            s.value >= 0 && s.value <= 250000 &&
            !s.capturedAt.isAfter(stepNow)).toList()
        : <DirectMetricSample>[];
    final stepsByDay = <String, int>{};
    for (final s in validDirectStepSamples) {
      final key = dayKey(s.capturedAt);
      final value = s.value.round();
      if (value > (stepsByDay[key] ?? -1)) stepsByDay[key] = value;
    }
    final directStepToday = stepsByDay[dayKey(stepNow)] ?? 0;
    final directDailySteps30 = List<int>.generate(30, (offset) {
      final day = DateTime(stepNow.year, stepNow.month, stepNow.day)
          .subtract(Duration(days: 29 - offset));
      return stepsByDay[dayKey(day)] ?? 0;
    });

    var heartSeries = List<HeartPoint>.from(base.heartSeries);''')
replace(direct,
'''      stepsToday: steps?.value.round(),
      sleepMinutes: sleep?.value.round(),''',
'''      stepsToday: hasDirectStepSource ? directStepToday : steps?.value.round(),
      // Direct snapshots can establish observed daily totals, but not the
      // hourly distribution or a prior year's history. Missing days remain
      // data gaps rather than fabricated counts.
      hourlySteps: hasDirectStepSource ? const [] : base.hourlySteps,
      dailySteps30: hasDirectStepSource ? directDailySteps30 : base.dailySteps30,
      monthlySteps12: hasDirectStepSource ? const [] : base.monthlySteps12,
      sleepMinutes: sleep?.value.round(),''')

# Collapse old duplicate Garmin Steps records at read time, without altering
# Health Connect interval data or live HR samples from any provider.
history='lib/services/metric_history_service.dart'
replace(history,
'''      final isDailyResting = metric == 'Resting heart rate' &&
          sample.sourceId.startsWith('ble:');
      final key = isDailyResting
''',
'''      final isDailyResting =
          (metric == 'Resting heart rate' || metric == 'Steps') &&
          sample.sourceId.startsWith('ble:');
      final key = isDailyResting
''')
replace(history,
'''      unique[key] = sample;
    }
    return unique.values.toList()''',
'''      // Daily step count is cumulative, not additive. Retain the highest
      // observed total for each source/day from legacy poll-heavy history.
      final earlier = unique[key];
      if (metric == 'Steps' && earlier != null &&
          earlier.value > sample.value) continue;
      unique[key] = sample;
    }
    return unique.values.toList()''')

# The Steps detail refresh button currently only reloads SharedPreferences.
# Have it request a real direct-device sync, bypassing the five-minute AUTO
# polling limit for explicitly requested reads, then load saved history.
detail='lib/screens/metric_detail_screen.dart'
replace(detail,
'''import '../state/app_state.dart';''',
'''import '../state/app_state.dart';
import '../state/health_sync_provider.dart';''')
replace(detail,
'''  Future<MetricHistoryResult> _load() => const MetricHistoryService().load(
        widget.metric,
        healthConnectAuthorized: ref.read(appStateProvider).health.authorized,
      );''',
'''  Future<MetricHistoryResult> _load() => const MetricHistoryService().load(
        widget.metric,
        healthConnectAuthorized: ref.read(appStateProvider).health.authorized,
      );

  Future<void> _syncAndLoad() async {
    await ref.read(healthSyncProvider.notifier).sync(forceDirect: true);
    if (!mounted) return;
    setState(() => _future = _load());
  }''')
replace(detail,
'''            onPressed: () => setState(() => _future = _load()),''',
'''            onPressed: _syncAndLoad,''')
replace(detail,
'''                Text(widget.metric == 'Resting heart rate' &&
                        last.sourceId.startsWith('ble:')
                    ? 'Daily resting HR • last synced ${_time(last.capturedAt)} • ${last.deviceName}'
                    : 'Latest • ${_time(last.capturedAt)} • ${last.deviceName}',
''',
'''                Text(last.sourceId.startsWith('ble:') &&
                        (widget.metric == 'Resting heart rate' || widget.metric == 'Steps')
                    ? '${widget.metric == 'Steps' ? 'Observed daily steps' : 'Daily resting HR'} • last synced ${_time(last.capturedAt)} • ${last.deviceName}'
                    : 'Latest • ${_time(last.capturedAt)} • ${last.deviceName}',
''')
replace(detail,
'''                    subtitle: Text(widget.metric == 'Resting heart rate' &&
                            sample.sourceId.startsWith('ble:')
                        ? 'Daily value • last synced ${_time(sample.capturedAt)}'
                        : _time(sample.capturedAt),
''',
'''                    subtitle: Text(sample.sourceId.startsWith('ble:') &&
                            (widget.metric == 'Resting heart rate' || widget.metric == 'Steps')
                        ? 'Daily value • last synced ${_time(sample.capturedAt)}'
                        : _time(sample.capturedAt),
''')

sync='lib/state/health_sync_provider.dart'
replace(sync,
'''  Future<void> sync() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await _sync();''',
'''  Future<void> sync({bool forceDirect = false}) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await _sync(forceDirect: forceDirect);''')
replace(sync,
'''  Future<List<SavedDirectDevice>> _refreshSavedDirectDevices() async {''',
'''  Future<List<SavedDirectDevice>> _refreshSavedDirectDevices({bool force = false}) async {''')
replace(sync,
'''      if (previous != null && now.difference(previous) <
          const Duration(minutes: 5)) continue;''',
'''      if (!force && previous != null && now.difference(previous) <
          const Duration(minutes: 5)) continue;''')
replace(sync,
'''  Future<void> _sync({bool? historyOverride}) async {
    final app = ref.read(appStateProvider);
    final savedDevices = await _refreshSavedDirectDevices();''',
'''  Future<void> _sync({bool? historyOverride, bool forceDirect = false}) async {
    final app = ref.read(appStateProvider);
    final savedDevices = await _refreshSavedDirectDevices(force: forceDirect);''')
replace(sync,
'''    final snapshot = await _service.sync(
      historicalAccess: historyOverride ?? app.health.historicalAccess,
      metricSources: routedSources,
    );''',
'''    // Salus direct BLE works independently of Health Connect authorization.
    // Do not block real Garmin step reads just because a third-party import
    // permission is off. Keep the last-known HC snapshot when disconnected.
    final snapshot = app.health.authorized
        ? await _service.sync(
            historicalAccess: historyOverride ?? app.health.historicalAccess,
            metricSources: routedSources,
          )
        : app.health;''')

home='lib/screens/home_screen.dart'
replace(home,
'''    if (app.health.authorized) {
      await ref.read(healthSyncProvider.notifier).sync();
    } else {
      await ref.read(healthSyncProvider.notifier).connectAndSync();
    }''',
'''    // An explicit Sync always checks saved direct devices; Health Connect
    // permission is managed separately in Connections.
    await ref.read(healthSyncProvider.notifier).sync(forceDirect: true);''')

shell='lib/screens/home_shell.dart'
shell_file = Path(shell)
shell_source = shell_file.read_text(encoding='utf-8')
old_gate = 'if (app.health.authorized && !sync.isLoading) {'
new_gate = 'if (!sync.isLoading) {'
if shell_source.count(old_gate) == 2:
    shell_file.write_text(shell_source.replace(old_gate, new_gate), encoding='utf-8')
elif shell_source.count(old_gate) != 0 or shell_source.count(new_gate) != 2:
    raise RuntimeError('Unexpected HomeShell sync gate state')
replace(shell,
'''      if (app.health.authorized) ref.read(healthSyncProvider.notifier).sync();''',
'''      ref.read(healthSyncProvider.notifier).sync();''')
# Removing authorization gates must also remove unused app reads.
shell_source = shell_file.read_text(encoding='utf-8')
shell_source = shell_source.replace('      final app = ref.read(appStateProvider);\n      final sync =', '      final sync =')
shell_source = shell_source.replace('      final app = ref.read(appStateProvider);\n      ref.read(healthSyncProvider.notifier).sync();', '      ref.read(healthSyncProvider.notifier).sync();')
shell_file.write_text(shell_source, encoding='utf-8')

activity='lib/screens/activity_screen.dart'
replace(activity,
'''import '../state/app_state.dart';''',
'''import '../state/app_state.dart';
import '../state/health_sync_provider.dart';''')
replace(activity,
'''    final health = app.health;
    final goal = app.profile.stepGoal''',
'''    final health = app.health;
    final directStepSource =
        health.resolvedSources['Steps']?.startsWith('ble:') == true;
    final hasSteps = health.authorized || directStepSource;
    final syncState = ref.watch(healthSyncProvider);
    final goal = app.profile.stepGoal''')
replace(activity,
'''        _DateNavigator(label: _dateLabel(now)),''',
'''        Row(children: [
          Expanded(child: _DateNavigator(label: _dateLabel(now))),
          IconButton(
            tooltip: 'Sync steps from connected sources',
            icon: syncState.isLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            onPressed: syncState.isLoading ? null : () =>
                ref.read(healthSyncProvider.notifier).sync(forceDirect: true),
          ),
        ]),''')
replace(activity,
'''                          health.authorized
                              ? compactNumber(health.stepsToday)
                              : '—',''',
'''                          hasSteps ? compactNumber(health.stepsToday) : '—',''')
replace(activity,
'''                  Text(
                    health.authorized ? '${(progress * 100).round()}%' : '—',''',
'''                  Text(
                    hasSteps ? '${(progress * 100).round()}%' : '—',''')
replace(activity,
'''                  value: health.authorized ? progress : 0,''',
'''                  value: hasSteps ? progress : 0,''')
replace(activity,
'''      'Day' => health.hourlySteps,
      'Week' => _tail(health.dailySteps30, 7),
      'Month' => health.dailySteps30,
      _ => health.monthlySteps12,''',
'''      'Day' => directStepSource ? const <int>[] : health.hourlySteps,
      'Week' => _tail(health.dailySteps30, 7),
      'Month' => health.dailySteps30,
      _ => directStepSource ? const <int>[] : health.monthlySteps12,''')
replace(activity,
'''              StepBarChart(
                values: chartValues,''',
'''              if (directStepSource) ...[
                const Text(
                  'Garmin direct sync provides daily step-total snapshots. '
                  'Missing days are unknown; hourly and yearly history are '
                  'not available until imported from a source with timestamps.',
                  style: TextStyle(color: AppTheme.textSecondary,
                      fontSize: 12.5),
                ),
                const SizedBox(height: 10),
              ],
              StepBarChart(
                values: chartValues,''')
# Week bars represent the most recent seven days, which do not necessarily
# begin on Monday. Align labels with actual calendar days.
replace(activity,
'''      return List.generate(count, (i) => days[i % 7]);''',
'''      final firstDay = DateTime.now().subtract(Duration(days: count - 1));
      return List.generate(count, (i) =>
          days[firstDay.add(Duration(days: i)).weekday - 1]);''')
replace(activity,
'''            labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],''',
'''            labels: _labelsFor('Week', _tail(health.dailySteps30, 7).length),''')

print('Build 59 Steps: direct sync independent of HC, force explicit poll, daily snapshots and honest chart coverage.')

# Run #93: remove the two unused local references after switching explicit
# and lifecycle syncs from HC-gated to direct-device aware.
replace('lib/screens/home_screen.dart',
'''  Future<void> _sync(WidgetRef ref) async {
    final app = ref.read(appStateProvider);
    // An explicit Sync''',
'''  Future<void> _sync(WidgetRef ref) async {
    // An explicit Sync''')
shell_file = Path('lib/screens/home_shell.dart')
content = shell_file.read_text(encoding='utf-8')
content = content.replace(
    '    final app = ref.read(appStateProvider);\n    final sync = ref.read(healthSyncProvider);',
    '    final sync = ref.read(healthSyncProvider);')
shell_file.write_text(content, encoding='utf-8')
