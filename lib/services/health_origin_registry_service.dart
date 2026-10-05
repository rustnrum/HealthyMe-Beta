import 'package:flutter/services.dart';

class HealthOriginStat {
  final String packageName;
  final String label;
  final int recordCount;
  final DateTime? lastSeen;

  const HealthOriginStat({
    required this.packageName,
    required this.label,
    required this.recordCount,
    required this.lastSeen,
  });

  factory HealthOriginStat.fromPlatform(Map<Object?, Object?> raw) {
    final lastSeenMillis = (raw['lastSeenMillis'] as num?)?.toInt();
    return HealthOriginStat(
      packageName: raw['packageName']?.toString().trim() ?? '',
      label: raw['label']?.toString().trim() ?? '',
      recordCount: (raw['recordCount'] as num?)?.toInt() ?? 0,
      lastSeen: lastSeenMillis == null || lastSeenMillis <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSeenMillis),
    );
  }
}

class HealthOriginRegistry {
  final bool nativeSupported;
  final Map<String, Map<String, HealthOriginStat>> metrics;
  final String? message;

  const HealthOriginRegistry({
    this.nativeSupported = false,
    this.metrics = const {},
    this.message,
  });

  factory HealthOriginRegistry.fromPlatform(dynamic raw) {
    if (raw is! Map) return const HealthOriginRegistry();

    final nativeSupported = raw['supported'] == true;
    final message = raw['message']?.toString();
    final rawMetrics = raw['metrics'];
    final metrics = <String, Map<String, HealthOriginStat>>{};

    if (rawMetrics is Map) {
      for (final metricEntry in rawMetrics.entries) {
        final metric = metricEntry.key?.toString().trim() ?? '';
        if (metric.isEmpty || metricEntry.value is! List) continue;

        final byPackage = <String, HealthOriginStat>{};
        for (final item in metricEntry.value as List) {
          if (item is! Map) continue;
          final stat = HealthOriginStat.fromPlatform(
            Map<Object?, Object?>.from(item),
          );
          if (stat.packageName.isEmpty) continue;
          byPackage[stat.packageName] = stat;
        }
        metrics[metric] = byPackage;
      }
    }

    return HealthOriginRegistry(
      nativeSupported: nativeSupported,
      metrics: metrics,
      message: message,
    );
  }

  Iterable<HealthOriginStat> allStats() sync* {
    for (final metric in metrics.values) {
      yield* metric.values;
    }
  }
}

class HealthOriginRegistryService {
  static const _channel =
      MethodChannel('com.rustnrum.healthyme/source_discovery');

  HealthOriginRegistry? _cached;
  DateTime? _cachedAt;

  Future<HealthOriginRegistry> scan({
    required DateTime startTime,
    required DateTime endTime,
    bool force = false,
  }) async {
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (!force &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(minutes: 5)) {
      return cached;
    }

    try {
      final raw = await _channel.invokeMethod<dynamic>(
        'scanHealthOrigins',
        {
          'startMillis': startTime.millisecondsSinceEpoch,
          'endMillis': endTime.millisecondsSinceEpoch,
        },
      );
      final value = HealthOriginRegistry.fromPlatform(raw);
      _cached = value;
      _cachedAt = DateTime.now();
      return value;
    } on MissingPluginException {
      return const HealthOriginRegistry(
        message: 'Native source registry is unavailable on this build.',
      );
    } on PlatformException catch (error) {
      return HealthOriginRegistry(
        message: error.message ?? error.code,
      );
    }
  }
}
