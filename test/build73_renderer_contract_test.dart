import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android renderer metadata and package continuity on Build 73 or later', () {
    final manifest = File('native/android/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('io.flutter.embedding.android.EnableImpeller'));
    expect(manifest, contains('android:value="false"'));

    // This regression test protects the renderer configuration, not an
    // obsolete exact release number. Newer Salus builds are valid as well.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*0\.21\.(\d+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(version, isNotNull, reason: 'Salus version must remain structured');
    final buildNumber = int.parse(version!.group(2)!);
    expect(buildNumber, greaterThanOrEqualTo(73));

    final app = File('lib/app.dart').readAsStringSync();
    expect(app, contains('MorningCheckInGate(child: HomeShell())'));
    final home = File('lib/screens/home_shell.dart').readAsStringSync();
    expect(home, contains('SalusHome85()'));
  });
}
