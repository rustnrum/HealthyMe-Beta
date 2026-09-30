import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  const HealthyMeState({
    this.profile = const UserProfile(),
    this.health = const HealthSnapshot(),
    this.measurements = const BodyMeasurements(),
    this.manualWeights = const [],
    this.labs = const [],
    this.photos = const [],
    this.metricSources = const {},
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
  }) {
    return HealthyMeState(
      profile: profile ?? this.profile,
      health: health ?? this.health,
      measurements: measurements ?? this.measurements,
      manualWeights: manualWeights ?? this.manualWeights,
      labs: labs ?? this.labs,
      photos: photos ?? this.photos,
      metricSources: metricSources ?? this.metricSources,
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
    _set(state.copyWith(health: health));
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
      state.copyWith(
        photos: state.photos.where((item) => item.id != id).toList(),
      ),
    );
  }

  void setMetricSource(String metric, String source) {
    final next = Map<String, String>.from(state.metricSources);
    if (source == 'Auto') {
      next.remove(metric);
    } else {
      next[metric] = source;
    }
    _set(state.copyWith(metricSources: next));
  }
}

final appStateProvider =
    NotifierProvider<AppStateNotifier, HealthyMeState>(AppStateNotifier.new);
