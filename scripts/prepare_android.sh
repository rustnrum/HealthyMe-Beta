#!/usr/bin/env bash
set -euo pipefail

MANIFEST="android/app/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST" ]; then
  echo "AndroidManifest.xml not found"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

path = Path("android/app/src/main/AndroidManifest.xml")
text = path.read_text()

marker = "HEALTHY_ME_HEALTH_CONNECT"
if marker not in text:
    permissions = f"""
    <!-- {marker}: read-only Health Connect permissions -->
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
    <uses-permission android:name="android.permission.health.READ_STEPS" />
    <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED" />
    <uses-permission android:name="android.permission.health.READ_DISTANCE" />
    <uses-permission android:name="android.permission.health.READ_HEART_RATE" />
    <uses-permission android:name="android.permission.health.READ_RESTING_HEART_RATE" />
    <uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY" />
    <uses-permission android:name="android.permission.health.READ_RESPIRATORY_RATE" />
    <uses-permission android:name="android.permission.health.READ_OXYGEN_SATURATION" />
    <uses-permission android:name="android.permission.health.READ_WEIGHT" />
    <uses-permission android:name="android.permission.health.READ_BODY_FAT" />
    <uses-permission android:name="android.permission.health.READ_SLEEP" />
    <uses-permission android:name="android.permission.health.READ_EXERCISE" />
    <uses-permission android:name="android.permission.health.READ_HEALTH_DATA_HISTORY" />
"""

    manifest_end = text.find(">")
    text = text[:manifest_end + 1] + permissions + text[manifest_end + 1:]

    queries = """
    <queries>
        <package android:name="com.google.android.apps.healthdata" />
        <intent>
            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
        </intent>
    </queries>
"""
    text = text.replace("    <application", queries + "\n    <application", 1)

    rationale = """
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>
"""
    text = text.replace("        </activity>", rationale + "        </activity>", 1)

    alias = """
        <activity-alias
            android:name="ViewPermissionUsageActivity"
            android:exported="true"
            android:targetActivity=".MainActivity"
            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
            <intent-filter>
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
                <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
            </intent-filter>
        </activity-alias>
"""
    text = text.replace("    </application>", alias + "    </application>", 1)

path.write_text(text)
PY

MAIN_ACTIVITY="$(find android/app/src/main/kotlin -name MainActivity.kt -print -quit 2>/dev/null || true)"
if [ -n "$MAIN_ACTIVITY" ]; then
  sed -i \
    's/import io\.flutter\.embedding\.android\.FlutterActivity/import io.flutter.embedding.android.FlutterFragmentActivity/' \
    "$MAIN_ACTIVITY"
  sed -i \
    's/: FlutterActivity()/: FlutterFragmentActivity()/' \
    "$MAIN_ACTIVITY"
  # Give this redesigned beta an unmistakable package identity so it cannot
  # be confused with or silently launch the old v0.2 beta.
  sed -i -E \
    's/^package[[:space:]]+com\.rustnrum\.[A-Za-z0-9_.]+/package com.rustnrum.healthyme.beta03/' \
    "$MAIN_ACTIVITY"
fi

python3 - <<'PYGRADLE'
from pathlib import Path
import re

for name in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    path = Path(name)
    if not path.exists():
        continue
    text = path.read_text()
    text = text.replace('minSdk = flutter.minSdkVersion', 'minSdk = 26')
    text = text.replace('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 26')
    text = re.sub(
        r'namespace\s*=\s*["\'][^"\']+["\']',
        'namespace = "com.rustnrum.healthyme.beta03"',
        text,
    )
    text = re.sub(
        r'applicationId\s*=\s*["\'][^"\']+["\']',
        'applicationId = "com.rustnrum.healthyme.beta03"',
        text,
    )
    text = re.sub(
        r'applicationId\s+["\'][^"\']+["\']',
        'applicationId "com.rustnrum.healthyme.beta03"',
        text,
    )
    path.write_text(text)
PYGRADLE

if ! grep -q '^android.useAndroidX=true' android/gradle.properties 2>/dev/null; then
  echo 'android.useAndroidX=true' >> android/gradle.properties
fi
if ! grep -q '^android.enableJetifier=true' android/gradle.properties 2>/dev/null; then
  echo 'android.enableJetifier=true' >> android/gradle.properties
fi


# Keep the installed app name human-readable.
python3 - <<'PYLABEL'
from pathlib import Path
p = Path('android/app/src/main/AndroidManifest.xml')
s = p.read_text()
import re
s = re.sub(r'android:label="[^"]+"', 'android:label="Healthy Me Beta 0.3.2"', s, count=1)
p.write_text(s)
PYLABEL

echo "Healthy Me Beta 0.3.2 Android identity + Health Connect configuration applied."

bash scripts/ui_contract_check.sh
