import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Build 74 has no full-screen MaterialApp voice Stack', () {
    final app = File('lib/app.dart').readAsStringSync();
    expect(app.contains('builder: (context, child) => Stack(fit: StackFit.expand'), isFalse);
    expect(app.contains("'/voice': (_) => const SalusVoiceScreen()"), isTrue);
    for (final path in [
      'lib/screens/home_shell.dart',
      'lib/screens/diet/diet_shell.dart',
      'lib/screens/health/health_shell.dart',
      'lib/screens/workout_screen.dart',
    ]) {
      expect(File(path).readAsStringSync().contains('SalusVoiceLauncher('), isTrue, reason: path);
    }
  });
}
