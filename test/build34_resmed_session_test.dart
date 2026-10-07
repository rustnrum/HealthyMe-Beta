import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/direct_metric_service.dart';

void main() {
  test('CPAP remains a dedicated therapy protocol while secure reader is enabled', () {
    expect(DirectMetricService.isTherapyOnlyProtocol('cpap-family'), isTrue);
    expect(DirectMetricService.isTherapyOnlyProtocol('garmin-family'), isFalse);
  });
}
