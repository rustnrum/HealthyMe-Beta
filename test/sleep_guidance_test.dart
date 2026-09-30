import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/sleep_guidance_service.dart';

void main() {
  test('54 year old receives 7 to 9 hour guidance', () {
    final guidance = SleepGuidanceService.forAge(54);
    expect(guidance.label, '7–9 hr');
    expect(guidance.minimumMinutes, 420);
    expect(guidance.upperMinutes, 540);
  });

  test('70 year old receives 7 to 8 hour guidance', () {
    final guidance = SleepGuidanceService.forAge(70);
    expect(guidance.label, '7–8 hr');
    expect(guidance.minimumMinutes, 420);
    expect(guidance.upperMinutes, 480);
  });
}
