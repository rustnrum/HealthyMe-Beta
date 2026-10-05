from pathlib import Path

MARKER = '// HEALTHY_ME_SOURCE_REGISTRY_V011'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'source registry patch: anchor not found for {label}')
    return text.replace(old, new, 1)


def patch_pubspec() -> None:
    path = Path('pubspec.yaml')
    text = path.read_text()
    if 'version: 0.11.0+15' in text:
        return
    text = replace_once(text, 'version: 0.10.0+14', 'version: 0.11.0+15', 'pubspec version')
    path.write_text(text)


def write_registry_service() -> None:
    path = Path('lib/services/health_origin_registry_service.dart')
    path.write_text(r'''import 'package:flutter/services.dart';

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
''')


def patch_models() -> None:
    path = Path('lib/models/models.dart')
    text = path.read_text()
    if 'sourceRecordCounts' in text and 'nativeSourceRegistry' in text:
        return

    text = replace_once(
        text,
        '  final Map<String, DateTime> freshness;\n',
        '  final Map<String, DateTime> freshness;\n'
        '  final Map<String, Map<String, int>> sourceRecordCounts;\n'
        '  final bool nativeSourceRegistry;\n',
        'HealthSnapshot fields',
    )
    text = replace_once(
        text,
        '    this.sourceLastSeen = const {},\n    this.freshness = const {},\n',
        '    this.sourceLastSeen = const {},\n'
        '    this.freshness = const {},\n'
        '    this.sourceRecordCounts = const {},\n'
        '    this.nativeSourceRegistry = false,\n',
        'HealthSnapshot constructor',
    )
    text = replace_once(
        text,
        '    Map<String, DateTime>? sourceLastSeen,\n    Map<String, DateTime>? freshness,\n',
        '    Map<String, DateTime>? sourceLastSeen,\n'
        '    Map<String, DateTime>? freshness,\n'
        '    Map<String, Map<String, int>>? sourceRecordCounts,\n'
        '    bool? nativeSourceRegistry,\n',
        'HealthSnapshot copyWith parameters',
    )
    text = replace_once(
        text,
        '      sourceLastSeen: sourceLastSeen ?? this.sourceLastSeen,\n      freshness: freshness ?? this.freshness,\n',
        '      sourceLastSeen: sourceLastSeen ?? this.sourceLastSeen,\n'
        '      freshness: freshness ?? this.freshness,\n'
        '      sourceRecordCounts: sourceRecordCounts ?? this.sourceRecordCounts,\n'
        '      nativeSourceRegistry:\n'
        '          nativeSourceRegistry ?? this.nativeSourceRegistry,\n',
        'HealthSnapshot copyWith body',
    )
    text = replace_once(
        text,
        "        'freshness': freshness.map(\n"
        "          (key, value) => MapEntry(key, value.toIso8601String()),\n"
        "        ),\n"
        "      };\n",
        "        'freshness': freshness.map(\n"
        "          (key, value) => MapEntry(key, value.toIso8601String()),\n"
        "        ),\n"
        "        'sourceRecordCounts': sourceRecordCounts,\n"
        "        'nativeSourceRegistry': nativeSourceRegistry,\n"
        "      };\n",
        'HealthSnapshot toJson',
    )
    text = replace_once(
        text,
        "    final rawSourceLastSeen =\n        json['sourceLastSeen'] as Map<String, dynamic>? ?? const {};\n",
        "    final rawSourceLastSeen =\n"
        "        json['sourceLastSeen'] as Map<String, dynamic>? ?? const {};\n"
        "    final rawSourceRecordCounts =\n"
        "        json['sourceRecordCounts'] as Map<String, dynamic>? ?? const {};\n",
        'HealthSnapshot fromJson raw counts',
    )
    text = replace_once(
        text,
        "      freshness: rawFresh.map(\n"
        "        (key, value) => MapEntry(\n"
        "          key,\n"
        "          DateTime.tryParse(value.toString()) ?? DateTime.now(),\n"
        "        ),\n"
        "      ),\n",
        "      freshness: rawFresh.map(\n"
        "        (key, value) => MapEntry(\n"
        "          key,\n"
        "          DateTime.tryParse(value.toString()) ?? DateTime.now(),\n"
        "        ),\n"
        "      ),\n"
        "      sourceRecordCounts: rawSourceRecordCounts.map(\n"
        "        (metric, value) => MapEntry(\n"
        "          metric,\n"
        "          (value as Map<String, dynamic>? ?? const {}).map(\n"
        "            (source, count) =>\n"
        "                MapEntry(source, (count as num?)?.toInt() ?? 0),\n"
        "          ),\n"
        "        ),\n"
        "      ),\n"
        "      nativeSourceRegistry: json['nativeSourceRegistry'] == true,\n",
        'HealthSnapshot fromJson values',
    )
    path.write_text(text)


