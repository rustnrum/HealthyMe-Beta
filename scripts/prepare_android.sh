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
fi

if [ -f android/app/build.gradle.kts ]; then
  sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 26/' android/app/build.gradle.kts || true
elif [ -f android/app/build.gradle ]; then
  sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 26/' android/app/build.gradle || true
fi

if ! grep -q '^android.useAndroidX=true' android/gradle.properties 2>/dev/null; then
  echo 'android.useAndroidX=true' >> android/gradle.properties
fi
if ! grep -q '^android.enableJetifier=true' android/gradle.properties 2>/dev/null; then
  echo 'android.enableJetifier=true' >> android/gradle.properties
fi

echo "Healthy Me Android Health Connect configuration applied."
