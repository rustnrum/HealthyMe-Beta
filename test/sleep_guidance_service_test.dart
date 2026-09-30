import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/sleep_guidance_service.dart';

void main() {
  test('adult 18 to 60 gets 7+ hour guidance', () {
    expect(SleepGuidanceService.forAge(54).target, '7+ hr');
  });

  test('adult 65+ gets 7 to 8 hour guidance', () {
    expect(SleepGuidanceService.forAge(70).target, '7–8 hr');
  });

  test('teen gets 8 to 10 hour guidance', () {
    expect(SleepGuidanceService.forAge(16).target, '8–10 hr');
  });
}
