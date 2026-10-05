import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_models.dart';

class WorkoutLibraryState {
  final bool loaded;
  final List<WorkoutTemplate> templates;
  final List<ScheduledWorkout> scheduled;
  final List<CompletedPlannedWorkout> history;

  const WorkoutLibraryState({
    this.loaded = false,
    this.templates = const [],
    this.scheduled = const [],
    this.history = const [],
  });

  WorkoutLibraryState copyWith({
    bool? loaded,
    List<WorkoutTemplate>? templates,
    List<ScheduledWorkout>? scheduled,
    List<CompletedPlannedWorkout>? history,
  }) {
    return WorkoutLibraryState(
      loaded: loaded ?? this.loaded,
      templates: templates ?? this.templates,
      scheduled: scheduled ?? this.scheduled,
      history: history ?? this.history,
    );
  }

  Map<String, dynamic> toJson() => {
        'templates': templates.map((e) => e.toJson()).toList(),
        'scheduled': scheduled.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  factory WorkoutLibraryState.fromJson(Map<String, dynamic> json) {
    return WorkoutLibraryState(
      loaded: true,
      templates: (json['templates'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkoutTemplate.fromJson)
          .toList(),
      scheduled: (json['scheduled'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ScheduledWorkout.fromJson)
          .toList(),
      history: (json['history'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CompletedPlannedWorkout.fromJson)
          .toList(),
    );
  }
}

class WorkoutStateNotifier extends Notifier<WorkoutLibraryState> {
  static const _storageKey = 'salus_workout_library_v1';
  bool _loading = false;

  @override
  WorkoutLibraryState build() {
    if (!_loading) {
      _loading = true;
      unawaited(_load());
    }
    return const WorkoutLibraryState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) {
        state = const WorkoutLibraryState(loaded: true);
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = WorkoutLibraryState.fromJson(decoded);
      } else {
        state = const WorkoutLibraryState(loaded: true);
      }
    } catch (_) {
      state = const WorkoutLibraryState(loaded: true);
    }
  }

  Future<void> _persist(WorkoutLibraryState next) async {
    state = next.copyWith(loaded: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  void saveTemplate(WorkoutTemplate template) {
    final next = [
      for (final item in state.templates)
        if (item.id != template.id) item,
      template,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    unawaited(_persist(state.copyWith(templates: next)));
  }

  void deleteTemplate(String id) {
    unawaited(
      _persist(
        state.copyWith(
          templates: state.templates.where((item) => item.id != id).toList(),
        ),
      ),
    );
  }

  void saveScheduled(ScheduledWorkout workout) {
    final next = [
      for (final item in state.scheduled)
        if (item.id != workout.id) item,
      workout,
    ]..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    unawaited(_persist(state.copyWith(scheduled: next)));
  }

  void deleteScheduled(String id) {
    unawaited(
      _persist(
        state.copyWith(
          scheduled: state.scheduled.where((item) => item.id != id).toList(),
        ),
      ),
    );
  }

  void completeScheduled(String id) {
    ScheduledWorkout? workout;
    for (final item in state.scheduled) {
      if (item.id == id) {
        workout = item;
        break;
      }
    }
    if (workout == null) return;
    final completed = CompletedPlannedWorkout(
      id: workout.id,
      name: workout.name,
      completedAt: DateTime.now(),
      exercises: workout.exercises,
      notes: workout.notes,
    );
    final history = [completed, ...state.history];
    final scheduled = state.scheduled.where((item) => item.id != id).toList();
    unawaited(_persist(state.copyWith(scheduled: scheduled, history: history)));
  }
}

final workoutStateProvider =
    NotifierProvider<WorkoutStateNotifier, WorkoutLibraryState>(
  WorkoutStateNotifier.new,
);
