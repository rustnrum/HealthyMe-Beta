import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/services/sleep_guidance_service.dart';

void main() {
  test('adult guidance is returned for an adult birthday', () {
    final now = DateTime.now();
    final birthday = DateTime(now.year - 40, 1, 1);
    expect(
      SleepGuidanceService.targetForBirthday(birthday),
      '7–9 hours',
    );
  });
}
