"""Build 61: real COLMI sleep window + ring nightly history + safety fixes.

Applied after the validated Build 60 code. Keep Garmin notification transport,
app ID, signing certificate, and existing history storage keys untouched.
"""
from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    if new in s:
        return
    count = s.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one matching source anchor, got {count}: {old[:85]!r}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')


reader = 'native/android/SalusProtocolReader.kt'
# Daily ring history dates belong to midnight, not a future noon timestamp.
replace(reader,
'''        private fun dayTimestamp(daysAgo: Int): Long {
            val calendar = Calendar.getInstance()
            calendar.set(Calendar.HOUR_OF_DAY, 12)''',
'''        private fun dayTimestamp(daysAgo: Int): Long {
            val calendar = Calendar.getInstance()
            calendar.set(Calendar.HOUR_OF_DAY, 0)''')
replace(reader,
'''        val asleep = light + deep + rem
        if (asleep > 0) {
            val captured = dayTimestamp(daysAgo)''',
'''        val asleep = light + deep + rem
        if (asleep > 0) {
            // The R02 sleep record has SIGNED minute offsets in bytes 2..5:
            // sleep start relative to the day and wake time relative to the
            // same midnight. These are not packet receipt timestamps.
            if (recordBytes >= 4) {
                val startOffset = u16(payload, pointer + 2).toShort().toInt()
                val endOffset = u16(payload, pointer + 4).toShort().toInt()
                val elapsed = endOffset - startOffset
                if (startOffset in -1440..1440 && endOffset in -120..2880 &&
                    elapsed in 30..1200) {
                    val midnight = Calendar.getInstance().apply {
                        timeInMillis = dayTimestamp(daysAgo)
                        set(Calendar.HOUR_OF_DAY, 0)
                        set(Calendar.MINUTE, 0)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }
                    val startTime = (midnight.clone() as Calendar).apply {
                        add(Calendar.MINUTE, startOffset)
                    }.timeInMillis
                    val endTime = (midnight.clone() as Calendar).apply {
                        add(Calendar.MINUTE, endOffset)
                    }.timeInMillis
                    if (startTime > 0 && endTime > startTime &&
                        endTime <= System.currentTimeMillis() + 300000L) {
                        addHistoryMetric("Sleep start", 1.0, startTime)
                        addHistoryMetric("Sleep end", 1.0, endTime)
                    }
                }
            }
            val captured = dayTimestamp(daysAgo)''')
# Don't re-date a historical sleep night every time the user syncs the ring.
# Keep live pulse data intact.
direct = 'lib/services/direct_metric_service.dart'
replace(direct,
'''      for (final entry in metrics.entries) {
        current.add(DirectMetricSample(''',
'''      for (final entry in metrics.entries) {
        // The COLMI BigData response already supplies the actual night's
        // calendar date. Re-labeling it with the poll time is misleading.
        if ((entry.key == 'Sleep' || entry.key == 'Sleep light' ||
             entry.key == 'Sleep deep' || entry.key == 'Sleep REM' ||
             entry.key == 'Sleep awake') &&
            history.any((item) => item.metric == entry.key)) continue;
        current.add(DirectMetricSample(''')
replace(direct,
'''    var heartSeries = List<HeartPoint>.from(base.heartSeries);''',
'''    // COLMI ring BigData includes multiple dated nights. Recover its
    // seven-day duration chart from saved nights of the selected provider,
    // not Health Connect's unrelated source. Zero bars indicate no reading,
    // never an inferred zero-hour night.
    final sleepSource = resolved['Sleep'];
    final directSleepSelected = sleepSource?.startsWith('ble:') == true;
    final directSleepDays = <String, int>{};
    if (directSleepSelected) {
      for (final sample in direct) {
        if (sample.sourceId != sleepSource || sample.metric != 'Sleep' ||
            !sample.value.isFinite || sample.value <= 0 ||
            sample.value > 1440 || sample.capturedAt.isAfter(stepNow)) continue;
        final day = dayKey(sample.capturedAt);
        directSleepDays[day] = sample.value.round();
      }
    }
    final directSleepMinutes7 = List<int>.generate(7, (i) {
      final date = DateTime(stepNow.year, stepNow.month, stepNow.day)
          .subtract(Duration(days: 6 - i));
      return directSleepDays[dayKey(date)] ?? 0;
    });

    var heartSeries = List<HeartPoint>.from(base.heartSeries);''')
replace(direct,
'''      sleepMinutes: sleep?.value.round(),
      sleepLightMinutes:''',
'''      sleepMinutes: sleep?.value.round(),
      sleepMinutes7: directSleepSelected ? directSleepMinutes7 : base.sleepMinutes7,
      sleepLightMinutes:''')
replace(direct,
'''      activeCaloriesToday: activeCalories?.value,''',
'''      // A daily 89,620-kcal reading is not plausible. Do not present raw
      // corrupted/incorrectly-scaled device data as actual energy expenditure.
      activeCaloriesToday: activeCalories != null &&
              activeCalories.value >= 0 && activeCalories.value <= 15000
          ? activeCalories.value
          : (base.activeCaloriesToday >= 0 && base.activeCaloriesToday <= 15000
              ? base.activeCaloriesToday : 0),''')
