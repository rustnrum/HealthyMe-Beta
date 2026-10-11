"""Build 58: recovery consumes selected-source, day-deduped history.

Idempotent overlay applied after the previously validated Build 57 patch.
Do not change the Garmin transport, stored-data format, package id or signing.
"""
from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    source = p.read_text(encoding='utf-8')
    if new in source:
        return
    n = source.count(old)
    if n != 1:
        raise RuntimeError(f'{path}: expected one anchor, found {n}: {old[:110]!r}')
    p.write_text(source.replace(old, new, 1), encoding='utf-8')


# Direct BLE data is already timestamped in SharedPreferences. Use the same
# chosen provider as the displayed value, with a real calendar-day baseline.
# NEVER mix Garmin/QRing/Health Connect just to manufacture enough readings.
direct = 'lib/services/direct_metric_service.dart'
replace(direct,
'''    var heartSeries = List<HeartPoint>.from(base.heartSeries);''',
'''    // Direct-device measurements do not get their 30-day series from
    // Health Connect. Recover saved, timestamped measurements here, grouped
    // by calendar day so repeated polling on one day cannot fake a baseline.
    List<double> directDailySeries(String metric, List<double> hcValues) {
      final source = resolved[metric];
      if (source == null || !source.startsWith('ble:')) return hcValues;
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 30));
      final daily = <DateTime, double>{};
      for (final sample in direct) {
        if (sample.metric != metric || sample.sourceId != source ||
            !sample.value.isFinite || sample.value <= 0 ||
            sample.capturedAt.isBefore(cutoff) ||
            sample.capturedAt.isAfter(now)) continue;
        // Both the input and the output are ordered oldest-to-newest.
        daily[DateTime(sample.capturedAt.year, sample.capturedAt.month,
            sample.capturedAt.day)] = sample.value;
      }
      final ordered = daily.keys.toList()..sort();
      return [for (final day in ordered) daily[day]!];
    }

    var heartSeries = List<HeartPoint>.from(base.heartSeries);''')
replace(direct,
'''      restingHeartRate: restingHeart?.value,
      hrvMs: hrv?.value,''',
'''      restingHeartRate: restingHeart?.value,
      restingHeartRate30: directDailySeries('Resting heart rate', base.restingHeartRate30),
      respiratoryRate30: directDailySeries('Respiratory rate', base.respiratoryRate30),
      hrv30: directDailySeries('HRV', base.hrv30),
      hrvMs: hrv?.value,''')

# Existing metrics remain visible in Recovery even without a full baseline.
recovery = 'lib/services/recovery_service.dart'
replace(recovery,"import '../models/models.dart';",
        "import '../models/models.dart';\nimport '../models/workout_models.dart';")
replace(recovery,
'''  final int weight;

  const RecoveryContributor({''',
'''  final int weight;
  /// Actual latest measured value; displayed even when there is no score.
  final String? reading;

  const RecoveryContributor({''')
replace(recovery,
'''    this.weight = 0,
  });''',
'''    this.weight = 0,
    this.reading,
  });''')
replace(recovery,
'''  static RecoveryReport build(HealthyMeState app) {
    final contributors = <RecoveryContributor>[''',
'''  static RecoveryReport build(HealthyMeState app, {
    List<CompletedPlannedWorkout> completedWorkouts = const [],
  }) {
    final contributors = <RecoveryContributor>[''')
replace(recovery,
'''      _trainingContributor(app.health),''',
'''      _trainingContributor(app.health, completedWorkouts),''')
replace(recovery,
'''    if (current == null || h.hrv30.length < 4) {
      return const RecoveryContributor(
        name: 'HRV',
        score: null,
        detail: 'Building your personal HRV baseline',
        available: false,
        weight: _hrvWeight,
      );
    }''',
'''    if (current == null || h.hrv30.length < 4) {
      return RecoveryContributor(
        name: 'HRV',
        score: null,
        reading: current == null ? null : '${current.round()} ms',
        detail: current == null
            ? 'No HRV value from the selected source'
            : 'Measured HRV available · ${h.hrv30.length} of 4 daily baseline readings. No comparison score yet.',
        available: false,
        weight: _hrvWeight,
      );
    }''')
replace(recovery,
'''    if (baseline <= 0) {
      return const RecoveryContributor(
        name: 'HRV',
        score: null,
        detail: 'Building your personal HRV baseline',
        available: false,
        weight: _hrvWeight,
      );
    }''',
'''    if (baseline <= 0) {
      return RecoveryContributor(
        name: 'HRV', score: null,
        reading: '${current.round()} ms',
        detail: 'HRV baseline could not be calculated from valid historical values',
        available: false, weight: _hrvWeight,
      );
    }''')
