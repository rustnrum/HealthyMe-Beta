import 'dart:math';

import '../models/models.dart';
import '../state/app_state.dart';
import 'recovery_service.dart';
import 'sleep_guidance_service.dart';

enum StatusLevel { good, fair, watch, noData }

class SubsystemStatus {
  final String name;
  final StatusLevel level;
  final String value;
  final String detail;

  const SubsystemStatus({
    required this.name,
    required this.level,
    required this.value,
    required this.detail,
  });
}

class DailyChange {
  final String title;
  final String detail;
  final StatusLevel level;

  const DailyChange({
    required this.title,
    required this.detail,
    required this.level,
  });
}

class WeightTrendSummary {
  final bool hasTrend;
  final double? weeklyDeltaLb;
  final StatusLevel level;
  final String detail;

  const WeightTrendSummary({
    required this.hasTrend,
    required this.weeklyDeltaLb,
    required this.level,
    required this.detail,
  });
}

class BodyReport {
  final String overall;
  final String summary;
  final List<SubsystemStatus> systems;
  final List<DailyChange> changes;

  const BodyReport({
    required this.overall,
    required this.summary,
    required this.systems,
    required this.changes,
  });
}

class BodyStatusService {
  static BodyReport build(HealthyMeState app) {
    final health = app.health;
    final sleepGuidance = SleepGuidanceService.forAge(app.profile.age);
    final recoveryReport = RecoveryService.build(app);

    final sleep = _sleepStatus(health, sleepGuidance);
    final activity = _activityStatus(app);
    final cardio = _cardioStatus(health);
    final body = _bodyStatus(app);
    final labs = _labsStatus(app);
    final recovery = _recoveryStatus(recoveryReport);

    final systems = [recovery, sleep, activity, cardio, body, labs];
    final known = systems.where((item) => item.level != StatusLevel.noData).toList();
    final watches = known.where((item) => item.level == StatusLevel.watch).length;
    final fairs = known.where((item) => item.level == StatusLevel.fair).length;

    String overall;
    String summary;
    if (known.length < 3) {
      overall = 'Limited data';
      summary = 'Connect more telemetry to build a useful daily baseline.';
    } else if (watches >= 2 || recovery.level == StatusLevel.watch) {
      overall = 'Watch';
      summary = 'A few signals are off your recent pattern today.';
    } else if (watches == 1 || fairs >= 2 || recovery.level == StatusLevel.fair) {
      overall = 'Fair';
      summary = 'Mostly steady, with a couple of areas worth watching.';
    } else {
      overall = 'Good';
      summary = 'Available signals are generally on track today.';
    }

    return BodyReport(
      overall: overall,
      summary: summary,
      systems: systems,
      changes: _changes(app),
    );
  }