# Build61 sleep window reader consumes the real timestamps saved by ring parser.
sleep = 'lib/screens/sleep_screen.dart'
replace(sleep,
'''import '../services/sleep_guidance_service.dart';''',
'''import '../services/sleep_guidance_service.dart';
import '../services/direct_metric_service.dart';
import '../services/sleep_window_service.dart';''')
replace(sleep,
'''        const SizedBox(height: 12),
        if (_range == 'Day') ...[''',
'''        const SizedBox(height: 12),
        if (_range == 'Day' && sleepSourceKey?.startsWith('ble:') == true) ...[
          CommandCard(
            child: FutureBuilder<List<DirectMetricSample>>(
              future: const DirectMetricService().loadSamples(),
              builder: (context, snapshot) {
                final window = SleepWindowService.latest(
                    snapshot.data ?? const <DirectMetricSample>[], sleepSourceKey!);
                String time(DateTime date) =>
                    '${date.month}/${date.day} · ${TimeOfDay.fromDateTime(date).format(context)}';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sleep and wake times', style: TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w800,
                        fontSize: 17)),
                    const SizedBox(height: 7),
                    if (window == null)
                      const Text('Sleep times are not in earlier Salus records. '
                          'They will appear after the next successful COLMI sleep sync '
                          'if the ring supplies valid start/end times.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
                    else ...[
                      Text('Sleep started  ${time(window.start)}',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                      const SizedBox(height: 5),
                      Text('Woke up           ${time(window.end)}',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                      const SizedBox(height: 7),
                      const Text('Ring-detected sleep period; not a clinical measure '
                          'of the exact moment sleep began.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_range == 'Day') ...[''')
# Correct rolling 7-day labels: not every last-seven-day window begins Monday.
replace(sleep,
'''
                  labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],''',
'''
                  labels: _recentDayLabels(),''')
replace(sleep,
'''
            labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],''',
'''
            labels: _recentDayLabels(),''')
replace(sleep,
'''  String _insight(int tonight, int average, int target) {''',
'''  List<String> _recentDayLabels() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now();
    return List.generate(7, (i) => labels[
      today.subtract(Duration(days: 6 - i)).weekday - 1]);
  }

  String _insight(int tonight, int average, int target) {''')
# Show daily totals as snapshots, not live stats, and reject obviously invalid
# calorie metrics on Activity until the provider/units can be verified.
activity = 'lib/screens/activity_screen.dart'
replace(activity,
'''    final stepFreshness = health.freshness['Steps'];''',
'''    final stepFreshness = health.freshness['Steps'];
    final stepIsStale = directStepSource && stepFreshness != null &&
        DateTime.now().difference(stepFreshness) > const Duration(hours: 1);
    final caloriesPlausible = health.activeCaloriesToday >= 0 &&
        health.activeCaloriesToday <= 15000;''')
replace(activity,
'''                        if (stepFreshness != null) ...[
                          const SizedBox(height: 2),''',
'''                        if (stepIsStale) ...[
                          const SizedBox(height: 4),
                          const Text('Last saved Garmin total — not current',
                              style: TextStyle(color: AppTheme.amber,
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                        if (stepFreshness != null) ...[
                          const SizedBox(height: 2),''')
replace(activity,
'''                value: health.authorized
                    ? '${health.activeCaloriesToday.round()} cal'
                    : '—',''',
'''                value: health.authorized && caloriesPlausible
                    ? '${health.activeCaloriesToday.round()} cal'
                    : '—',''')
replace(activity,
'''        const SizedBox(height: 24),
        HmSectionHeader(
          title: 'Workouts',''',
'''        if (!caloriesPlausible) ...[
          const SizedBox(height: 8),
          const Text('Active-calorie data is outside a plausible daily range '
              'and is hidden pending source verification.',
              style: TextStyle(color: AppTheme.amber, fontSize: 12)),
        ],
        const SizedBox(height: 24),
        HmSectionHeader(
          title: 'Workouts',''')
# The native ring can report large values from an unsupported/incorrect
# calorie format. Never add these to the visible direct metrics.
replace(reader,
'''                            if (ringCaloriesTotal > 0) {
                                metrics["Active calories"] =
                                    ringCaloriesTotal.toDouble()
                            }''',
'''                            if (ringCaloriesTotal in 1..15000) {
                                metrics["Active calories"] =
                                    ringCaloriesTotal.toDouble()
                            } else if (ringCaloriesTotal > 15000) {
                                notes.add("Ring calorie total is implausible; omitting unverified value")
                            }''')
# The committed repo version is always bumped precisely once.
replace('pubspec.yaml', 'version: 0.21.22+60', 'version: 0.21.23+61')
for path in Path('test').glob('*.dart'):
    s = path.read_text(encoding='utf-8')
    new = s.replace('version: 0.21.22+60', 'version: 0.21.23+61')
    if s != new:
        path.write_text(new, encoding='utf-8')
print('Build 61: real COLMI sleep times, saved ring seven-day sleep history, stale Garmin Steps warning, invalid calorie guard')
