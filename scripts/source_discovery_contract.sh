#!/usr/bin/env bash
set -euo pipefail

# prepare_android.sh runs ui_contract_check.sh immediately before this script.
# Do not re-run the UI/source patches here: Build 29 intentionally changes
# source-hub code that Build 27 originally patched, so replaying Build 27 after
# Build 29 is both unnecessary and non-idempotent.
python3 scripts/native_source_registry_patch.py
python3 scripts/direct_device_native_patch.py
python3 scripts/direct_metric_native_patch.py
python3 scripts/protocol_metric_native_patch.py

fail() { echo "SOURCE REGISTRY CONTRACT FAILURE: $1" >&2; exit 1; }

MAIN_ACTIVITY="$(find android/app/src/main/kotlin -name MainActivity.kt -print -quit)"
[ -n "$MAIN_ACTIVITY" ] || fail "MainActivity.kt missing"
PROTO_READER="$(dirname "$MAIN_ACTIVITY")/SalusProtocolReader.kt"
[ -s "$PROTO_READER" ] || fail "SalusProtocolReader.kt missing"

grep -q '^version: 0.14.0+29$' pubspec.yaml || fail "build 29 version missing"

# UI/source patches must already have been applied by ui_contract_check.sh.
grep -q 'SALUS_BUILD29_AUTO_IDENTIFY' lib/screens/sources_screen.dart || fail "Build 29 UI patch was not applied before source contract"
grep -q 'SALUS_BUILD29_HEALTH_CANDIDATE' lib/services/source_hub_service.dart || fail "Build 29 source classification patch missing"
grep -q 'SALUS_BUILD28_LOCKED_HOME_BACKGROUND' lib/widgets/salus_widgets.dart || fail "Build 28 locked home background missing"

for required in \
  '"scanBle" ->' \
  '"inspectBle" ->' \
  '"pairBle" ->' \
  '"readStandardMetrics" ->' \
  '"readProtocolMetrics" ->'; do
  grep -Fq "$required" "$MAIN_ACTIVITY" || fail "MethodChannel action missing: $required"
done

for required in \
  'SALUS_PROTOCOL_METRICS_V027' \
  '6e40fff0-b5a3-f393-e0a9-e50e24dcca9e' \
  'de5bf728-d711-4e47-af26-65e3012a5dc7' \
  '6a4e2800-667b-11e3-949a-0800200c9a66' \
  'GARMIN_REALTIME_HR = 6' \
  'GARMIN_REALTIME_STEPS = 7' \
  'GARMIN_REALTIME_HRV = 12' \
  'GARMIN_REALTIME_SPO2 = 19' \
  'GARMIN_REALTIME_RESPIRATION = 21' \
  'metrics["Sleep"]' \
  'metrics["SpO2"]' \
  'metrics["Steps"]'; do
  grep -Fq "$required" "$PROTO_READER" || fail "protocol reader missing: $required"
done

grep -q "'readProtocolMetrics'" lib/services/direct_metric_service.dart || fail "Dart protocol call missing"
grep -q "'Sleep Stages'" lib/services/direct_metric_service.dart || fail "direct sleep-stage routing missing"
grep -q "'Resting heart rate'" lib/services/direct_metric_service.dart || fail "direct resting-HR routing missing"
grep -q "'Respiratory rate'" lib/services/direct_metric_service.dart || fail "direct respiration routing missing"
grep -q "'Ring HRV proxy'" lib/services/direct_metric_service.dart || fail "ring HRV proxy isolation missing"

grep -q 'SALUS_BUILD28_LOCKED_HOME_BACKGROUND' lib/widgets/salus_widgets.dart || fail "locked Salus home background missing"

grep -q 'SALUS_BUILD29_AUTO_IDENTIFY' lib/screens/sources_screen.dart || fail "automatic device identification missing"
grep -q 'SALUS_BUILD29_HEALTH_CANDIDATE' lib/services/source_hub_service.dart || fail "Bluetooth health classification missing"

echo "Salus build 29 direct protocol + BLE scan + locked home visual contract passed."
