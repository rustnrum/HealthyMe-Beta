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
  final bool selectable;
  final DateTime? lastSeen;
  final String? secondaryLabel;
  final String? note;

  const HealthyDataSource({
    required this.id,
    required this.label,
    required this.transport,
    required this.metrics,
    required this.selectable,
    this.lastSeen,
    this.secondaryLabel,
    this.note,
  });

  bool provides(String metric) => metrics.contains(metric);

  String get transportLabel => switch (transport) {
        SourceTransport.healthConnect => 'via Health Connect',
        SourceTransport.directBluetooth => 'Direct Bluetooth',
      };
}

class SourceHubService {
  static List<HealthyDataSource> healthSources(HealthSnapshot health) {
    final ids = <String>{
      ...health.detectedSources,
      for (final values in health.availableSources.values) ...values,
    }..removeWhere(SourceNameService.isTransportOnly);

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

      result.add(
        HealthyDataSource(
          id: id,
          label: health.sourceLabels[id] ?? SourceNameService.friendly(id),
          transport: SourceTransport.healthConnect,
          metrics: metrics,
          selectable: metrics.isNotEmpty,
          lastSeen: health.sourceLastSeen[id],
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
      final identifiedAsRing = profile != null &&
          (capabilities.contains('Sleep') ||
              capabilities.contains('Steps')) &&
          (capabilities.contains('Heart rate') ||
              capabilities.contains('SpO2'));

      final rawName = device.name.trim();
      final label = identifiedAsRing
          ? 'Smart ring'
          : rawName.isEmpty || rawName == 'Unnamed BLE device'
              ? 'Bluetooth device'
              : rawName;

      result.add(
        HealthyDataSource(
          id: 'ble:${device.id}',
          label: label,
          transport: SourceTransport.directBluetooth,
          metrics: capabilities,
          // Discovery/inspection is not the same as a data reader. Keep direct
          // devices out of metric routing until Healthy Me can decode them.
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

  static String _normalizeMetric(String value) {
    return switch (value.trim()) {
      'SpO₂' => 'SpO2',
      'Body composition' => 'Body composition',
      final other => other,
    };
  }
}
