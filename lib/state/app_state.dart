import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_state.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class HealthyMeState {
  final UserProfile profile;
  final HealthSnapshot health;
  final BodyMeasurements measurements;
  final List<WeightPoint> manualWeights;
  final List<LabResult> labs;
  final List<ProgressPhoto> photos;
  final Map<String, String> metricSources;
  final bool dailyStateEnabled;
  final int dailyStateStartMinutes;
  final List<DailyStateEntry> dailyStates;

  const HealthyMeState({
    this.profile = const UserProfile(),
    this.health = const HealthSnapshot(),
    this.measurements = const BodyMeasurements(),
    this.manualWeights = const [],
    this.labs = const [],
    this.photos = const [],
    this.metricSources = const {},
    this.dailyStateEnabled = true,
    this.dailyStateStartMinutes = 8 * 60,
    this.dailyStates = const [],
  });

  double? get currentWeightLb =>
      health.weightLb ?? profile.manualCurrentWeightLb;

  List<WeightPoint> get mergedWeightHistory {
    final all = [...health.weightHistory, ...manualWeights];
    all.sort((a, b) => a.date.compareTo(b.date));
    return all;
  }

  HealthyMeState copyWith({
    UserProfile? profile,
    HealthSnapshot? health,
    BodyMeasurements? measurements,
    List<WeightPoint>? manualWeights,
    List<LabResult>? labs,
    List<ProgressPhoto>? photos,
    Map<String, String>? metricSources,
    bool? dailyStateEnabled,
    int? dailyStateStartMinutes,
    List<DailyStateEntry>? dailyStates,
  }) {
    return HealthyMeState(
      profile: profile ?? this.profile,
      health: health ?? this.health,
      measurements: measurements ?? this.measurements,
      manualWeights: manualWeights ?? this.manualWeights,
      labs: labs ?? this.labs,
      photos: photos ?? this.photos,
      metricSources: metricSources ?? this.metricSources,
      dailyStateEnabled: dailyStateEnabled ?? this.dailyStateEnabled,
      dailyStateStartMinutes:
          dailyStateStartMinutes ?? this.dailyStateStartMinutes,
      dailyStates: dailyStates ?? this.dailyStates,
    );
  }

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'health': health.toJson(),
        'measurements': measurements.toJson(),
        'manualWeights': manualWeights.map((e) => e.toJson()).toList(),
        'labs': labs.map((e) => e.toJson()).toList(),
        'photos': photos.map((e) => e.toJson()).toList(),
        'metricSources': metricSources,
        'dailyStateEnabled': dailyStateEnabled,
        'dailyStateStartMinutes': dailyStateStartMinutes,
        'dailyStates': dailyStates.map((e) => e.toJson()).toList(),
      };

  factory HealthyMeState.fromJson(Map<String, dynamic> json) {
    return HealthyMeState(
      profile: UserProfile.fromJson(
        json['profile'] as Map<String, dynamic>? ?? const {},
      ),
      health: HealthSnapshot.fromJson(
        json['health'] as Map<String, dynamic>? ?? const {},
      ),
      measurements: BodyMeasurements.fromJson(
        json['measurements'] as Map<String, dynamic>? ?? const {},
      ),
      manualWeights:
          (json['manualWeights'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(WeightPoint.fromJson)
              .toList(),
      labs:
          (json['labs'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(LabResult.fromJson)
              .toList(),
      photos:
          (json['photos'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(ProgressPhoto.fromJson)
              .toList(),
      metricSources:
          (json['metricSources'] as Map<String, dynamic>? ?? const {})
              .map((key, value) => MapEntry(key, value.toString())),
      dailyStateEnabled: json['dailyStateEnabled'] != false,
      dailyStateStartMinutes:
          ((json['dailyStateStartMinutes'] as num?)?.toInt() ?? 8 * 60)
              .clamp(0, (24 * 60) - 1)
              .toInt(),
      dailyStates:
          (json['dailyStates'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(DailyStateEntry.fromJson)
              .toList(),
    );
  }

  String encode() => jsonEncode(toJson());
}

final initialAppStateProvider = Provider<HealthyMeState>(
  (ref) => throw UnimplementedError('Initial state must be overridden.'),
);

class AppStateNotifier extends Notifier<HealthyMeState> {
  final _storage = StorageService();

  @override
  HealthyMeState build() => ref.read(initialAppStateProvider);

  void _set(HealthyMeState next) {
    state = next;
    unawaited(_storage.save(next));
  }

  void saveProfile(UserProfile profile) {
    _set(state.copyWith(profile: profile));
  }

  void saveMeasurements(BodyMeasurements measurements) {
    _set(state.copyWith(measurements: measurements));
  }

  void setHealthSnapshot(HealthSnapshot health) {
    _set(state.copyWith(health: _enforceSingleSleepSource(health)));
  }

  HealthSnapshot _enforceSingleSleepSource(HealthSnapshot health) {
    final sleepSource = health.resolvedSources['Sleep'];
    final stageSource = health.resolvedSources['Sleep Stages'];

    if (sleepSource != null && stageSource == sleepSource) {
      return health;
    }

    final resolved = Map<String, String>.from(health.resolvedSources)
      ..remove('Sleep Stages');
    final freshness = Map<String, DateTime>.from(health.freshness)
      ..remove('Sleep Stages');

    // A sleep session belongs to one provider. If stage attribution does not
    // match the provider that owns Sleep, stage values are treated as missing
    // instead of being silently blended into the session.
    return health.copyWith(
      sleepAwakeMinutes: 0,
      sleepRemMinutes: 0,
      sleepLightMinutes: 0,
      sleepDeepMinutes: 0,
      resolvedSources: resolved,
      freshness: freshness,
    );
  }

  void setHealthAuthorization(bool authorized) {
    _set(
      state.copyWith(
        health: state.health.copyWith(
          authorized: authorized,
          clearError: authorized,
        ),
      ),
    );
  }

  void setHealthError(String message) {
    _set(
      state.copyWith(
        health: state.health.copyWith(error: message),
      ),
    );
  }

  void logManualWeight(double pounds) {
    final point = WeightPoint(
      date: DateTime.now(),
      pounds: pounds,
      source: 'Manual',
    );
    final profile = state.profile.copyWith(
      manualCurrentWeightLb: pounds,
      startingWeightLb: state.profile.startingWeightLb ?? pounds,
    );
    _set(
      state.copyWith(
        profile: profile,
        manualWeights: [...state.manualWeights, point],
      ),
    );
  }

  void addLab(LabResult lab) {
    _set(state.copyWith(labs: [...state.labs, lab]));
  }

  void updateLab(LabResult lab) {
    _set(
      state.copyWith(
        labs: [
          for (final item in state.labs)
            if (item.id == lab.id) lab else item,
        ],
      ),
    );
  }

  void removeLab(String id) {
    _set(
      state.copyWith(
        labs: state.labs.where((item) => item.id != id).toList(),
      ),
    );
  }

  void addLabs(Iterable<LabResult> labs) {
    _set(state.copyWith(labs: [...state.labs, ...labs]));
  }

  void addPhoto(ProgressPhoto photo) {
    _set(state.copyWith(photos: [...state.photos, photo]));
  }

  void removePhoto(String id) {
    _set(
      state.copyWith(photos: state.photos.where((item) => item.id != id).toList()),
    );
  }

  void setMetricSource(String metric, String source) {
    final next = Map<String, String>.from(state.metricSources);
    final routingMetric = metric == 'Sleep Stages' ? 'Sleep' : metric;

    if (source == 'Auto') {
      next.remove(routingMetric);
      if (routingMetric == 'Sleep') next.remove('Sleep Stages');
    } else {
      next[routingMetric] = source;
      if (routingMetric == 'Sleep') next['Sleep Stages'] = source;
    }
    _set(state.copyWith(metricSources: next));
  }

  void setSleepWindow({required int bedtimeMinutes, required int wakeMinutes}) {
    final bed = bedtimeMinutes.clamp(0, (24 * 60) - 1).toInt();
    final wake = wakeMinutes.clamp(0, (24 * 60) - 1).toInt();
    _set(
      state.copyWith(
        profile: state.profile.copyWith(
          sleepBedtimeMinutes: bed,
          sleepWakeMinutes: wake,
        ),
      ),
    );
  }

  void setDailyStateSettings({bool? enabled, int? startMinutes}) {
    _set(
      state.copyWith(
        dailyStateEnabled: enabled ?? state.dailyStateEnabled,
        dailyStateStartMinutes: (startMinutes ?? state.dailyStateStartMinutes)
            .clamp(0, (24 * 60) - 1)
            .toInt(),
      ),
    );
  }

  void saveDailyState(DailyStateEntry entry) {
    final next = [
      for (final item in state.dailyStates)
        if (item.dayKey != entry.dayKey) item,
      entry,
    ]..sort((a, b) => a.date.compareTo(b.date));
    _set(state.copyWith(dailyStates: next));
  }

  void markDailyStateToday(String status) {
    saveDailyState(DailyStateEntry(date: DateTime.now(), status: status));
  }

  void setDailyStateFeedback(String dayKey, String feedback) {
    final next = [
      for (final item in state.dailyStates)
        if (item.dayKey == dayKey)
          item.copyWith(resetFeedback: feedback)
        else
          item,
    ];
    _set(state.copyWith(dailyStates: next));
  }
}

final appStateProvider =
    NotifierProvider<AppStateNotifier, HealthyMeState>(AppStateNotifier.new);
