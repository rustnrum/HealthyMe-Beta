import 'dart:math';

import '../models/models.dart';
import '../state/app_state.dart';
import 'daily_state_service.dart';
import 'sleep_guidance_service.dart';

enum RecoveryBand { good, fair, watch, noData }

class RecoveryContributor {
  final String name;
  final int? score;
  final String detail;
  final bool available;
  final int weight;

  const RecoveryContributor({
    required this.name,
    required this.score,
    required this.detail,
    this.available = true,
    this.weight = 0,
  });
}

class RecoveryReport {
  final int? score;
  final int confidence;
  final RecoveryBand band;
  final String label;
  final String summary;
  final List<RecoveryContributor> contributors;

  const RecoveryReport({
    required this.score,
    required this.confidence,
    required this.band,
    required this.label,
    required this.summary,
    required this.contributors,
  });
}

/// Salus wellness/readiness estimate.
///
/// Missing signals are excluded instead of guessed. Salus also requires useful
/// objective coverage before it will show a numeric recovery value; one strong
/// metric by itself must never look like a complete 98/100 recovery picture.
class RecoveryService {
  static const int _sleepWeight = 35;
  static const int _dailyStateWeight = 30;
  static const int _hrvWeight = 20;
  static const int _rhrWeight = 15;
  static const int _breathingWeight = 10;
  static const int _trainingWeight = 20;

  /// Minimum objective coverage needed for an objective-only recovery number.
  static const int _minimumObjectiveCoverage = 50;

  static RecoveryReport build(HealthyMeState app) {
    final contributors = <RecoveryContributor>[
      _sleepContributor(app),
      _dailyStateContributor(app),
      _hrvContributor(app.health),
      _restingHeartRateContributor(app.health),
      _breathingContributor(app.health),
      _trainingContributor(app.health),
      const RecoveryContributor(
        name: 'Nutrition',
        score: null,
        detail: 'Not included until Diet has real food data',
        available: false,
        weight: 0,
      ),
    ];

    final scored = contributors
        .where((item) => item.available && item.score != null)
        .toList();
    if (scored.isEmpty) {
      return RecoveryReport(
        score: null,
        confidence: 0,
        band: RecoveryBand.noData,
        label: 'Building',
        summary:
            'Recovery is building. Salus needs more overnight or morning check-in data before showing a number.',
        contributors: contributors,
      );
    }

    final objectiveScored =
        scored.where((item) => item.name != 'Daily state').toList();
    final objectiveWeight =
        objectiveScored.fold<int>(0, (sum, item) => sum + item.weight);
    final objectiveWeighted = objectiveScored.fold<int>(
      0,
      (sum, item) => sum + (item.score ?? 0) * item.weight,
    );
    final objectiveScore = objectiveScored.isEmpty
        ? null
        : (objectiveWeighted / max(1, objectiveWeight))
            .round()
            .clamp(0, 100)
            .toInt();

    final dailyItems =
        scored.where((item) => item.name == 'Daily state').toList();
    final dailyScore = dailyItems.isEmpty ? null : dailyItems.first.score;

    final objectiveConfidence =
        objectiveWeight.clamp(0, 100).toInt();

    // Without a subjective check-in, do not inflate a tiny amount of objective
    // telemetry to a full 0–100 readiness score.
    if (dailyScore == null &&
        objectiveWeight < _minimumObjectiveCoverage) {
      return RecoveryReport(
        score: null,
        confidence: objectiveConfidence,
        band: RecoveryBand.noData,
        label: 'Building',
        summary:
            'More overnight signals are needed before Salus shows a reliable recovery number.',
        contributors: contributors,
      );
    }

    final int score;
    if (objectiveScore != null && dailyScore != null) {
      score = (objectiveScore * 0.70 + dailyScore * 0.30)
          .round()
          .clamp(0, 100)
          .toInt();
    } else if (objectiveScore != null) {
      score = objectiveScore;
    } else {
      // A completed Daily State can still provide a subjective estimate, but
      // confidence remains visibly lower until objective telemetry arrives.
      score = dailyScore!;
    }

    final confidence = dailyScore == null
        ? objectiveConfidence
        : (objectiveConfidence * 0.70 + 30)
            .round()
            .clamp(0, 100)
            .toInt();

    final band = score >= 80
        ? RecoveryBand.good
        : score >= 60
            ? RecoveryBand.fair
            : RecoveryBand.watch;
    final label = score >= 80
        ? 'High'
        : score >= 60
            ? 'Moderate'
            : score >= 40
                ? 'Low'
                : 'Very low';

    final ranked = [...scored]
      ..sort((a, b) => (a.score ?? 100).compareTo(b.score ?? 100));
    final lowest =
        ranked.where((item) => (item.score ?? 100) < 80).take(2).toList();
    final summary = lowest.isEmpty
        ? 'Available recovery signals are close to your recent baseline.'
        : '${lowest.map((item) => item.name.toLowerCase()).join(' + ')} are pulling recovery down.';

    return RecoveryReport(
      score: score,
      confidence: confidence,
      band: band,
      label: label,
      summary: summary,
      contributors: contributors,
    );
  }

