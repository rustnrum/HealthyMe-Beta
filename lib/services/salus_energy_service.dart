import 'dart:math' as math;

import '../models/models.dart';

/// Cross-device *experimental* daily energy estimate. Not Garmin Body Battery.
/// It uses only data resolved by Salus from the user's selected data sources.
/// Values are never generated if the physiological evidence is insufficient.
/// This estimate is deliberately NOT a Recovery contributor: their inputs
/// overlap, and using Energy to score Recovery would count them twice.
class SalusEnergyEstimate {
  final int? score;
  final int coverage;
  final String quality;
  final List<String> used;
  final List<String> missing;
  final String explanation;

  const SalusEnergyEstimate({
    required this.score,
    required this.coverage,
    required this.quality,
    required this.used,
    required this.missing,
    required this.explanation,
  });
}

class SalusEnergyService {
  const SalusEnergyService._();

  static double _between(double value, double low, double high) =>
      value.clamp(low, high).toDouble();

  static bool _fresh(
    HealthSnapshot h, String metric, DateTime now, Duration maxAge,
  ) {
    final at = h.freshness[metric];
    if (at != null) {
      final age = now.difference(at);
      return !age.isNegative && age <= maxAge;
    }
    // A recent sync with an explicitly resolved provider gives a lower quality
    // time signal when a metric-specific timestamp is not exposed.
    final sync = h.lastSync;
    if (sync == null || !h.resolvedSources.containsKey(metric)) return false;
    final age = now.difference(sync);
    return !age.isNegative && age <= maxAge;
  }

  static SalusEnergyEstimate estimate(
    HealthSnapshot h,
    UserProfile profile, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final used = <String>[];
    final missing = <String>[];
    var weighted = 0.0;
    var weights = 0.0;
    var coverage = 0;
    var sleepAvailable = false;
    var autonomicAvailable = false;
    var baselineDays = 0;

    if (h.sleepMinutes > 0 && _fresh(h, 'Sleep', clock, const Duration(hours: 36))) {
      final goalMinutes = math.max(360, profile.plannedSleepMinutes);
      final sleepScore = _between(h.sleepMinutes / goalMinutes * 100, 20, 100);
      weighted += sleepScore * 35;
      weights += 35;
      coverage += 35;
      sleepAvailable = true;
      used.add('Sleep');
    } else {
      missing.add('Recent sleep');
    }

    // Daily resting HR, not a spot-check pulse. Two preceding days establish
    // only an initial comparison; the resulting score stays provisional.
    final rhr = h.restingHeartRate;
    if (rhr != null && rhr.isFinite && rhr > 30 && rhr < 180 &&
        h.restingHeartRate30.length >= 3 &&
        _fresh(h, 'Resting heart rate', clock, const Duration(hours: 48))) {
      final history = h.restingHeartRate30.sublist(0, h.restingHeartRate30.length - 1)
          .where((v) => v.isFinite && v >= 30 && v <= 180).toList();
      if (history.length >= 2) {
        final baseline = history.reduce((a, b) => a + b) / history.length;
        // Higher-than-usual resting HR can accompany strain; individual
        // baselines matter much more than population-wide heart-rate values.
        final score = _between(75 - (rhr - baseline) * 5, 25, 95);
        weighted += score * 25;
        weights += 25;
        coverage += 25;
        autonomicAvailable = true;
        baselineDays = math.max(baselineDays, history.length);
        used.add('Resting HR');
      }
    }
    if (!used.contains('Resting HR')) missing.add('Resting HR baseline');

    final hrv = h.hrvMs;
    if (hrv != null && hrv.isFinite && hrv > 0 && hrv < 350 &&
        h.hrv30.length >= 4 && _fresh(h, 'HRV', clock, const Duration(hours: 48))) {
      final history = h.hrv30.sublist(0, h.hrv30.length - 1)
          .where((v) => v.isFinite && v > 0 && v < 350).toList();
      if (history.length >= 3) {
        final baseline = history.reduce((a, b) => a + b) / history.length;
        final ratio = hrv / baseline;
        // Exceptionally high HRV isn't assumed to be endlessly better.
        final score = ratio > 1.4
            ? 72.0 : _between(75 + (ratio - 1) * 80, 25, 95);
        weighted += score * 30;
        weights += 30;
        coverage += 30;
        autonomicAvailable = true;
        baselineDays = math.max(baselineDays, history.length);
        used.add('HRV');
      }
    }
    if (!used.contains('HRV')) missing.add('HRV baseline');

    if (h.stepsToday >= 0 && h.resolvedSources.containsKey('Steps') &&
        _fresh(h, 'Steps', clock, const Duration(hours: 20))) {
      // Movement changes an energy *estimate*. Steps alone never suffice.
      // Vigorous activity is not inferred from a steps-only reading.
      final target = math.max(1, profile.stepGoal);
      final fraction = h.stepsToday / target;
      final movementFactor = _between(94 - 14 * fraction, 55, 94);
      weighted += movementFactor * 10;
      weights += 10;
      coverage += 10;
      used.add('Steps');
    } else {
      missing.add('Today\'s movement');
    }

    if (!sleepAvailable || !autonomicAvailable || weights == 0) {
      return SalusEnergyEstimate(
        score: null,
        coverage: coverage,
        quality: 'Insufficient data',
        used: used,
        missing: missing,
        explanation: 'Needs recent sleep plus a personal HRV or resting-heart-rate baseline.',
      );
    }

    // Early baselines are unreliable. Pull the result toward a neutral
    // midpoint until sufficient personal history and signal coverage accrue.
    // This is an openly experimental heuristic, never a medically validated
    // readiness measure or a reconstruction of Garmin's proprietary score.
    final maturity = _between(baselineDays / 14.0, 0.0, 1.0);
    final evidence = (coverage / 100.0) * maturity;
    final candidate = weighted / weights;
    final score = _between(50 + (candidate - 50) * evidence, 5, 100).round();
    return SalusEnergyEstimate(
      score: score,
      coverage: coverage,
      quality: 'Provisional estimate',
      used: used,
      missing: missing,
      explanation: 'Experimental daily estimate, not a medical measure. '
          'It does not reproduce Garmin\'s continuous charging and draining.',
    );
  }
}