  static WeightTrendSummary weightTrend(HealthyMeState app) {
    final points = app.mergedWeightHistory.where((p) => p.pounds > 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final current = app.currentWeightLb ?? (points.isEmpty ? null : points.last.pounds);
    if (current == null) {
      return const WeightTrendSummary(
        hasTrend: false,
        weeklyDeltaLb: null,
        level: StatusLevel.noData,
        detail: 'Log or connect weight',
      );
    }

    if (points.length < 2) {
      return const WeightTrendSummary(
        hasTrend: false,
        weeklyDeltaLb: null,
        level: StatusLevel.fair,
        detail: 'Weekly trend pending',
      );
    }

    final latest = points.last;
    final cutoff = latest.date.subtract(const Duration(days: 5));
    WeightPoint? baseline;
    for (final point in points.reversed.skip(1)) {
      if (!point.date.isAfter(cutoff)) {
        baseline = point;
        break;
      }
    }
    if (baseline == null) {
      return const WeightTrendSummary(
        hasTrend: false,
        weeklyDeltaLb: null,
        level: StatusLevel.fair,
        detail: 'Need about a week of weight data',
      );
    }

    final delta = latest.pounds - baseline.pounds;
    final goal = app.profile.goalWeightLb;
    if (goal == null) {
      return WeightTrendSummary(
        hasTrend: true,
        weeklyDeltaLb: delta,
        level: StatusLevel.fair,
        detail: '${_signed(delta)} lb this week',
      );
    }

    final wantsLower = baseline.pounds > goal;
    final wantsHigher = baseline.pounds < goal;
    if (!wantsLower && !wantsHigher) {
      return WeightTrendSummary(
        hasTrend: true,
        weeklyDeltaLb: delta,
        level: StatusLevel.good,
        detail: 'At weight goal',
      );
    }

    final towardGoal = wantsLower ? -delta : delta;
    final level = towardGoal >= 0.2
        ? StatusLevel.good
        : towardGoal <= -0.2
            ? StatusLevel.watch
            : StatusLevel.fair;
    final detail = delta.abs() < 0.2
        ? 'No meaningful change this week'
        : '${_signed(delta)} lb this week';

    return WeightTrendSummary(
      hasTrend: true,
      weeklyDeltaLb: delta,
      level: level,
      detail: detail,
    );
  }

  static SubsystemStatus _sleepStatus(HealthSnapshot health, SleepGuidance guidance) {
    if (health.sleepMinutes <= 0 || guidance.minimumMinutes <= 0) {
      return const SubsystemStatus(
        name: 'Sleep',
        level: StatusLevel.noData,
        value: 'No data',
        detail: 'Connect a sleep source',
      );
    }

    final delta = health.sleepMinutes - guidance.minimumMinutes;
    final hours = _minutes(health.sleepMinutes);
    if (delta >= 0) {
      return SubsystemStatus(
        name: 'Sleep',
        level: StatusLevel.good,
        value: hours,
        detail: 'At age-based target',
      );
    }
    if (delta >= -60) {
      return SubsystemStatus(
        name: 'Sleep',
        level: StatusLevel.fair,
        value: hours,
        detail: '${(-delta)} min below target',
      );
    }
    return SubsystemStatus(
      name: 'Sleep',
      level: StatusLevel.watch,
      value: hours,
      detail: '${(-delta)} min below target',
    );
  }

  static SubsystemStatus _activityStatus(HealthyMeState app) {
    if (!app.health.authorized && app.health.stepsToday == 0) {
      return const SubsystemStatus(
        name: 'Activity',
        level: StatusLevel.noData,
        value: 'No data',
        detail: 'Connect steps',
      );
    }

    final goal = max(1, app.profile.stepGoal);
    final now = DateTime.now();
    final wakingStart = DateTime(now.year, now.month, now.day, 7);
    final wakingEnd = DateTime(now.year, now.month, now.day, 21);
    final totalMinutes = wakingEnd.difference(wakingStart).inMinutes;
    final elapsed = now.isBefore(wakingStart)
        ? 0
        : min(totalMinutes, now.difference(wakingStart).inMinutes);
    final expected = goal * (elapsed / totalMinutes);
    final steps = app.health.stepsToday;

    if (now.isAfter(wakingEnd)) {
      final ratio = steps / goal;
      return SubsystemStatus(
        name: 'Activity',
        level: ratio >= 0.9
            ? StatusLevel.good
            : ratio >= 0.65
                ? StatusLevel.fair
                : StatusLevel.watch,
        value: '${_steps(steps)} steps',
        detail: '${(ratio * 100).round()}% of goal',
      );
    }

    final onTrack = expected <= 0 ? true : steps >= expected * 0.8;
    return SubsystemStatus(
      name: 'Activity',
      level: onTrack ? StatusLevel.good : StatusLevel.fair,
      value: '${_steps(steps)} steps',
      detail: onTrack ? 'On pace today' : 'Below today’s pace',
    );
  }

  static SubsystemStatus _cardioStatus(HealthSnapshot health) {
    final rhr = health.restingHeartRate;
    final resp = health.respiratoryRate;
    if (rhr == null && resp == null) {
      return const SubsystemStatus(
        name: 'Cardio',
        level: StatusLevel.noData,
        value: 'No data',
        detail: 'Heart and breathing unavailable',
      );
    }

    var level = StatusLevel.good;
    var baselineDetail = 'Building your baseline';
    if (rhr != null && health.restingHeartRate30.length >= 4) {
      final history = health.restingHeartRate30;
      final baselineValues = history.sublist(0, max(1, history.length - 1));
      final baseline = baselineValues.reduce((a, b) => a + b) / baselineValues.length;
      final delta = rhr - baseline;
      level = delta <= 5
          ? StatusLevel.good
          : delta <= 10
              ? StatusLevel.fair
              : StatusLevel.watch;
      baselineDetail = delta.abs() < 1
          ? 'HR stable'
          : 'HR ${delta >= 0 ? '+' : ''}${delta.round()} vs baseline';
    }

    if (resp != null && health.respiratoryRate30.length >= 4) {
      final values = health.respiratoryRate30;
      final baselineValues = values.sublist(0, max(1, values.length - 1));
      final baseline = baselineValues.reduce((a, b) => a + b) / baselineValues.length;
      final delta = resp - baseline;
      if (delta > 3) {
        level = StatusLevel.watch;
      } else if (delta > 1.5 && level == StatusLevel.good) {
        level = StatusLevel.fair;
      }
    }

    final value = rhr != null ? '${rhr.round()} bpm' : '${resp!.round()} br/min';
    final detail = resp != null
        ? '${resp.toStringAsFixed(0)} br/min • $baselineDetail'
        : baselineDetail;

    return SubsystemStatus(
      name: 'Cardio',
      level: level,
      value: value,
      detail: detail,
    );
  }

  static SubsystemStatus _bodyStatus(HealthyMeState app) {
    final current = app.currentWeightLb;
    if (current == null) {
      return const SubsystemStatus(
        name: 'Body',
        level: StatusLevel.noData,
        value: 'No data',
        detail: 'Log or connect weight',
      );
    }
    final trend = weightTrend(app);
    return SubsystemStatus(
      name: 'Body',
      level: trend.level,
      value: '${current.toStringAsFixed(1)} lb',
      detail: trend.detail,
    );
  }

  static SubsystemStatus _labsStatus(HealthyMeState app) {
    if (app.labs.isEmpty) {
      return const SubsystemStatus(
        name: 'Labs',
        level: StatusLevel.noData,
        value: 'No labs',
        detail: 'Optional long-term context',
      );
    }

    final dated = app.labs.where((lab) => lab.date != null).toList()
      ..sort((a, b) => b.date!.compareTo(a.date!));
    if (dated.isEmpty) {
      return SubsystemStatus(
        name: 'Labs',
        level: StatusLevel.fair,
        value: '${app.labs.length} stored',
        detail: 'Add collection dates',
      );
    }

    final days = DateTime.now().difference(dated.first.date!).inDays;
    return SubsystemStatus(
      name: 'Labs',
      level: days <= 180
          ? StatusLevel.good
          : days <= 365
              ? StatusLevel.fair
              : StatusLevel.watch,
      value: '${app.labs.length} stored',
      detail: '$days days since latest',
    );
  }

  static SubsystemStatus _recoveryStatus(RecoveryReport report) {
    final level = switch (report.band) {
      RecoveryBand.good => StatusLevel.good,
      RecoveryBand.fair => StatusLevel.fair,
      RecoveryBand.watch => StatusLevel.watch,
      RecoveryBand.noData => StatusLevel.noData,
    };
    return SubsystemStatus(
      name: 'Recovery',
      level: level,
      value: report.score == null ? '—' : report.score.toString(),
      detail: report.score == null
          ? 'Need more recovery data'
          : '${report.label} • ${report.confidence}% confidence',
    );
  }

  static List<DailyChange> _changes(HealthyMeState app) {
    final changes = <DailyChange>[];
    final h = app.health;

    final recentSleep = h.sleepMinutes7.where((minutes) => minutes > 0).toList();
    if (h.sleepMinutes > 0 && recentSleep.length >= 3) {
      final previous = recentSleep.length > 1
          ? recentSleep.sublist(0, recentSleep.length - 1)
          : recentSleep;
      final avg = previous.reduce((a, b) => a + b) / max(1, previous.length);
      final delta = h.sleepMinutes - avg;
      if (delta.abs() >= 30) {
        changes.add(
          DailyChange(
            title: delta < 0
                ? 'Sleep was shorter than your recent average'
                : 'Sleep was longer than your recent average',
            detail: '${_minutes(h.sleepMinutes)} vs ${_minutes(avg.round())} recent average',
            level: delta < -60 ? StatusLevel.watch : StatusLevel.fair,
          ),
        );
      }
    }

    final recentSteps = h.dailySteps30.where((steps) => steps > 0).toList();
    if (DateTime.now().hour >= 17 && recentSteps.length >= 4) {
      final previous = recentSteps.length > 1
          ? recentSteps.sublist(0, recentSteps.length - 1)
          : recentSteps;
      final tail = previous.length > 7 ? previous.sublist(previous.length - 7) : previous;
      final avg = tail.reduce((a, b) => a + b) / tail.length;
      if (avg > 0 && h.stepsToday < avg * 0.7) {
        changes.add(
          DailyChange(
            title: 'Activity is below your recent pace',
            detail: '${_steps(h.stepsToday)} steps vs ${_steps(avg.round())} recent daily average',
            level: StatusLevel.fair,
          ),
        );
      }
    }

    if (h.restingHeartRate != null && h.restingHeartRate30.length >= 4) {
      final values = h.restingHeartRate30;
      final base = values.sublist(0, values.length - 1).reduce((a, b) => a + b) /
          (values.length - 1);
      final delta = h.restingHeartRate! - base;
      if (delta.abs() >= 5) {
        changes.add(
          DailyChange(
            title: delta > 0
                ? 'Resting heart rate is above your baseline'
                : 'Resting heart rate is below your baseline',
            detail: '${h.restingHeartRate!.round()} bpm (${delta >= 0 ? '+' : ''}${delta.round()} vs baseline)',
            level: delta > 10 ? StatusLevel.watch : StatusLevel.fair,
          ),
        );
      }
    }

    if (h.respiratoryRate != null && h.respiratoryRate30.length >= 4) {
      final values = h.respiratoryRate30;
      final base = values.sublist(0, values.length - 1).reduce((a, b) => a + b) /
          (values.length - 1);
      final delta = h.respiratoryRate! - base;
      if (delta > 1.5) {
        changes.add(
          DailyChange(
            title: 'Breathing rate is above your baseline',
            detail: '${h.respiratoryRate!.toStringAsFixed(1)} br/min (${delta.toStringAsFixed(1)} above baseline)',
            level: delta > 3 ? StatusLevel.watch : StatusLevel.fair,
          ),
        );
      }
    }

    final trend = weightTrend(app);
    if (trend.hasTrend && trend.weeklyDeltaLb != null && trend.weeklyDeltaLb!.abs() >= 0.2) {
      changes.add(
        DailyChange(
          title: trend.level == StatusLevel.good
              ? 'Weight moved toward your goal this week'
              : trend.level == StatusLevel.watch
                  ? 'Weight moved away from your goal this week'
                  : 'Weight was mostly steady this week',
          detail: trend.detail,
          level: trend.level,
        ),
      );
    }

    if (changes.isEmpty) {
      changes.add(
        const DailyChange(
          title: 'No major change detected',
          detail: 'Available signals are close to their recent pattern.',
          level: StatusLevel.good,
        ),
      );
    }

    return changes.take(4).toList();
  }

  static String _steps(int value) {
    if (value >= 10000) return '${(value / 1000).round()}K';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  static String _minutes(int total) {
    final hours = total ~/ 60;
    final minutes = total % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  static String _signed(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
}