  static RecoveryContributor _dailyStateContributor(HealthyMeState app) {
    if (!app.dailyStateEnabled) {
      return const RecoveryContributor(
        name: 'Daily state',
        score: null,
        detail: 'Morning check-in disabled',
        available: false,
        weight: 0,
      );
    }

    final entry = DailyStateService.today(app);
    final score = DailyStateService.recoveryEstimate(entry);
    if (entry == null || score == null) {
      return const RecoveryContributor(
        name: 'Daily state',
        score: null,
        detail: 'Morning check-in not completed today',
        available: false,
        weight: _dailyStateWeight,
      );
    }

    return RecoveryContributor(
      name: 'Daily state',
      score: score,
      detail:
          'Recovery ${entry.recoveryAverage!.toStringAsFixed(1)}/6 • Stress ${entry.stressAverage!.toStringAsFixed(1)}/6',
      weight: _dailyStateWeight,
    );
  }

  static RecoveryContributor _sleepContributor(HealthyMeState app) {
    final h = app.health;
    final guidance = SleepGuidanceService.forAge(app.profile.age);
    if (h.sleepMinutes <= 0 || guidance.minimumMinutes <= 0) {
      return const RecoveryContributor(
        name: 'Sleep',
        score: null,
        detail: 'No usable sleep data',
        available: false,
        weight: _sleepWeight,
      );
    }

    final target = guidance.minimumMinutes.toDouble();
    final upper = guidance.upperMinutes?.toDouble();

    double durationScore;
    if (h.sleepMinutes < target) {
      durationScore =
          (h.sleepMinutes / target * 100).clamp(35, 100).toDouble();
    } else if (upper != null && h.sleepMinutes > upper + 90) {
      durationScore = 88;
    } else {
      durationScore = 100;
    }

    final recent = h.sleepMinutes7.where((v) => v > 0).toList();
    double balanceScore = durationScore;
    if (recent.length >= 4) {
      final history =
          recent.length > 1 ? recent.sublist(0, recent.length - 1) : recent;
      final avg = history.reduce((a, b) => a + b) / history.length;
      balanceScore = (avg / target * 100).clamp(45, 100).toDouble();
    }

    final score = (durationScore * 0.70 + balanceScore * 0.30)
        .round()
        .clamp(0, 100)
        .toInt();

    String detail;
    if (recent.length >= 4) {
      final history =
          recent.length > 1 ? recent.sublist(0, recent.length - 1) : recent;
      final avg = history.reduce((a, b) => a + b) / history.length;
      final delta = h.sleepMinutes - avg;
      final comparison = delta.abs() < 20
          ? 'near recent average'
          : '${delta.abs().round()} min ${delta < 0 ? 'below' : 'above'} recent average';
      detail = '${_minutes(h.sleepMinutes)} • $comparison';
    } else {
      detail = '${_minutes(h.sleepMinutes)} • target ${guidance.label}';
    }

    return RecoveryContributor(
      name: 'Sleep',
      score: score,
      detail: detail,
      weight: _sleepWeight,
    );
  }

  static RecoveryContributor _hrvContributor(HealthSnapshot h) {
    final current = h.hrvMs;
    if (current == null || h.hrv30.length < 4) {
      return const RecoveryContributor(
        name: 'HRV',
        score: null,
        detail: 'Building your personal HRV baseline',
        available: false,
        weight: _hrvWeight,
      );
    }

    final history = _baselineWithoutCurrent(h.hrv30);
    final baseline = _avg(history);
    if (baseline <= 0) {
      return const RecoveryContributor(
        name: 'HRV',
        score: null,
        detail: 'Building your personal HRV baseline',
        available: false,
        weight: _hrvWeight,
      );
    }

    final ratio = current / baseline;
    final score = ratio >= 1.0
        ? 95
        : ratio >= 0.90
            ? 88
            : ratio >= 0.80
                ? 75
                : ratio >= 0.70
                    ? 60
                    : 42;
    final pct = ((ratio - 1) * 100).round();
    return RecoveryContributor(
      name: 'HRV',
      score: score,
      detail:
          '${current.round()} ms • ${pct >= 0 ? '+' : ''}$pct% vs baseline',
      weight: _hrvWeight,
    );
  }