def patch_health_service() -> None:
    path = Path('lib/services/health_connect_service.dart')
    text = path.read_text()
    if MARKER in text:
        return

    text = replace_once(
        text,
        "import 'source_name_service.dart';\n",
        "import 'source_name_service.dart';\n"
        "import 'health_origin_registry_service.dart';\n",
        'health registry import',
    )
    text = replace_once(
        text,
        'class HealthConnectService {\n  final Health _health = Health();\n',
        f'{MARKER}\n'
        'class HealthConnectService {\n'
        '  final Health _health = Health();\n'
        '  final HealthOriginRegistryService _originRegistry =\n'
        '      HealthOriginRegistryService();\n',
        'health registry field',
    )

    text = replace_once(
        text,
        '    points = _health.removeDuplicates(points);\n\n'
        '    String originKey(HealthDataPoint point) => SourceNameService.key(\n',
        '''    // Never dedupe across providers. Cross-provider dedupe can erase the
    // very DataOrigin Healthy Me needs for source routing. Dedupe only inside
    // each provider bucket.
    final providerBuckets = <String, List<HealthDataPoint>>{};
    for (final point in points) {
      final sourceId = point.sourceId.trim();
      final sourceName = point.sourceName.trim();
      final providerKey = sourceId.isNotEmpty ? sourceId : sourceName;
      providerBuckets.putIfAbsent(providerKey, () => <HealthDataPoint>[]).add(point);
    }
    points = [
      for (final bucket in providerBuckets.values)
        ..._health.removeDuplicates(bucket),
    ];

    final nativeRegistry = await _originRegistry.scan(
      startTime: queryStart,
      endTime: now,
    );

    String originKey(HealthDataPoint point) => SourceNameService.key(
''',
        'provider-local dedupe + native scan',
    )

    text = replace_once(
        text,
        '''    for (final point in points) {
      final key = originKey(point);
      if (key.isEmpty) continue;
      sourceLabels[key] = originLabel(point);
      final previous = sourceLastSeen[key];
      if (previous == null || point.dateTo.isAfter(previous)) {
        sourceLastSeen[key] = point.dateTo;
      }
    }

    final sources = sourceLabels.keys
''',
        '''    for (final point in points) {
      final key = originKey(point);
      if (key.isEmpty) continue;
      sourceLabels[key] = originLabel(point);
      final previous = sourceLastSeen[key];
      if (previous == null || point.dateTo.isAfter(previous)) {
        sourceLastSeen[key] = point.dateTo;
      }
    }

    // Native Android Health Connect scans the underlying Record.metadata
    // DataOrigin package name. This registry is independent from Flutter's
    // cross-provider dedupe behavior and is the source of truth for discovery.
    for (final stat in nativeRegistry.allStats()) {
      final key = stat.packageName;
      if (key.isEmpty || SourceNameService.isTransportOnly(key)) continue;
      sourceLabels[key] = stat.label.isEmpty
          ? SourceNameService.friendly(key)
          : SourceNameService.friendly(stat.label);
      final seen = stat.lastSeen;
      final previous = sourceLastSeen[key];
      if (seen != null && (previous == null || seen.isAfter(previous))) {
        sourceLastSeen[key] = seen;
      }
    }

    final sources = sourceLabels.keys
''',
        'native label merge',
    )

    start = text.find('    List<String> originsFor(Iterable<HealthDataType> types) {')
    end = text.find('    return HealthSnapshot(', start)
    if start < 0 or end < 0:
        raise SystemExit('source registry patch: origins/availableSources block not found')
    replacement = '''    Map<String, int> recordCountsFor(
      String metric,
      Iterable<HealthDataType> types,
    ) {
      final counts = <String, int>{};
      final native = nativeRegistry.metrics[metric];
      if (native != null) {
        for (final entry in native.entries) {
          final source = entry.key;
          if (source.isEmpty || SourceNameService.isTransportOnly(source)) continue;
          counts[source] = entry.value.recordCount;
        }
      }

      final allowed = types.toSet();
      for (final point in points) {
        if (!allowed.contains(point.type)) continue;
        final source = originKey(point);
        if (source.isEmpty || SourceNameService.isTransportOnly(source)) continue;
        // Native count wins when present; plugin raw points provide fallback on
        // Android versions where the platform registry is unavailable.
        if (native != null &&
            native.keys.any((key) => SourceNameService.sameProvider(key, source))) {
          continue;
        }
        counts[source] = (counts[source] ?? 0) + 1;
      }
      return counts;
    }

    List<String> sourcesFromCounts(Map<String, int> counts) {
      final values = counts.keys.toList();
      values.sort(
        (a, b) => (sourceLabels[a] ?? SourceNameService.friendly(a))
            .compareTo(sourceLabels[b] ?? SourceNameService.friendly(b)),
      );
      return values;
    }

    final sourceRecordCounts = <String, Map<String, int>>{
      'Steps': recordCountsFor('Steps', [HealthDataType.STEPS]),
      'Sleep': recordCountsFor('Sleep', sleepTypes),
      'Heart rate': recordCountsFor('Heart rate', [HealthDataType.HEART_RATE]),
      'Resting heart rate': recordCountsFor(
        'Resting heart rate',
        [HealthDataType.RESTING_HEART_RATE],
      ),
      'HRV': recordCountsFor(
        'HRV',
        [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
      ),
      'Respiratory rate': recordCountsFor(
        'Respiratory rate',
        [HealthDataType.RESPIRATORY_RATE],
      ),
      'SpO2': recordCountsFor('SpO2', [HealthDataType.BLOOD_OXYGEN]),
      'Weight': recordCountsFor('Weight', [HealthDataType.WEIGHT]),
      'Body fat': recordCountsFor(
        'Body fat',
        [HealthDataType.BODY_FAT_PERCENTAGE],
      ),
      'Body water': recordCountsFor(
        'Body water',
        [HealthDataType.BODY_WATER_MASS],
      ),
      'Lean body mass': recordCountsFor(
        'Lean body mass',
        [HealthDataType.LEAN_BODY_MASS],
      ),
      'Workouts': recordCountsFor('Workouts', [HealthDataType.WORKOUT]),
    };

    final availableSources = <String, List<String>>{
      for (final entry in sourceRecordCounts.entries)
        entry.key: sourcesFromCounts(entry.value),
    };

'''
    text = text[:start] + replacement + text[end:]

    text = replace_once(
        text,
        '      sourceLastSeen: sourceLastSeen,\n      freshness: freshness,\n',
        '      sourceLastSeen: sourceLastSeen,\n'
        '      freshness: freshness,\n'
        '      sourceRecordCounts: sourceRecordCounts,\n'
        '      nativeSourceRegistry: nativeRegistry.nativeSupported,\n',
        'HealthSnapshot registry result',
    )

    path.write_text(text)


