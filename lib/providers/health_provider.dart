import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/data_source.dart';

class ConnectionState {
  final List<DataSource> sources;
  final Map<String, String> selectedSourceByMetric;

  const ConnectionState({
    required this.sources,
    this.selectedSourceByMetric = const {},
  });

  ConnectionState copyWith({
    List<DataSource>? sources,
    Map<String, String>? selectedSourceByMetric,
  }) {
    return ConnectionState(
      sources: sources ?? this.sources,
      selectedSourceByMetric:
          selectedSourceByMetric ?? this.selectedSourceByMetric,
    );
  }
}

class HealthConnectionsNotifier extends Notifier<ConnectionState> {
  @override
  ConnectionState build() {
    return const ConnectionState(
      sources: [
        DataSource(
          id: 'health_connect',
          name: 'Health Connect',
          metrics: {'Steps', 'Sleep', 'Heart rate', 'Weight', 'Workouts'},
        ),
        DataSource(
          id: 'samsung_health',
          name: 'Samsung Health',
          metrics: {'Steps', 'Sleep', 'Heart rate', 'Workouts'},
        ),
        DataSource(
          id: 'fitbit',
          name: 'Fitbit',
          metrics: {'Steps', 'Sleep', 'Heart rate'},
        ),
        DataSource(
          id: 'garmin',
          name: 'Garmin',
          metrics: {'Steps', 'Sleep', 'Heart rate', 'Workouts'},
        ),
        DataSource(
          id: 'smart_scale',
          name: 'Smart Scale',
          metrics: {'Weight', 'Body fat'},
        ),
      ],
    );
  }

  void chooseSource(String metric, String sourceId) {
    final updated = Map<String, String>.from(state.selectedSourceByMetric);
    updated[metric] = sourceId;
    state = state.copyWith(selectedSourceByMetric: updated);
  }
}

final healthConnectionsProvider =
    NotifierProvider<HealthConnectionsNotifier, ConnectionState>(
  HealthConnectionsNotifier.new,
);
