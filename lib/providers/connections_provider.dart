import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_models.dart';
import '../services/storage_service.dart';

const supportedSources = [
  DataSource(
    id: 'health_connect',
    name: 'Health Connect',
    subtitle: 'Android health-data hub',
    metrics: {'Steps', 'Sleep', 'Heart rate', 'Weight', 'Workouts'},
  ),
  DataSource(
    id: 'samsung_health',
    name: 'Samsung Health',
    subtitle: 'Samsung phones and wearables',
    metrics: {'Steps', 'Sleep', 'Heart rate', 'Workouts'},
  ),
  DataSource(
    id: 'fitbit',
    name: 'Fitbit',
    subtitle: 'Fitbit watches and trackers',
    metrics: {'Steps', 'Sleep', 'Heart rate', 'Workouts'},
  ),
  DataSource(
    id: 'garmin',
    name: 'Garmin',
    subtitle: 'Garmin watches and activity data',
    metrics: {'Steps', 'Sleep', 'Heart rate', 'Workouts'},
  ),
  DataSource(
    id: 'smart_scale',
    name: 'Smart Scale',
    subtitle: 'Compatible weight/body-composition scale',
    metrics: {'Weight', 'Body fat'},
  ),
];

class ConnectionsNotifier extends Notifier<ConnectionsState> {
  final _storage = StorageService();

  @override
  ConnectionsState build() => ref.read(bootstrapDataProvider).connections;

  void setPreferredSource(String metric, String sourceId) {
    final next = Map<String, String>.from(state.preferredSourceByMetric);
    if (sourceId == 'auto') {
      next.remove(metric);
    } else {
      next[metric] = sourceId;
    }

    state = state.copyWith(preferredSourceByMetric: next);
    unawaited(_storage.saveConnections(state));
  }
}

final connectionsProvider =
    NotifierProvider<ConnectionsNotifier, ConnectionsState>(
  ConnectionsNotifier.new,
);