def patch_sync_provider() -> None:
    path = Path('lib/state/health_sync_provider.dart')
    text = path.read_text()
    # Current source lists must reflect the latest raw/native registry scan.
    # Historical detected providers and last-seen timestamps remain retained.
    function_start = text.find('    Map<String, List<String>> mergeSourceLists(')
    if function_start >= 0:
        function_end = text.find('    final previous = app.health;', function_start)
        if function_end < 0:
            raise SystemExit('source registry patch: mergeSourceLists end not found')
        text = text[:function_start] + text[function_end:]

    old = '''      availableSources: mergeSourceLists(
        previous.availableSources,
        snapshot.availableSources,
      ),
'''
    if old in text:
        text = text.replace(
            old,
            '      availableSources: snapshot.availableSources,\n',
            1,
        )
    elif 'availableSources: snapshot.availableSources' not in text:
        raise SystemExit('source registry patch: availableSources merge anchor not found')
    path.write_text(text)


def patch_source_hub() -> None:
    path = Path('lib/services/source_hub_service.dart')
    text = path.read_text()
    if 'recordCounts' in text:
        return

    old_ids = '''    final ids = <String>{
      ...health.detectedSources,
      for (final values in health.availableSources.values) ...values,
    }..removeWhere(SourceNameService.isTransportOnly);

'''
    new_ids = '''    final rawIds = <String>{
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

'''
    text = replace_once(text, old_ids, new_ids, 'SourceHub canonical provider ids')

    text = replace_once(
        text,
        '  final List<String> metrics;\n  final bool selectable;\n',
        '  final List<String> metrics;\n'
        '  final Map<String, int> recordCounts;\n'
        '  final bool selectable;\n',
        'HealthyDataSource recordCounts field',
    )
    text = replace_once(
        text,
        '    required this.metrics,\n    required this.selectable,\n',
        '    required this.metrics,\n'
        '    this.recordCounts = const {},\n'
        '    required this.selectable,\n',
        'HealthyDataSource constructor',
    )
    text = replace_once(
        text,
        '  bool provides(String metric) => metrics.contains(metric);\n\n',
        '  bool provides(String metric) => metrics.contains(metric);\n'
        '  int recordsFor(String metric) => recordCounts[metric] ?? 0;\n'
        '  int get totalRecords =>\n'
        '      recordCounts.values.fold<int>(0, (sum, value) => sum + value);\n\n',
        'HealthyDataSource helpers',
    )
    text = replace_once(
        text,
        '''      result.add(
        HealthyDataSource(
          id: id,
          label: health.sourceLabels[id] ?? SourceNameService.friendly(id),
          transport: SourceTransport.healthConnect,
          metrics: metrics,
          selectable: metrics.isNotEmpty,
          lastSeen: health.sourceLastSeen[id],
        ),
      );
''',
        '''      final recordCounts = <String, int>{};
      for (final entry in health.sourceRecordCounts.entries) {
        for (final sourceEntry in entry.value.entries) {
          if (SourceNameService.sameProvider(sourceEntry.key, id)) {
            recordCounts[entry.key] = sourceEntry.value;
          }
        }
      }

      result.add(
        HealthyDataSource(
          id: id,
          label: health.sourceLabels[id] ?? SourceNameService.friendly(id),
          transport: SourceTransport.healthConnect,
          metrics: metrics,
          recordCounts: recordCounts,
          selectable: metrics.isNotEmpty,
          lastSeen: health.sourceLastSeen[id],
        ),
      );
''',
        'SourceHub health source record counts',
    )
    path.write_text(text)


