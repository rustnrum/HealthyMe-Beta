import '../state/app_state.dart';
import 'daily_state_service.dart';
import 'sleep_guidance_service.dart';

/// One short evidence-backed observation. A reading is never labelled a
/// 24-hour observation unless its source timestamp is within that window.
class HomeInsight {
  final String message;
  final String source;
  final bool hasFreshData;

  const HomeInsight({
    required this.message,
    required this.source,
    required this.hasFreshData,
  });
}

class HomeInsightService {
  const HomeInsightService._();

  static HomeInsight build(HealthyMeState app, {DateTime? now}) {
    final moment = now ?? DateTime.now();
    final h = app.health;

    bool fresh(String metric) {
      final recorded = h.freshness[metric];
      if (recorded == null) return false;
      final age = moment.difference(recorded);
      return !age.isNegative && age <= const Duration(hours: 24);
    }

    String source(String metric) {
      final id = h.resolvedSources[metric];
      if (id == null || id.isEmpty) return 'Recorded $metric';
      final label = h.sourceLabels[id];
      return (label != null && label.trim().isNotEmpty) ? label : id;
    }

    // Subjective reports are explicitly distinguished from wearable readings.
    final daily = DailyStateService.today(app, now: moment);
    if (daily?.isCompleted == true) {
      final stress = daily!.stressAverage;
      final recovery = daily.recoveryAverage;
      if ((stress != null && stress >= 4.0) ||
          (recovery != null && recovery <= 2.5)) {
        return const HomeInsight(
          message: 'Your check-in suggests a tougher day. Consider a short break or an easier workout.',
          source: 'Today\'s self-reported check-in',
          hasFreshData: true,
        );
      }
    }

    if (fresh('Sleep') && h.sleepMinutes > 0) {
      final recommended = SleepGuidanceService.forAge(app.profile.age).minimumMinutes;
      if (recommended > 0 && h.sleepMinutes < recommended - 60) {
        final shortfall = (recommended - h.sleepMinutes) ~/ 60;
        return HomeInsight(
          message: 'Your last sleep was below the age-based minimum. Consider a gentler day and a consistent bedtime.',
          source: '${source('Sleep')} · ${h.sleepMinutes ~/ 60}h ${h.sleepMinutes % 60}m sleep · about $shortfall h short',
          hasFreshData: true,
        );
      }
    }

    if (fresh('HRV') && h.hrvMs != null && h.hrv30.length >= 5) {
      final history = h.hrv30.sublist(0, h.hrv30.length - 1)
          .where((v) => v > 0 && v.isFinite).toList();
      if (history.length >= 4) {
        final recent = history.length > 7 ? history.sublist(history.length - 7) : history;
        final average = recent.reduce((a, b) => a + b) / recent.length;
        if (average > 0 && h.hrvMs! / average < 0.85) {
          return HomeInsight(
            message: 'HRV is lower than your recent readings. Consider keeping activity easy and prioritizing rest.',
            source: '${source('HRV')} · ${h.hrvMs!.round()} ms · personal comparison',
            hasFreshData: true,
          );
        }
      }
    }

    if (fresh('Resting heart rate') && h.restingHeartRate != null &&
        h.restingHeartRate30.length >= 5) {
      final history = h.restingHeartRate30.sublist(0, h.restingHeartRate30.length - 1)
          .where((v) => v > 0 && v.isFinite).toList();
      if (history.length >= 4) {
        final recent = history.length > 7 ? history.sublist(history.length - 7) : history;
        final average = recent.reduce((a, b) => a + b) / recent.length;
        if (h.restingHeartRate! >= average + 6) {
          return HomeInsight(
            message: 'Resting heart rate is above your recent pattern. Consider a lighter session if you feel run-down.',
            source: '${source('Resting heart rate')} · ${h.restingHeartRate!.round()} bpm',
            hasFreshData: true,
          );
        }
      }
    }

    if (fresh('Sleep') && h.sleepMinutes > 0) {
      return HomeInsight(
        message: 'You have a recent sleep reading. Keep your sleep schedule consistent and check how you feel today.',
        source: '${source('Sleep')} · ${h.sleepMinutes ~/ 60}h ${h.sleepMinutes % 60}m sleep',
        hasFreshData: true,
      );
    }

    if (fresh('HRV') && h.hrvMs != null) {
      return HomeInsight(
        message: 'New HRV is available. More readings from the same source will make personal comparisons more useful.',
        source: '${source('HRV')} · ${h.hrvMs!.round()} ms',
        hasFreshData: true,
      );
    }

    return const HomeInsight(
      message: 'No fresh recovery readings found in the last 24 hours. Sync your sources or complete today\'s check-in.',
      source: 'Waiting for timestamped measurements',
      hasFreshData: false,
    );
  }
}
