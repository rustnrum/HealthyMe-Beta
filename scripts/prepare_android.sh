#!/usr/bin/env bash
set -euo pipefail
# Preserve the project's existing platform setup and patch the native channel
# before generated Android sources are compiled and before source is committed.
python3 scripts/patch_build47.py
# Build 56/57 migrations are only needed on an older checkout. Never
# revert/redo their version upgrades on a committed Build 58/59 source.
if ! grep -Eq '^version: 0\.21\.(19\+57|20\+58|21\+59|22\+60|23\+61|24\+62)$' pubspec.yaml; then
  python3 scripts/patch_build56.py
fi
if ! grep -Eq '^version: 0\.21\.(20\+58|21\+59|22\+60|23\+61|24\+62)$' pubspec.yaml; then
  python3 scripts/patch_build57.py
fi
# Build 58 migration's version step cannot be re-applied after Build 59.
if ! grep -Eq '^version: 0\.21\.(20\+58|21\+59|22\+60|23\+61|24\+62)$' pubspec.yaml; then
  python3 scripts/patch_build58.py
fi
if ! grep -Eq '^version: 0\.21\.(22\+60|23\+61|24\+62)$' pubspec.yaml; then
  python3 scripts/patch_build59.py
  python3 scripts/patch_build59_steps.py
fi
if ! grep -Eq '^version: 0\.21\.(23\+61|24\+62)$' pubspec.yaml; then
  python3 scripts/patch_build60.py
fi
if ! grep -q '^version: 0.21.24+62$' pubspec.yaml; then
  python3 scripts/patch_build61.py
fi
python3 scripts/patch_build62.py
python3 scripts/patch_build62_test_contracts.py

test -f native/android/MainActivity.kt
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