def patch_sources_screen() -> None:
    path = Path('lib/screens/sources_screen.dart')
    text = path.read_text()
    text = text.replace(
        "static const _buildLabel = 'Beta 0.10.0+14 • Healthy Me Source Hub';",
        "static const _buildLabel = 'Beta 0.11.0+15 • Healthy Me Source Registry';",
        1,
    )

    old_choice = "                  subtitle: '${source.transportLabel} • use only for $metric',\n"
    new_choice = "                  subtitle: '${source.transportLabel} • ${source.recordsFor(metric)} records • use only for $metric',\n"
    if old_choice in text:
        text = text.replace(old_choice, new_choice, 1)
    elif '${source.recordsFor(metric)} records' not in text:
        raise SystemExit('source registry patch: source choice subtitle anchor not found')

    old_metrics = '''    final metrics = source.metrics.isEmpty
        ? 'No readable metrics yet'
        : source.metrics.join(' • ');
'''
    new_metrics = '''    final metrics = source.metrics.isEmpty
        ? 'No readable metrics yet'
        : source.metrics
            .map((metric) {
              final count = source.recordsFor(metric);
              return count > 0 ? '$metric ($count)' : metric;
            })
            .join(' • ');
'''
    if old_metrics in text:
        text = text.replace(old_metrics, new_metrics, 1)
    elif 'final count = source.recordsFor(metric);' not in text:
        raise SystemExit('source registry patch: provider metric count anchor not found')

    path.write_text(text)


