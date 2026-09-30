#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not on PATH."
  exit 1
fi

rm -rf /tmp/healthy_me_bootstrap
flutter create \
  --platforms=android \
  --org com.rustnrum \
  --project-name healthy_me \
  --no-pub \
  /tmp/healthy_me_bootstrap

rm -rf android
cp -R /tmp/healthy_me_bootstrap/android ./android

if [ -f android/app/build.gradle.kts ]; then
  sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 26/' android/app/build.gradle.kts || true
fi

echo
echo "Android shell created without touching lib/ or pubspec.yaml."
echo "Next: flutter pub get && flutter analyze && flutter test"
