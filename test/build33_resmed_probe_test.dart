import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/direct_metric_service.dart';

void main() {
  test('ResMed probe result preserves diagnostics without inventing therapy metrics', () {
    const result = DirectMetricReadResult(
      metrics: {},
      message: 'ResMed connected.',
      reader: 'ResMed read-only BLE probe',
      observations: ['read • uuid = 0102'],
      diagnostics: {
        'readCount': 1,
        'notificationCount': 0,
        'subscriptionCount': 2,
      },
    );

    expect(result.hasMetrics, isFalse);
    expect(result.observations, hasLength(1));
    expect(result.diagnostics['readCount'], 1);
    expect(result.reader, contains('ResMed'));
  });
}
