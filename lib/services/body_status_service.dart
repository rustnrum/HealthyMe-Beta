import 'dart:math';

import '../models/models.dart';
import '../state/app_state.dart';
import 'sleep_guidance_service.dart';

enum StatusLevel {
  good,
  fair,
  watch,
  noData,
}

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
    final sleepGuidance =
        SleepGuidanceService.forAge(app.profile.age);

    final sleep = _sleepStatus(health, sleepGuidance);
    final activity = _activityStatus(app);
    final cardio = _cardioStatus(health);
    final body = _bodyStatus(app);
    final labs = _labsStatus(app);
    final recovery = _recoveryStatus(sleep, cardio, health);

    final systems = [
      recovery,
      sleep,
      activity,
      cardio,
      body,
      labs,
    ];

    final known = systems
        .where((item) => item.level != StatusLevel.noData)
        .toList();
    final watches =
        known.where((item) => item.level == StatusLevel.watch).length;
    final fairs =
        known.where((item) => item.level == StatusLevel.fair).length;

    String overall;
    String summary;
    if (known.length < 3) {
      overall = 'Limited data';
      summary = 'Connect more telemetry to build a useful daily baseline.';
    } else if (watches >= 2) {
      overall = 'Watch';
      summary = 'A few systems are off your current pattern today.';
    } else if (watches == 1 || fairs >= 2) {
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
      changes: _changes(app, sleepGuidance),
    );
  }

  static SubsystemStatus _sleepStatus(
    HealthSnapshot health,
    SleepGuidance guidance,
  ) {
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
    if (!app.health.authorized &&
        app.health.stepsToday == 0) {
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
        : min(
            totalMinutes,
            now.difference(wakingStart).inMinutes,
          );
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
        value: '$steps steps',
        detail: '${(ratio * 100).round()}% of goal',
      );
    }

    final onTrack = expected <= 0 ? true : steps >= expected * 0.8;
    return SubsystemStatus(
      name: 'Activity',
      level: onTrack ? StatusLevel.good : StatusLevel.fair,
      value: '$steps steps',
      detail: onTrack ? 'On pace today' : 'Below today’s pace',
    );
  }

  static SubsystemStatus _cardioStatus(HealthSnapshot health) {
    final rhr = health.restingHeartRate;
    if (rhr == null) {
      return const SubsystemStatus(
        name: 'Cardio',
        level: StatusLevel.noData,
        value: 'No data',
        detail: 'Resting HR unavailable',
      );
    }

    final history = health.restingHeartRate30;
    if (history.length < 4) {
      return SubsystemStatus(
        name: 'Cardio',
        level: StatusLevel.good,
        value: '${rhr.round()} bpm',
        detail: 'Building your baseline',
      );
    }

    final baselineValues = history.sublist(0, max(1, history.length - 1));
    final baseline =
        baselineValues.reduce((a, b) => a + b) / baselineValues.length;
    final delta = rhr - baseline;

    return SubsystemStatus(
      name: 'Cardio',
      level: delta <= 5
          ? StatusLevel.good
          : delta <= 10
              ? StatusLevel.fair
              : StatusLevel.watch,
      value: '${rhr.round()} bpm',
      detail: delta.abs() < 1
          ? 'Near baseline'
          : '${delta >= 0 ? '+' : ''}${delta.round()} vs baseline',
    );
  }

  static SubsystemStatus _bodyStatus(HealthyMeState app) {
    final current = app.currentWeightLb;
    final goal = app.profile.goalWeightLb;
    if (current == null) {
      return const SubsystemStatus(
        name: 'Body',
        level: StatusLevel.noData,
        value: 'No data',
        detail: 'Log or connect weight',
      );
    }

    if (goal == null) {
      return SubsystemStatus(
        name: 'Body',
        level: StatusLevel.good,
        value: '${current.toStringAsFixed(1)} lb',
        detail: 'No weight goal set',
      );
    }

    final remaining = current - goal;
    return SubsystemStatus(
      name: 'Body',
      level: StatusLevel.good,
      value: '${current.toStringAsFixed(1)} lb',
      detail: remaining > 0
          ? '${remaining.toStringAsFixed(1)} lb to goal'
          : 'At or beyond goal',
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

  static SubsystemStatus _recoveryStatus(
    SubsystemStatus sleep,
    SubsystemStatus cardio,
    HealthSnapshot health,
  ) {
    if (sleep.level == StatusLevel.noData &&
        cardio.level == StatusLevel.noData) {
      return const SubsystemStatus(
        name: 'Recovery',
        level: StatusLevel.noData,
        value: 'No data',
        detail: 'Needs sleep or cardio data',
      );
    }

    final levels = [sleep.level, cardio.level];
    final level = levels.contains(StatusLevel.watch)
        ? StatusLevel.watch
        : levels.contains(StatusLevel.fair)
            ? StatusLevel.fair
            : StatusLevel.good;

    final parts = <String>[];
    if (health.hrvMs != null) {
      parts.add('HRV ${health.hrvMs!.round()} ms');
    }
    if (health.sleepMinutes > 0) {
      parts.add(_minutes(health.sleepMinutes));
    }

    return SubsystemStatus(
      name: 'Recovery',
      level: level,
      value: level == StatusLevel.good
          ? 'Good'
          : level == StatusLevel.fair
              ? 'Fair'
              : 'Watch',
      detail: parts.isEmpty ? 'Based on available signals' : parts.join(' • '),
    );
  }

  static List<DailyChange> _changes(
    HealthyMeState app,
    SleepGuidance guidance,
  ) {
    final changes = <DailyChange>[];
    final h = app.health;

    final recentSleep =
        h.sleepMinutes7.where((minutes) => minutes > 0).toList();
    if (h.sleepMinutes > 0 && recentSleep.length >= 3) {
      final previous = recentSleep.length > 1
          ? recentSleep.sublist(0, recentSleep.length - 1)
          : recentSleep;
      final avg =
          previous.reduce((a, b) => a + b) / max(1, previous.length);
      final delta = h.sleepMinutes - avg;
      if (delta.abs() >= 30) {
        changes.add(
          DailyChange(
            title: delta < 0
                ? 'Sleep was shorter than your recent average'
                : 'Sleep was longer than your recent average',
            detail:
                '${_minutes(h.sleepMinutes)} vs ${_minutes(avg.round())} recent average',
            level: delta < -60 ? StatusLevel.watch : StatusLevel.fair,
          ),
        );
      }
    }

    if (h.restingHeartRate != null &&
        h.restingHeartRate30.length >= 4) {
      final values = h.restingHeartRate30;
      final base = values
              .sublist(0, values.length - 1)
              .reduce((a, b) => a + b) /
          (values.length - 1);
      final delta = h.restingHeartRate! - base;
      if (delta.abs() >= 5) {
        changes.add(
          DailyChange(
            title: delta > 0
                ? 'Resting heart rate is above your baseline'
                : 'Resting heart rate is below your baseline',
            detail:
                '${h.restingHeartRate!.round()} bpm (${delta >= 0 ? '+' : ''}${delta.round()} vs baseline)',
            level: delta > 10 ? StatusLevel.watch : StatusLevel.fair,
          ),
        );
      }
    }

    final weights = app.mergedWeightHistory;
    if (weights.length >= 2) {
      final first = weights.first.pounds;
      final last = weights.last.pounds;
      final delta = last - first;
      if (delta.abs() >= 0.5) {
        changes.add(
          DailyChange(
            title: delta < 0
                ? 'Weight trend is moving down'
                : 'Weight trend is moving up',
            detail:
                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} lb across available history',
            level: StatusLevel.good,
          ),
        );
      }
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

  static String _minutes(int total) {
    final hours = total ~/ 60;
    final minutes = total % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
}
