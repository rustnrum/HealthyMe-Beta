#!/usr/bin/env python3
"""Build 73: opt out of Android Impeller for a rendering-isolation test.

The Build 72 install exhibited a strong translucent red compositing artifact
across the application viewport on a Galaxy Fold. This opt-out tests a known
alternate Flutter rendering path without modifying stored data or the UI.
"""
from pathlib import Path
import re

version = Path('pubspec.yaml')
text = version.read_text()
old = 'version: 0.21.34+72'
new = 'version: 0.21.35+73'
if new not in text:
    if text.count(old) != 1:
        raise RuntimeError('Unexpected Salus version: refusing Build 73 overlay')
    version.write_text(text.replace(old, new, 1))

manifest = Path('native/android/AndroidManifest.xml')
text = manifest.read_text()
metadata = '''        <!-- Temporary renderer compatibility test for Galaxy Z Fold7: use OpenGL instead of Impeller. -->
        <meta-data
            android:name="io.flutter.embedding.android.EnableImpeller"
            android:value="false" />
'''
marker = '        <meta-data\n            android:name="flutterEmbedding"'
if 'io.flutter.embedding.android.EnableImpeller' not in text:
    if text.count(marker) != 1:
        raise RuntimeError('Android manifest structure changed: refusing renderer patch')
    text = text.replace(marker, metadata + marker, 1)
    manifest.write_text(text)
else:
    if not re.search(r'android:name="io\.flutter\.embedding\.android\.EnableImpeller"\s+android:value="false"', text):
        raise RuntimeError('Conflicting Impeller metadata')

# This is a compatibility experiment, not proof that the red screen is fixed.
# Assert that we have not replaced the user's module, navigation or data state.
for filename, required in {
    'lib/screens/home_shell.dart': 'SalusPremiumHome()',
    'lib/screens/diet/diet_shell.dart': 'SalusNutritionOverview(',
    'lib/screens/workout_screen.dart': 'SalusTrainingOverview(',
    'lib/app.dart': 'MorningCheckInGate(child: HomeShell())',
}.items():
    if required not in Path(filename).read_text():
        raise RuntimeError(f'Salus feature missing before Build 73: {filename}')
print('Build 73 renderer opt-out and version applied; user data untouched.')
