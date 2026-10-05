import 'package:flutter_test/flutter_test.dart';
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