replace(recovery,
'''    if (current == null || h.restingHeartRate30.length < 4) {
      return const RecoveryContributor(
        name: 'Resting HR',
        score: null,
        detail: 'Building your resting-HR baseline',
        available: false,
        weight: _rhrWeight,
      );
    }''',
'''    if (current == null || h.restingHeartRate30.length < 4) {
      return RecoveryContributor(
        name: 'Resting HR', score: null,
        reading: current == null ? null : '${current.round()} bpm',
        detail: current == null
            ? 'No resting-heart-rate value from the selected source'
            : 'Measured resting heart rate available · ${h.restingHeartRate30.length} of 4 baseline readings. No comparison score yet.',
        available: false, weight: _rhrWeight,
      );
    }''')
replace(recovery,
'''    if (current == null || h.respiratoryRate30.length < 4) {
      return const RecoveryContributor(
        name: 'Breathing',
        score: null,
        detail: 'Building your respiratory baseline',
        available: false,
        weight: _breathingWeight,
      );
    }''',
'''    if (current == null || h.respiratoryRate30.length < 4) {
      return RecoveryContributor(
        name: 'Breathing', score: null,
        reading: current == null ? null : '${current.toStringAsFixed(1)} br/min',
        detail: current == null
            ? 'No respiratory-rate value from the selected source'
            : 'Measured respiratory rate available · ${h.respiratoryRate30.length} of 4 baseline readings. No comparison score yet.',
        available: false, weight: _breathingWeight,
      );
    }''')
replace(recovery,
'''  static RecoveryContributor _trainingContributor(HealthSnapshot h) {
    if (!h.authorized) {''',
'''  static RecoveryContributor _trainingContributor(
    HealthSnapshot h, List<CompletedPlannedWorkout> completedWorkouts) {
    // A completed Salus workout has exercises and completion time, but no
    // measured duration. Acknowledging it is valid; inventing its training
    // strain in minutes would make Recovery misleading.
    if (!h.authorized && completedWorkouts.isEmpty) {''')
replace(recovery,
'''    if (h.workouts.isEmpty) {
      return const RecoveryContributor(
        name: 'Training load',
        score: null,
        detail: 'No workout history yet',
        available: false,
        weight: _trainingWeight,
      );
    }''',
'''    if (h.workouts.isEmpty) {
      if (completedWorkouts.isNotEmpty) {
        return RecoveryContributor(
          name: 'Training load', score: null,
          reading: '${completedWorkouts.length} saved',
          detail: '${completedWorkouts.length} completed Salus workout(s) found. Duration is not recorded, so training strain is not guessed.',
          available: false, weight: _trainingWeight,
        );
      }
      return const RecoveryContributor(
        name: 'Training load', score: null,
        detail: 'No workout history yet',
        available: false, weight: _trainingWeight,
      );
    }''')

# Share the same in-memory workout history with home + Recovery details.
replace('lib/screens/home_screen.dart',
'''    final recovery = RecoveryService.build(app);''',
'''    final recovery = RecoveryService.build(app,
        completedWorkouts: ref.watch(workoutStateProvider).history);''')
replace('lib/screens/recovery_detail_screen.dart',
'''import '../state/app_state.dart';''',
'''import '../state/app_state.dart';
import '../state/workout_state.dart';''')
replace('lib/screens/recovery_detail_screen.dart',
'''    final report = RecoveryService.build(app);''',
'''    final report = RecoveryService.build(app,
        completedWorkouts: ref.watch(workoutStateProvider).history);''')
replace('lib/screens/recovery_detail_screen.dart',
'''                      score == null ? 'N/A' : '$score%',''',
'''                      score == null ? (item.reading ?? 'N/A') : '$score%',''')

replace('pubspec.yaml', 'version: 0.21.19+57', 'version: 0.21.20+58')
# Existing source contract tests should remain valid on the new version.
for path in Path('test').glob('*.dart'):
    old = path.read_text(encoding='utf-8')
    new = old.replace('version: 0.21.19+57', 'version: 0.21.20+58')
    if old != new:
        path.write_text(new, encoding='utf-8')

print('Build 58: real BLE day-history series, visible unscored measurements, stored workouts, source-safe recovery.')
