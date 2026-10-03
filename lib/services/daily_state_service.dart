import '../models/daily_state.dart';
import '../state/app_state.dart';

class DailyStateBaseline {
  final double recovery;
  final double stress;
  final int days;

  const DailyStateBaseline({
    required this.recovery,
    required this.stress,
    required this.days,
  });
}

class DailyStateService {
  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DailyStateEntry? entryForDay(
    List<DailyStateEntry> entries,
    DateTime day,
  ) {
    final key = dayKey(day);
    for (final entry in entries.reversed) {
      if (entry.dayKey == key) return entry;
    }
    return null;
  }

  static DailyStateEntry? today(HealthyMeState app, {DateTime? now}) =>
      entryForDay(app.dailyStates, now ?? DateTime.now());

  static bool isDue(HealthyMeState app, {DateTime? now}) {
    if (!app.dailyStateEnabled || !app.profile.completed) return false;
    final moment = now ?? DateTime.now();
    final minutes = moment.hour * 60 + moment.minute;
    if (minutes < app.dailyStateStartMinutes) return false;
    return entryForDay(app.dailyStates, moment) == null;
  }

  static DailyStateBaseline? baseline(
    HealthyMeState app, {
    DateTime? before,
  }) {
    final cutoff = before ?? DateTime.now();
    final key = dayKey(cutoff);
    final completed = app.dailyStates
        .where((entry) =>
            entry.isCompleted &&
            entry.dayKey != key &&
            entry.recoveryAverage != null &&
            entry.stressAverage != null)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (completed.length < 7) return null;
    final sample = completed.take(28).toList();
    final recovery = sample
            .map((entry) => entry.recoveryAverage!)
            .reduce((a, b) => a + b) /
        sample.length;
    final stress = sample
            .map((entry) => entry.stressAverage!)
            .reduce((a, b) => a + b) /
        sample.length;
    return DailyStateBaseline(
      recovery: recovery,
      stress: stress,
      days: sample.length,
    );
  }

  /// Healthy Me's transparent conversion for blending subjective Daily State
  /// into the app's existing 0-100 wellness recovery estimate. This is not an
  /// official score from SRSS or any diagnostic instrument.
  static int? recoveryEstimate(DailyStateEntry? entry) {
    final recovery = entry?.recoveryAverage;
    final stress = entry?.stressAverage;
    if (recovery == null || stress == null) return null;
    final recoveryPart = recovery / 6 * 100;
    final lowStressPart = (6 - stress) / 6 * 100;
    return (recoveryPart * 0.60 + lowStressPart * 0.40)
        .round()
        .clamp(0, 100)
        .toInt();
  }

  static String baselineComparison(
    HealthyMeState app,
    DailyStateEntry entry,
  ) {
    final recovery = entry.recoveryAverage;
    final stress = entry.stressAverage;
    if (recovery == null || stress == null) return 'No completed check-in today.';
    final base = baseline(app, before: entry.date);
    if (base == null) {
      final completed = app.dailyStates.where((e) => e.isCompleted).length;
      final remaining = (7 - completed).clamp(0, 7);
      return remaining == 0
          ? 'Your personal baseline is ready after the next saved day.'
          : 'Building your personal baseline • $remaining more day${remaining == 1 ? '' : 's'} needed.';
    }

    final recDelta = recovery - base.recovery;
    final stressDelta = stress - base.stress;
    String recText;
    if (recDelta.abs() < 0.35) {
      recText = 'recovery near your normal';
    } else {
      recText = 'recovery ${recDelta > 0 ? 'above' : 'below'} your normal';
    }
    String stressText;
    if (stressDelta.abs() < 0.35) {
      stressText = 'stress near your normal';
    } else {
      stressText = 'stress ${stressDelta > 0 ? 'above' : 'below'} your normal';
    }
    return '$recText • $stressText';
  }

  static String suggestedReset(DailyStateEntry entry) {
    if (!entry.isCompleted) return '';
    if ((entry.lackActivation ?? 0) >= 4) {
      return 'Try a 10-minute walk, then check whether your energy or drive changed.';
    }
    if ((entry.overallStress ?? 0) >= 4 ||
        (entry.negativeEmotionalState ?? 0) >= 4) {
      return 'Try 5 minutes of slow breathing or quiet mindfulness, then reassess how you feel.';
    }
    if ((entry.muscularStress ?? 0) >= 4 ||
        (entry.overallRecovery ?? 6) <= 2) {
      return 'Consider a lighter workout or recovery-focused session rather than forcing full intensity.';
    }
    if ((entry.mentalCapability ?? 6) <= 2 ||
        (entry.emotionalBalance ?? 6) <= 2) {
      return 'Take a short mental reset before training and choose a simple, achievable first step.';
    }
    return 'Your check-in does not flag a strong subjective barrier. Follow the planned day and adjust if your body says otherwise.';
  }
}
