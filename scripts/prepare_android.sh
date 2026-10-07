#!/usr/bin/env bash
set -euo pipefail

mkdir -p native/android

if [ ! -f native/android/SalusProtocolReader.kt ]; then
  if [ ! -f scripts/SalusProtocolReader.kt.template ]; then
    echo "Missing current SalusProtocolReader source"
    exit 1
  fi
  cp scripts/SalusProtocolReader.kt.template native/android/SalusProtocolReader.kt
fi

PKG_DIR="android/app/src/main/kotlin/com/rustnrum/healthyme/beta03"
rm -rf android/app/src/main/kotlin
mkdir -p "$PKG_DIR"

cp native/android/MainActivity.kt "$PKG_DIR/MainActivity.kt"
cp native/android/SalusProtocolReader.kt "$PKG_DIR/SalusProtocolReader.kt"
cp native/android/SalusNotificationListenerService.kt "$PKG_DIR/SalusNotificationListenerService.kt"
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

# One-time cleanup only: remove the old Python mutation layer after the current
# protocol reader has been copied to permanent native source.
find scripts -maxdepth 1 -type f -name '*.py' -delete
rm -rf scripts/__pycache__
rm -f scripts/SalusProtocolReader.kt.template
rm -f scripts/ui_contract_check.sh scripts/source_discovery_contract.sh
