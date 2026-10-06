import '../models/models.dart';
import 'ble_discovery_service.dart';
import 'source_name_service.dart';

enum SourceTransport {
  healthConnect,
  directBluetooth,
}

class HealthyDataSource {
  final String id;
  final String label;
  final SourceTransport transport;
  final List<String> metrics;
  final Map<String, int> recordCounts;
  final bool selectable;
  final DateTime? lastSeen;
  final String? secondaryLabel;
  final String? note;

  const HealthyDataSource({
    required this.id,
    required this.label,
    required this.transport,
    required this.metrics,
    this.recordCounts = const {},
    required this.selectable,
    this.lastSeen,
    this.secondaryLabel,
    this.note,
  });

  bool provides(String metric) => metrics.contains(metric);
  int recordsFor(String metric) => recordCounts[metric] ?? 0;
  int get totalRecords =>
      recordCounts.values.fold<int>(0, (sum, value) => sum + value);

  String get transportLabel => switch (transport) {
        SourceTransport.healthConnect => 'via Health Connect',
        SourceTransport.directBluetooth => 'Direct Bluetooth',
      };
}

class SourceHubService {
  static List<HealthyDataSource> healthSources(HealthSnapshot health) {
    final rawIds = <String>{
      ...health.detectedSources,
      for (final values in health.availableSources.values) ...values,
    }..removeWhere(SourceNameService.isTransportOnly);

    // Prefer package-origin keys discovered by the native registry, then add
    // any remaining aliases. This prevents one provider appearing twice as a
    // package id and a display name.
    final ids = <String>[];
    final preferred = <String>[
      for (final counts in health.sourceRecordCounts.values) ...counts.keys,
      ...rawIds,
    ];
    for (final raw in preferred) {
      if (raw.isEmpty || SourceNameService.isTransportOnly(raw)) continue;
      if (ids.any((existing) => SourceNameService.sameProvider(existing, raw))) {
        continue;
      }
      ids.add(raw);
    }

    final result = <HealthyDataSource>[];
    for (final id in ids) {
      final metrics = health.availableSources.entries
          .where(
            (entry) => entry.value.any(
              (source) => SourceNameService.sameProvider(source, id),
            ),
          )
          .map((entry) => entry.key)
          .toSet()
          .toList()
        ..sort();

      final recordCounts = <String, int>{};
      for (final entry in health.sourceRecordCounts.entries) {
        for (final sourceEntry in entry.value.entries) {
          if (SourceNameService.sameProvider(sourceEntry.key, id)) {
            recordCounts[entry.key] = sourceEntry.value;
          }
        }
      }

      // SALUS_BUILD26_ACTIVE_SOURCES
      // Do not keep historical provider names around after they have stopped
      // supplying readable records. Direct BLE sources are distinguished from
      // Health Connect origins by their stable ble: source id.
      if (metrics.isEmpty &&
          recordCounts.values.every((count) => count <= 0)) {
        continue;
      }
      final direct = id.startsWith('ble:');

      result.add(
        HealthyDataSource(
          id: id,
          label: health.sourceLabels[id] ?? SourceNameService.friendly(id),
          transport: direct
              ? SourceTransport.directBluetooth
              : SourceTransport.healthConnect,
          metrics: metrics,
          recordCounts: recordCounts,
          selectable: metrics.isNotEmpty,
          lastSeen: health.sourceLastSeen[id],
          note: direct ? 'Read directly from the paired device' : null,
        ),
      );
    }

    result.sort((a, b) => a.label.compareTo(b.label));
    return result;
  }

  static List<HealthyDataSource> healthChoicesForMetric(
    HealthSnapshot health,
    String metric,
  ) {
    return healthSources(health)
        .where((source) => source.selectable && source.provides(metric))
        .toList();
  }

  static List<HealthyDataSource> healthSourcesMissingMetric(
    HealthSnapshot health,
    String metric,
  ) {
    return healthSources(health)
        .where((source) => !source.provides(metric))
        .toList();
  }

  static List<HealthyDataSource> bluetoothSources({
    required List<BleDeviceCandidate> devices,
    required Map<String, BleDeviceInspection> inspections,
  }) {
    final result = <HealthyDataSource>[];

    for (final device in devices) {
      final inspection = inspections[device.id];
      final capabilities = <String>{
        ...(inspection?.capabilities ?? device.capabilities),
      }.map(_normalizeMetric).where((value) => value.isNotEmpty).toList()
        ..sort();

      final profile = inspection?.protocolProfile ?? device.protocolProfile;
      final protocolId = inspection?.protocolId ?? device.protocolId;
      final kind = inspection?.deviceKind ?? device.deviceKind;
      final identifiedAsRing =
          protocolId == 'ring-uart-v1' ||
          kind.toLowerCase().contains('ring');

      final rawName = device.name.trim();
      final unnamed = rawName.isEmpty || rawName == 'Unnamed BLE device';
      final profileLabel = inspection?.protocolProfile ?? device.protocolProfile;
      final label = unnamed
          ? (profileLabel ?? (identifiedAsRing ? 'Smart ring' : 'Bluetooth device'))
          : rawName;

      result.add(
        HealthyDataSource(
          id: 'ble:${device.id}',
          label: label,
          transport: SourceTransport.directBluetooth,
          metrics: capabilities,
          // Discovery/inspection is not the same as a data reader. Keep direct
          // devices out of metric routing until Salus can decode them.
          selectable: false,
          secondaryLabel:
              identifiedAsRing && rawName.isNotEmpty ? rawName : null,
          note: profile == null
              ? null
              : 'Identified by Bluetooth protocol fingerprint',
        ),
      );
    }

    result.sort((a, b) {
      final aUseful = a.metrics.isNotEmpty ? 0 : 1;
      final bUseful = b.metrics.isNotEmpty ? 0 : 1;
      if (aUseful != bUseful) return aUseful.compareTo(bUseful);
      return a.label.compareTo(b.label);
    });
    return result;
  }

  // SALUS_BUILD29_HEALTH_CANDIDATE
  static bool isBluetoothHealthCandidate(HealthyDataSource source) {
    if (source.transport != SourceTransport.directBluetooth) return false;
    const healthMetrics = <String>{
      'Heart rate',
      'Resting heart rate',
      'HRV',
      'SpO2',
      'Respiratory rate',
      'Steps',
      'Sleep',
      'Sleep Stages',
      'Weight',
      'Body fat',
      'Body composition',
      'Blood pressure',
      'Glucose',
      'Temperature',
      'Cadence',
      'Cycling cadence',
      'Workout telemetry',
      'Workouts',
      'Therapy data',
      'Raw motion',
    };
    return source.metrics.any(healthMetrics.contains) ||
        source.note == 'Identified by Bluetooth protocol fingerprint';
  }

  static String _normalizeMetric(String value) {
    return switch (value.trim()) {
      'SpO₂' => 'SpO2',
      'Body composition' => 'Body composition',
      final other => other,
    };
  }
}
