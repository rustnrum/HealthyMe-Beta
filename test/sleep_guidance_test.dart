import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/sleep_guidance_service.dart';

void main() {
  test('54 year old receives adult 7+ hour guidance', () {
    final value = SleepGuidanceService.forAge(54);
    expect(value.minimumMinutes, 420);
    expect(value.label, '7+ hr');
  });

  test('70 year old receives 7 to 8 hour guidance', () {
    final value = SleepGuidanceService.forAge(70);
    expect(value.minimumMinutes, 420);
    expect(value.upperMinutes, 480);
  });
}
