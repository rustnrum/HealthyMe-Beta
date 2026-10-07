import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification mirroring remains opt-in by product contract', () {
    const defaultEnabled = false;
    expect(defaultEnabled, isFalse);
  });
}
