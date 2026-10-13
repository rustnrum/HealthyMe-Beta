#!/usr/bin/env bash
set -euo pipefail
if ! grep -Eq '^version: 0\.21\.(36\+74|37\+75|38\+76|39\+77|40\+78|41\+79|42\+80)$' pubspec.yaml; then
python3 scripts/patch_build47.py
if ! grep -Eq '^version: 0\.21\.(19\+57|20\+58|21\+59|22\+60|23\+61|24\+62|25\+63|26\+64|27\+65|28\+66|29\+67|30\+68|31\+69|32\+70|33\+71|34\+72|35\+73)$' pubspec.yaml; then
  python3 scripts/patch_build56.py
fi
if ! grep -Eq '^version: 0\.21\.(20\+58|21\+59|22\+60|23\+61|24\+62|25\+63|26\+64|27\+65|28\+66|29\+67|30\+68|31\+69|32\+70|33\+71|34\+72|35\+73)$' pubspec.yaml; then
  python3 scripts/patch_build57.py
fi
if ! grep -Eq '^version: 0\.21\.(20\+58|21\+59|22\+60|23\+61|24\+62|25\+63|26\+64|27\+65|28\+66|29\+67|30\+68|31\+69|32\+70|33\+71|34\+72|35\+73)$' pubspec.yaml; then
  python3 scripts/patch_build58.py
fi
if ! grep -Eq '^version: 0\.21\.(22\+60|23\+61|24\+62|25\+63|26\+64|27\+65|28\+66|29\+67|30\+68|31\+69|32\+70|33\+71|34\+72|35\+73)$' pubspec.yaml; then
  python3 scripts/patch_build59.py
  python3 scripts/patch_build59_steps.py
fi
if ! grep -Eq '^version: 0\.21\.(23\+61|24\+62|25\+63|26\+64|27\+65|28\+66|29\+67|30\+68|31\+69|32\+70|33\+71|34\+72|35\+73)$' pubspec.yaml; then
  python3 scripts/patch_build60.py
fi
if ! grep -Eq '^version: 0\.21\.(24\+62|25\+63|26\+64|27\+65|28\+66|29\+67|30\+68|31\+69|32\+70|33\+71|34\+72|35\+73)$' pubspec.yaml; then
  python3 scripts/patch_build61.py
fi
if ! grep -Eq '^version: 0\.21\.(25\+63|26\+64|27\+65|28\+66|29\+67|30\+68|31\+69|32\+70|33\+71|34\+72|35\+73)$' pubspec.yaml; then
  python3 scripts/patch_build62.py
fi
python3 scripts/patch_build62_test_contracts.py
if ! grep -Eq '^version: 0\.21\.(26\+64|27\+65|28\+66|29\+67|30\+68|31\+69|32\+70|33\+71|34\+72|35\+73)$' pubspec.yaml; then
  python3 scripts/patch_build63.py
fi
if ! grep -Eq '^version: 0\.21\.(27\+65|28\+66|29\+67|30\+68|31\+69|32\+70|33\+71|34\+72|35\+73)$' pubspec.yaml; then
  python3 scripts/patch_build64.py
fi
if ! grep -Eq '^version: 0\.21\.(28\+66|29\+67|30\+68|31\+69|32\+70|33\+71|34\+72|35\+73)$' pubspec.yaml; then
  python3 scripts/patch_build65.py
fi
if ! grep -Eq '^version: 0\.21\.(29\+67|30\+68|31\+69|32\+70|33\+71|34\+72|35\+73)$' pubspec.yaml; then
  python3 scripts/patch_build66.py
fi
if grep -Eq '^version: 0\.21\.(28\+66|29\+67)$' pubspec.yaml; then
  python3 scripts/patch_build67.py
fi
if grep -Eq '^version: 0\.21\.(29\+67|30\+68)$' pubspec.yaml; then
  python3 scripts/patch_build68.py
fi
if grep -Eq '^version: 0\.21\.(30\+68|31\+69)$' pubspec.yaml; then
  python3 scripts/patch_build69.py
fi
if grep -Eq '^version: 0\.21\.(31\+69|32\+70)$' pubspec.yaml; then
  python3 scripts/patch_build70.py
fi
if grep -Eq '^version: 0\.21\.(32\+70|33\+71)$' pubspec.yaml; then
  python3 scripts/patch_build71.py
fi
if grep -Eq '^version: 0\.21\.(33\+71|34\+72)$' pubspec.yaml; then
  python3 scripts/patch_build72.py
fi

python3 scripts/patch_build73.py

fi
if ! grep -Eq '^version: 0\.21\.(37\+75|38\+76|39\+77|40\+78|41\+79|42\+80)$' pubspec.yaml; then
  python3 scripts/patch_build74.py
fi
if ! grep -Eq '^version: 0\.21\.(37\+75|38\+76|39\+77|40\+78|41\+79|42\+80)$' pubspec.yaml; then
  python3 scripts/patch_build75.py
fi
if ! grep -Eq '^version: 0\.21\.(39\+77|40\+78|41\+79|42\+80)$' pubspec.yaml; then
  python3 scripts/patch_build76.py
fi
if grep -Eq '^version: 0\.21\.38\+76$' pubspec.yaml; then
  python3 scripts/patch_build77.py
fi
if grep -Eq '^version: 0\.21\.(39\+77|40\+78)$' pubspec.yaml; then
  python3 scripts/patch_build78.py
fi
if grep -Eq '^version: 0\.21\.41\+79$' pubspec.yaml; then
  python3 scripts/patch_build79.py
fi
python3 scripts/patch_build80.py

test -f lib/widgets/garmin_body_battery_panel.dart
test -f native/android/MainActivity.kt
test -f native/android/SalusBleDeviceInfoReader.kt
test -f native/android/SalusRingHrvLogDecoder.kt
test -f native/android/SalusRingTemperatureDecoder.kt
test -f native/android/SalusBackupBridge.kt
test -f native/android/SalusProtocolReader.kt
test -f native/android/SalusNotificationListenerService.kt
test -f native/android/SalusWatchNotificationStore.kt
test -f native/android/SalusWatchNotificationSender.kt
test -f native/android/AndroidManifest.xml

PKG_DIR="android/app/src/main/kotlin/com/rustnrum/healthyme/beta03"
rm -rf android/app/src/main/kotlin
mkdir -p "$PKG_DIR"
cp native/android/*.kt "$PKG_DIR"/
cp native/android/AndroidManifest.xml android/app/src/main/AndroidManifest.xml

if [ -f android/app/build.gradle.kts ]; then
  sed -i -E 's/namespace = "[^"]+"/namespace = "com.rustnrum.healthyme.beta03"/' android/app/build.gradle.kts
  sed -i -E 's/applicationId = "[^"]+"/applicationId = "com.rustnrum.healthyme.beta03"/' android/app/build.gradle.kts
  sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 26/' android/app/build.gradle.kts
else
  sed -i -E 's/applicationId "[^"]+"/applicationId "com.rustnrum.healthyme.beta03"/' android/app/build.gradle
  sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 26/' android/app/build.gradle
fi

grep -q '^android.useAndroidX=true' android/gradle.properties || echo 'android.useAndroidX=true' >> android/gradle.properties
grep -q '^android.enableJetifier=true' android/gradle.properties || echo 'android.enableJetifier=true' >> android/gradle.properties

for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  src="branding/android/mipmap-${density}/ic_launcher.png"
  dst="android/app/src/main/res/mipmap-${density}/ic_launcher.png"
  if [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  fi
done
