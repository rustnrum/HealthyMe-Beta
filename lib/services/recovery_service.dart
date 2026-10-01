import 'dart:math';

import '../models/models.dart';
import '../state/app_state.dart';
import 'sleep_guidance_service.dart';

enum RecoveryBand { good, fair, watch, noData }

class RecoveryContributor {
  final String name;
  final int? score;
  final String detail;
  final bool available;

  const RecoveryContributor({
    required this.name,
    required this.score,
    required this.detail,
    this.available = true,
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

class RecoveryService {
  static RecoveryReport build(HealthyMeState app) {
    final health = app.health;
    final sleep = _sleepContributor(app);
    final cardio = _cardioContributor(health);
    final training = _trainingContributor(health);

    final available = <({RecoveryContributor item, double weight})>[
      if (sleep.available) (item: sleep, weight: 0.45),
      if (cardio.available) (item: cardio, weight: 0.35),
      if (training.available) (item: training, weight: 0.20),
    ];

    final nutrition = const RecoveryContributor(
      name: 'Nutrition',
      score: null,
      detail: 'Not included until Diet has real food data',
      available: false,
    );

    if (available.isEmpty) {
      return RecoveryReport(
        score: null,
        confidence: 0,
        band: RecoveryBand.noData,
        label: 'No data',
        summary: 'Recovery needs sleep, cardio or workout telemetry.',
        contributors: [sleep, cardio, training, nutrition],
      );
    }

    final weightTotal = available.fold<double>(0.0, (sum, entry) => sum + entry.weight);
    final weighted = available.fold<double>(
      0.0,
      (sum, entry) => sum + (entry.item.score ?? 0) * entry.weight,
    );
    final score = (weighted / weightTotal).round().clamp(0, 100).toInt();

    var confidence = 0;
    if (sleep.available) confidence += health.sleepMinutes7.where((v) => v > 0).length >= 4 ? 38 : 30;
    if (cardio.available) {
      confidence += health.restingHeartRate30.length >= 4 ? 27 : 19;
      if (health.hrv30.length >= 4 || health.respiratoryRate30.length >= 4) {
        confidence += 8;
      }
    }
    if (training.available) confidence += 27;
    confidence = confidence.clamp(0, 100).toInt();

    final band = score >= 80
        ? RecoveryBand.good
        : score >= 60
            ? RecoveryBand.fair
            : RecoveryBand.watch;
    final label = band == RecoveryBand.good
        ? 'Good'
        : band == RecoveryBand.fair
            ? 'Fair'
            : 'Watch';

    final reasons = <String>[];
    if ((sleep.score ?? 100) < 75) reasons.add('shorter sleep');
    if ((cardio.score ?? 100) < 75) reasons.add('cardio strain');
    if ((training.score ?? 100) < 70) reasons.add('recent training load');

    final summary = reasons.isEmpty
        ? 'Available recovery signals are steady.'
        : reasons.take(2).join(' + ');

    return RecoveryReport(
      score: score,
      confidence: confidence,
      band: band,
      label: label,
      summary: _sentence(summary),
      contributors: [sleep, cardio, training, nutrition],
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
      );
    }

    final target = guidance.minimumMinutes;
    var score = 100.0;
    if (h.sleepMinutes < target) {
      final shortage = target - h.sleepMinutes;
      score -= min<double>(55.0, shortage / target * 100 * 1.5);
    } else if (guidance.upperMinutes != null && h.sleepMinutes > guidance.upperMinutes!) {
      final over = h.sleepMinutes - guidance.upperMinutes!;
      score -= min<double>(15.0, over / 60 * 4);
    }

    final recent = h.sleepMinutes7.where((v) => v > 0).toList();
    if (recent.length >= 4) {
      final comparison = recent.length > 1 ? recent.sublist(0, recent.length - 1) : recent;
      final avg = comparison.reduce((a, b) => a + b) / comparison.length;
      final delta = (h.sleepMinutes - avg).abs();
      if (delta > 45) score -= min<double>(12.0, (delta - 45) / 15 * 2);
    }

    score = score.clamp(0, 100).toDouble();
    String detail;
    if (recent.length >= 3) {
      final previous = recent.length > 1 ? recent.sublist(0, recent.length - 1) : recent;
      final avg = previous.reduce((a, b) => a + b) / previous.length;
      final diff = h.sleepMinutes - avg;
      if (diff <= -30) {
        detail = '${_minutes(h.sleepMinutes)} • ${(-diff).round()} min below recent average';
      } else if (diff >= 30) {
        detail = '${_minutes(h.sleepMinutes)} • ${diff.round()} min above recent average';
      } else {
        detail = '${_minutes(h.sleepMinutes)} • near recent average';
      }
    } else {
      detail = '${_minutes(h.sleepMinutes)} • target ${guidance.label}';
    }

    return RecoveryContributor(
      name: 'Sleep',
      score: score.round(),
      detail: detail,
    );
  }

  static RecoveryContributor _cardioContributor(HealthSnapshot h) {
    final hasAny = h.restingHeartRate != null || h.hrvMs != null || h.respiratoryRate != null;
    if (!hasAny) {
      return const RecoveryContributor(
        name: 'Cardio',
        score: null,
        detail: 'No recovery-oriented cardio data',
        available: false,
      );
    }

    var score = 88.0;
    final notes = <String>[];

    final rhr = h.restingHeartRate;
    if (rhr != null && h.restingHeartRate30.length >= 4) {
      final baselineValues = h.restingHeartRate30.sublist(0, h.restingHeartRate30.length - 1);
      final baseline = _avg(baselineValues);
      final delta = rhr - baseline;
      if (delta > 3) score -= min<double>(28.0, delta * 3.5);
      notes.add('HR ${rhr.round()} bpm ${delta.abs() < 1 ? 'near baseline' : '${delta >= 0 ? '+' : ''}${delta.round()} vs baseline'}');
    } else if (rhr != null) {
      notes.add('HR ${rhr.round()} bpm');
    }

    final resp = h.respiratoryRate;
    if (resp != null && h.respiratoryRate30.length >= 4) {
      final baselineValues = h.respiratoryRate30.sublist(0, h.respiratoryRate30.length - 1);
      final baseline = _avg(baselineValues);
      final delta = resp - baseline;
      if (delta > 1.5) score -= min<double>(18.0, delta * 7);
      notes.add('${resp.toStringAsFixed(0)} br/min');
    } else if (resp != null) {
      notes.add('${resp.toStringAsFixed(0)} br/min');
    }

    final hrv = h.hrvMs;
    if (hrv != null && h.hrv30.length >= 4) {
      final baselineValues = h.hrv30.sublist(0, h.hrv30.length - 1);
      final baseline = _avg(baselineValues);
      if (baseline > 0) {
        final ratio = hrv / baseline;
        if (ratio < 0.8) score -= min<double>(22.0, (0.8 - ratio) * 70);
      }
      notes.add('HRV ${hrv.round()} ms');
    }

    score = score.clamp(0, 100).toDouble();
    return RecoveryContributor(
      name: 'Cardio',
      score: score.round(),
      detail: notes.isEmpty ? 'Building your cardio baseline' : notes.take(2).join(' • '),
    );
  }

  static RecoveryContributor _trainingContributor(HealthSnapshot h) {
    if (!h.authorized) {
      return const RecoveryContributor(
        name: 'Training load',
        score: null,
        detail: 'Connect workout data',
        available: false,
      );
    }

    final now = DateTime.now();
    var load = 0.0;
    var recentMinutes = 0;
    var hardest = 0.0;
    for (final workout in h.workouts) {
      final age = now.difference(workout.end);
      if (age.isNegative || age > const Duration(hours: 48)) continue;
      final intensity = _intensity(workout.type);
      final recency = age <= const Duration(hours: 24) ? 1.0 : 0.55;
      final minutes = max(0, workout.minutes);
      load += minutes * intensity * recency;
      recentMinutes += minutes;
      hardest = max(hardest, intensity);
    }

    final score = load <= 25
        ? 95
        : load <= 60
            ? 84
            : load <= 100
                ? 70
                : load <= 150
                    ? 55
                    : 40;
    final intensityLabel = hardest >= 1.45
        ? 'high'
        : hardest >= 1.15
            ? 'moderate'
            : recentMinutes > 0
                ? 'light'
                : 'none';
    final detail = recentMinutes == 0
        ? 'No workout load in the last 48 hr'
        : '$recentMinutes min • $intensityLabel recent load';

    return RecoveryContributor(
      name: 'Training load',
      score: score,
      detail: detail,
    );
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

  static String _sentence(String value) {
    if (value.isEmpty) return value;
    final normalized = value.endsWith('.') ? value.substring(0, value.length - 1) : value;
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}.';
  }
}
