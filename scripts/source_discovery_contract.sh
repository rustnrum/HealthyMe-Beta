#!/usr/bin/env bash
set -euo pipefail

# prepare_android.sh writes MainActivity immediately before calling this contract.
python3 scripts/native_source_registry_patch.py
python3 scripts/salus_brand_patch.py

fail() { echo "SOURCE REGISTRY CONTRACT FAILURE: $1" >&2; exit 1; }

SOURCES="lib/screens/sources_screen.dart"
HUB="lib/services/source_hub_service.dart"
HEALTH="lib/services/health_connect_service.dart"
REGISTRY="lib/services/health_origin_registry_service.dart"
MODELS="lib/models/models.dart"
SYNC="lib/state/health_sync_provider.dart"
NAMES="lib/services/source_name_service.dart"
BLE="lib/services/ble_discovery_service.dart"
PROFILES="lib/services/ble_protocol_profiles.dart"
PUBSPEC="pubspec.yaml"
MAIN_ACTIVITY="$(find android/app/src/main/kotlin -name MainActivity.kt -print -quit)"

[ -n "$MAIN_ACTIVITY" ] || fail "MainActivity.kt missing"

for required in "Beta 0.14.0+19 • Salus Source Registry" "Health Connect import" "Your data providers" "Metric sources" "records • use only for" "Sleep Stages"; do
  grep -q "$required" "$SOURCES" || fail "Sources screen missing: $required"
done
for forbidden in "Visible Health Connect apps" "Find compatible sources" "Health Connect aggregate step data"; do
  if grep -q "$forbidden" "$SOURCES"; then fail "obsolete/misleading source UI remains: $forbidden"; fi
done
for required in "class HealthOriginRegistryService" "class HealthOriginRegistry" "scanHealthOrigins" "nativeSupported"; do grep -q "$required" "$REGISTRY" || fail "registry service missing: $required"; done
for required in "HEALTHY_ME_SOURCE_REGISTRY_V011" "providerBuckets" "nativeRegistry" "sourceRecordCounts" "recordCountsFor" "nativeSourceRegistry: nativeRegistry.nativeSupported" "resolvedOrigin('Sleep Stages', sleepStageTypes)" "'Sleep Stages': recordCountsFor('Sleep Stages', sleepStageTypes)"; do grep -q "$required" "$HEALTH" || fail "Health Connect registry routing missing: $required"; done
if grep -q '^    points = _health.removeDuplicates(points);$' "$HEALTH"; then fail "global cross-provider dedupe still erases DataOrigin attribution"; fi
grep -q "A manual source choice is authoritative" "$HEALTH" || fail "manual source must not silently fall back"
if grep -q "getTotalStepsInInterval" "$HEALTH"; then fail "steps must stay provider attributed"; fi
for required in "sourceRecordCounts" "nativeSourceRegistry"; do grep -q "$required" "$MODELS" || fail "HealthSnapshot missing: $required"; done
for required in "recordCounts" "recordsFor" "final rawIds" "final preferred" "healthChoicesForMetric"; do grep -q "$required" "$HUB" || fail "Source hub missing: $required"; done
grep -q "availableSources: snapshot.availableSources" "$SYNC" || fail "current provider choices are still merging stale metric availability"
if grep -q "mergeSourceLists" "$SYNC"; then fail "stale availableSources merge remains"; fi
grep -q "isTransportOnly" "$NAMES" || fail "Health Connect transport separation missing"
grep -q "com.android.healthconnect.phone." "$NAMES" || fail "phone-origin handling missing"
for required in '"scanHealthOrigins" ->' "HEALTHY_ME_NATIVE_SOURCE_REGISTRY_V011" "ReadRecordsRequestUsingFilters" "getDataOrigin" "getPackageName" "getRecords" "getNextPageToken" "appLabelForPackage"; do grep -q "$required" "$MAIN_ACTIVITY" || fail "native registry missing: $required"; done
grep -q 'HEALTH_CONNECT_SERVICE_NAME = "healthconnect"' "$MAIN_ACTIVITY" || fail "Android Health Connect service name must be healthconnect"
if grep -q 'HEALTH_CONNECT_SERVICE_NAME = "health_connect"' "$MAIN_ACTIVITY"; then fail "invalid Android Health Connect service name remains"; fi
for forbidden in "com.xs.imoni" "com.app.cq.ring" "QRing" "iMoni"; do if grep -q "$forbidden" "$MAIN_ACTIVITY"; then fail "native source routing must not be brand/package hardcoded: $forbidden"; fi; done
grep -q "MethodChannel('com.rustnrum.healthyme/source_discovery')" "$BLE" || fail "native discovery MethodChannel missing"
grep -q "ring-uart-v1" "$PROFILES" || fail "ring protocol fingerprint missing"
grep -q "selectable: false" "$HUB" || fail "BLE discovery must not pretend to be a working metric reader"
if grep -q "flutter_reactive_ble" "$PUBSPEC"; then fail "flutter_reactive_ble must not be reintroduced"; fi
grep -q '^version: 0.14.0+19$' "$PUBSPEC" || fail "pubspec must identify Salus build 19"
grep -q 'android:label="Salus"' android/app/src/main/AndroidManifest.xml || fail "Android app label must be Salus"
grep -q "title: 'Salus'" lib/app.dart || fail "Flutter app title must be Salus"
if grep -q "import 'workout_screen.dart';" lib/screens/activity_screen.dart; then fail "Activity still imports Workout as a detail page"; fi
grep -q "HealthyMeModule.workout" lib/widgets/module_menu_button.dart || fail "Workout must be a top-level Salus module"
grep -q "'/workout': (_) => const WorkoutScreen()" lib/app.dart || fail "Workout module route missing"
grep -q "current: HealthyMeModule.workout" lib/screens/workout_screen.dart || fail "Workout screen must identify itself as the Workout module"
grep -q "reservedSize: 58" lib/widgets/step_bar_chart.dart || fail "step Y-axis must reserve visible label width"
grep -q "fontSize: 12.5" lib/widgets/step_bar_chart.dart || fail "step Y-axis labels must meet readability floor"
grep -q "color: AppTheme.textSecondary" lib/widgets/step_bar_chart.dart || fail "step Y-axis labels must use visible contrast"
grep -q "fit: BoxFit.scaleDown" lib/widgets/design_widgets.dart || fail "shared narrow text must scale instead of overflow"
grep -Fq 'Source: $stepSourceLabel' lib/screens/activity_screen.dart || fail "Activity step source label missing"
grep -q "softWrap: true" lib/screens/activity_screen.dart || fail "Activity source labels must wrap instead of truncate"
if grep -Fq "import 'workout_screen.dart';" lib/screens/activity_screen.dart; then fail "Activity retains obsolete direct Workout import"; fi
grep -Fq 'Stages from: $stageSourceLabel' lib/screens/sleep_screen.dart || fail "Sleep Stages source label missing"
if grep -Fq "h.resolvedSources['Sleep Stages'] ?? h.resolvedSources['Sleep']" lib/screens/sleep_screen.dart; then fail "Sleep Stages must not reuse generic Sleep provenance"; fi
for folder in mdpi hdpi xhdpi xxhdpi xxxhdpi; do [ -f "android/app/src/main/res/mipmap-${folder}/ic_launcher.png" ] || fail "launcher icon missing for ${folder}"; done
grep -q "native registry parser preserves package origins and counts" test/health_origin_registry_service_test.dart || fail "source registry tests missing"
echo "Salus build 19 source registry + module + Activity/Sleep contracts passed."
