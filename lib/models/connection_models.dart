class DataSource {
  final String id;
  final String name;
  final String subtitle;
  final Set<String> metrics;
  final bool setupAvailable;

  const DataSource({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.metrics,
    this.setupAvailable = false,
  });
}

class ConnectionsState {
  final Map<String, String> preferredSourceByMetric;
  final Set<String> connectedSourceIds;

  const ConnectionsState({
    this.preferredSourceByMetric = const {},
    this.connectedSourceIds = const {},
  });

  Map<String, dynamic> toJson() => {
        'preferredSourceByMetric': preferredSourceByMetric,
        'connectedSourceIds': connectedSourceIds.toList(),
      };

  factory ConnectionsState.fromJson(Map<String, dynamic> json) {
    final sourceMap =
        json['preferredSourceByMetric'] as Map<String, dynamic>? ?? const {};
    final connected =
        (json['connectedSourceIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toSet();

    return ConnectionsState(
      preferredSourceByMetric:
          sourceMap.map((key, value) => MapEntry(key, value.toString())),
      connectedSourceIds: connected,
    );
  }

  ConnectionsState copyWith({
    Map<String, String>? preferredSourceByMetric,
    Set<String>? connectedSourceIds,
  }) {
    return ConnectionsState(
      preferredSourceByMetric:
          preferredSourceByMetric ?? this.preferredSourceByMetric,
      connectedSourceIds: connectedSourceIds ?? this.connectedSourceIds,
    );
  }
}