  static RecoveryContributor _restingHeartRateContributor(HealthSnapshot h) {
    final current = h.restingHeartRate;
    if (current == null || h.restingHeartRate30.length < 4) {
      return const RecoveryContributor(
        name: 'Resting HR',
        score: null,
        detail: 'Building your resting-HR baseline',
        available: false,
        weight: _rhrWeight,
      );
    }

    final baseline = _avg(_baselineWithoutCurrent(h.restingHeartRate30));
    final delta = current - baseline;
    final score = delta <= 0
        ? 95
        : delta <= 2
            ? 90
            : delta <= 4
                ? 78
                : delta <= 6
                    ? 64
                    : delta <= 9
                        ? 48
                        : 30;

    return RecoveryContributor(
      name: 'Resting HR',
      score: score,
      detail:
          '${current.round()} bpm • ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} vs baseline',
      weight: _rhrWeight,
    );
  }

  static RecoveryContributor _breathingContributor(HealthSnapshot h) {
    final current = h.respiratoryRate;
    if (current == null || h.respiratoryRate30.length < 4) {
      return const RecoveryContributor(
        name: 'Breathing',
        score: null,
        detail: 'Building your respiratory baseline',
        available: false,
        weight: _breathingWeight,
      );
    }

    final baseline = _avg(_baselineWithoutCurrent(h.respiratoryRate30));
    final delta = (current - baseline).abs();
    final score = delta <= 0.5
        ? 95
        : delta <= 1.0
            ? 86
            : delta <= 1.5
                ? 74
                : delta <= 2.0
                    ? 60
                    : delta <= 3.0
                        ? 45
                        : 30;

    return RecoveryContributor(
      name: 'Breathing',
      score: score,
      detail:
          '${current.toStringAsFixed(1)} br/min • ${delta.toStringAsFixed(1)} from baseline',
      weight: _breathingWeight,
    );
  }

  static RecoveryContributor _trainingContributor(HealthSnapshot h) {
    if (!h.authorized) {
      return const RecoveryContributor(
        name: 'Training load',
        score: null,
        detail: 'Connect workout data',
        available: false,
        weight: _trainingWeight,
      );
    }
    if (h.workouts.isEmpty) {
      return const RecoveryContributor(
        name: 'Training load',
        score: null,
        detail: 'No workout history yet',
        available: false,
        weight: _trainingWeight,
      );
    }

    final now = DateTime.now();
    var recentLoad = 0.0;
    var baselineLoad = 0.0;
    var recentMinutes = 0;

    for (final workout in h.workouts) {
      final age = now.difference(workout.end);
      if (age.isNegative) continue;
      final minutes = max(0, workout.minutes);
      if (minutes == 0) continue;
      final rawLoad = minutes * _intensity(workout.type);

      if (age <= const Duration(hours: 72)) {
        final decay = exp(-age.inHours / 54.0);
        recentLoad += rawLoad * decay;
        recentMinutes += minutes;
      } else if (age <= const Duration(days: 21)) {
        baselineLoad += rawLoad;
      }
    }

    final expectedThreeDayLoad =
        baselineLoad > 0 ? baselineLoad / 18 * 3 : 0.0;
    int score;
    String comparison;
    if (recentLoad == 0) {
      score = 92;
      comparison = 'No recent workout strain';
    } else if (expectedThreeDayLoad > 8) {
      final ratio = recentLoad / expectedThreeDayLoad;
      score = ratio <= 0.7
          ? 92
          : ratio <= 1.0
              ? 84
              : ratio <= 1.3
                  ? 72
                  : ratio <= 1.6
                      ? 58
                      : 40;
      comparison = '${ratio.toStringAsFixed(1)}× recent-vs-usual load';
    } else {
      score = recentLoad <= 35
          ? 90
          : recentLoad <= 75
              ? 80
              : recentLoad <= 120
                  ? 68
                  : recentLoad <= 180
                      ? 54
                      : 40;
      comparison = 'Building your training-load baseline';
    }

    return RecoveryContributor(
      name: 'Training load',
      score: score,
      detail: '$recentMinutes min in last 72 hr • $comparison',
      weight: _trainingWeight,
    );
  }

  static List<double> _baselineWithoutCurrent(List<double> values) {
    if (values.length <= 1) return values;
    return values.sublist(0, values.length - 1);
  }

  static double _intensity(String type) {
    final value = type.toLowerCase();
    if (value.contains('hiit') ||
        value.contains('run') ||
        value.contains('sprint') ||
        value.contains('cross') ||
        value.contains('boxing')) {
      return 1.55;
    }
    if (value.contains('strength') ||
        value.contains('weight') ||
        value.contains('cycle') ||
        value.contains('bike') ||
        value.contains('swim') ||
        value.contains('row')) {
      return 1.25;
    }
    if (value.contains('walk') ||
        value.contains('yoga') ||
        value.contains('stretch') ||
        value.contains('mobility')) {
      return 0.70;
    }
    return 1.0;
  }

  static double _avg(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  static String _minutes(int total) {
    final hours = total ~/ 60;
    final minutes = total % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
}
