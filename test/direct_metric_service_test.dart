import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/services/direct_metric_service.dart';

void main() {
  test('direct heart rate becomes a real selectable snapshot source', () {
    final service = DirectMetricService();
    final now = DateTime(2026, 10, 6, 15, 0);
    const source = 'ble:AA:BB:CC:DD:EE:FF';

    final merged = service.mergeIntoSnapshot(
      const HealthSnapshot(),
      metricSources: const {},
      samples: [
        DirectMetricSample(
          sourceId: source,
          deviceId: 'AA:BB:CC:DD:EE:FF',
          deviceName: 'vívoactive 6',
          metric: 'Heart rate',
          value: 72,
          unit: 'bpm',
          capturedAt: now,
        ),
      ],
    );

    expect(merged.latestHeartRate, 72);
    expect(merged.availableSources['Heart rate'], contains(source));
    expect(merged.resolvedSources['Heart rate'], source);
    expect(merged.sourceLabels[source], 'vívoactive 6');
    expect(merged.sourceRecordCounts['Heart rate']?[source], 1);
  });

  test('manual Health Connect selection is not overwritten by direct sample', () {
    final service = DirectMetricService();
    final now = DateTime(2026, 10, 6, 15, 0);

    final merged = service.mergeIntoSnapshot(
      HealthSnapshot(
        latestHeartRate: 61,
        freshness: {'Heart rate': now.subtract(const Duration(minutes: 1))},
      ),
      metricSources: const {
        'Heart rate': 'com.samsung.android.app.shealth',
      },
      samples: [
        DirectMetricSample(
          sourceId: 'ble:AA:BB',
          deviceId: 'AA:BB',
          deviceName: 'Watch',
          metric: 'Heart rate',
          value: 74,
          unit: 'bpm',
          capturedAt: now,
        ),
      ],
    );

    expect(merged.latestHeartRate, 61);
    expect(
      merged.availableSources['Heart rate'],
      contains('ble:AA:BB'),
    );
  });
}
