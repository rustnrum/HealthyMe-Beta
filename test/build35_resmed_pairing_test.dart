import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/direct_metric_service.dart';

void main() {
  test('ResMed pairing code validation requires exactly four digits', () {
    expect(DirectMetricService.isValidCpapPasskey('1234'), isTrue);
    expect(DirectMetricService.isValidCpapPasskey('0007'), isTrue);
    expect(DirectMetricService.isValidCpapPasskey('123'), isFalse);
    expect(DirectMetricService.isValidCpapPasskey('12345'), isFalse);
    expect(DirectMetricService.isValidCpapPasskey('12a4'), isFalse);
  });
}