def patch_android_label() -> None:
    # This patch runs after prepare_android.sh has generated the Android shell,
    # so update both the current manifest and the script used by later builds.
    manifest = Path('android/app/src/main/AndroidManifest.xml')
    if manifest.exists():
        text = manifest.read_text()
        text = text.replace('android:label="Healthy Me Beta 0.10"',
                            'android:label="Healthy Me Beta 0.11"', 1)
        manifest.write_text(text)

    prepare = Path('scripts/prepare_android.sh')
    if prepare.exists():
        text = prepare.read_text()
        text = text.replace('android:label="Healthy Me Beta 0.10"',
                            'android:label="Healthy Me Beta 0.11"')
        text = text.replace("'android:label=\"Healthy Me Beta 0.10\"'",
                            "'android:label=\"Healthy Me Beta 0.11\"'")
        text = text.replace(
            'private const val HEALTH_CONNECT_SERVICE_NAME = "health_connect"',
            'private const val HEALTH_CONNECT_SERVICE_NAME = "healthconnect"',
        )
        prepare.write_text(text)


def write_tests() -> None:
    Path('test/health_origin_registry_service_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/health_origin_registry_service.dart';
import 'package:healthy_me/services/source_hub_service.dart';

void main() {
  test('native registry parser preserves package origins and counts', () {
    final registry = HealthOriginRegistry.fromPlatform({
      'supported': true,
      'metrics': {
        'Weight': [
          {
            'packageName': 'com.xs.imoni',
            'label': 'iMoni',
            'recordCount': 4,
            'lastSeenMillis': 1760000000000,
          },
        ],
        'Sleep': [
          {
            'packageName': 'com.app.cq.ring',
            'label': 'QRing',
            'recordCount': 22,
            'lastSeenMillis': 1760000000000,
          },
        ],
      },
    });

    expect(registry.nativeSupported, isTrue);
    expect(registry.metrics['Weight']!['com.xs.imoni']!.label, 'iMoni');
    expect(registry.metrics['Weight']!['com.xs.imoni']!.recordCount, 4);
    expect(registry.metrics['Sleep']!['com.app.cq.ring']!.label, 'QRing');
  });

  test('source hub exposes native record counts per provider and metric', () {
    const snapshot = HealthSnapshot(
      detectedSources: ['com.xs.imoni', 'com.app.cq.ring'],
      availableSources: {
        'Weight': ['com.xs.imoni'],
        'Sleep': ['com.app.cq.ring'],
      },
      sourceLabels: {
        'com.xs.imoni': 'iMoni',
        'com.app.cq.ring': 'QRing',
      },
      sourceRecordCounts: {
        'Weight': {'com.xs.imoni': 4},
        'Sleep': {'com.app.cq.ring': 22},
      },
      nativeSourceRegistry: true,
    );

    final sources = SourceHubService.healthSources(snapshot);
    final imoni = sources.singleWhere((source) => source.label == 'iMoni');
    final qring = sources.singleWhere((source) => source.label == 'QRing');

    expect(imoni.recordsFor('Weight'), 4);
    expect(qring.recordsFor('Sleep'), 22);
    expect(SourceHubService.healthChoicesForMetric(snapshot, 'Weight').single.id,
        'com.xs.imoni');
  });

  test('source hub collapses package and display aliases to one provider', () {
    const snapshot = HealthSnapshot(
      detectedSources: ['iMoni'],
      availableSources: {
        'Weight': ['iMoni', 'com.xs.imoni'],
      },
      sourceLabels: {
        'com.xs.imoni': 'iMoni',
        'iMoni': 'iMoni',
      },
      sourceRecordCounts: {
        'Weight': {'com.xs.imoni': 4},
      },
    );

    final sources = SourceHubService.healthSources(snapshot);
    expect(sources.where((source) => source.label == 'iMoni'), hasLength(1));
    expect(sources.single.id, 'com.xs.imoni');
  });

  test('HealthSnapshot registry fields survive JSON round trip', () {
    const original = HealthSnapshot(
      sourceRecordCounts: {
        'SpO2': {'com.app.cq.ring': 9},
      },
      nativeSourceRegistry: true,
    );

    final restored = HealthSnapshot.fromJson(original.toJson());
    expect(restored.nativeSourceRegistry, isTrue);
    expect(restored.sourceRecordCounts['SpO2']!['com.app.cq.ring'], 9);
  });
}
''')


def main() -> None:
    patch_pubspec()
    write_registry_service()
    patch_models()
    patch_health_service()
    patch_sync_provider()
    patch_source_hub()
    patch_sources_screen()
    patch_android_label()
    write_tests()
    print('Healthy Me v0.11 native source registry Dart layer applied.')


if __name__ == '__main__':
    main()
