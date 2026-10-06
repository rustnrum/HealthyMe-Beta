#!/usr/bin/env bash
set -euo pipefail

python3 scripts/native_source_registry_patch.py
python3 scripts/direct_device_native_patch.py
python3 scripts/direct_metric_native_patch.py
python3 scripts/direct_device_patch.py
python3 scripts/salus_brand_patch.py
python3 scripts/build26_fix_patch.py

fail() { echo "SOURCE REGISTRY CONTRACT FAILURE: $1" >&2; exit 1; }

MAIN_ACTIVITY="$(find android/app/src/main/kotlin -name MainActivity.kt -print -quit)"
[ -n "$MAIN_ACTIVITY" ] || fail "MainActivity.kt missing"

grep -q '^version: 0.14.0+26$' pubspec.yaml || fail "build 26 version missing"
for required in '"scanBle" ->' '"inspectBle" ->' '"pairBle" ->' '"readStandardMetrics" ->' \
  'SALUS_DIRECT_DEVICE_PAIRING_V023' 'SALUS_DIRECT_STANDARD_METRICS_V026' \
  'createBond()' '00002a37-0000-1000-8000-00805f9b34fb'; do
  grep -q "$required" "$MAIN_ACTIVITY" || fail "native direct-device feature missing: $required"
done

for required in "ring-uart-v1" "garmin-family" "fitcloud-family" "moyoung-dafit-family" "cpap-family"; do
  grep -q "$required" lib/services/ble_protocol_profiles.dart || fail "protocol profile missing: $required"
done

grep -q 'DirectMetricService' lib/state/health_sync_provider.dart || fail "direct metrics not merged into health snapshot"
grep -q "id.startsWith('ble:')" lib/services/source_hub_service.dart || fail "direct BLE transport detection missing"
grep -q "Read data" lib/screens/sources_screen.dart || fail "direct read action missing"

echo "Salus build 26 direct metric + source registry contract passed."
