import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Build 73 Android renderer metadata and package continuity', () {
    final manifest = File('native/android/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('io.flutter.embedding.android.EnableImpeller'));
    expect(manifest, contains('android:value="false"'));
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: 0.21.35+73'));
    final app = File('lib/app.dart').readAsStringSync();
    expect(app, contains('MorningCheckInGate(child: HomeShell())'));
    final home = File('lib/screens/home_shell.dart').readAsStringSync();
    expect(home, contains('SalusPremiumHome()'));
  });
}
