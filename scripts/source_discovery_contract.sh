#!/usr/bin/env bash
set -euo pipefail

# prepare_android.sh writes MainActivity immediately before this contract.
python3 scripts/native_source_registry_patch.py
python3 scripts/direct_device_native_patch.py
python3 scripts/direct_device_patch.py
python3 scripts/salus_brand_patch.py

fail() { echo "SOURCE REGISTRY CONTRACT FAILURE: $1" >&2; exit 1; }

SOURCES="lib/screens/sources_screen.dart"
HUB="lib/services/source_hub_service.dart"
BLE="lib/services/ble_discovery_service.dart"
PROFILES="lib/services/ble_protocol_profiles.dart"
DIRECT_STORE="lib/services/direct_device_store.dart"
MAIN_ACTIVITY="$(find android/app/src/main/kotlin -name MainActivity.kt -print -quit)"

[ -n "$MAIN_ACTIVITY" ] || fail "MainActivity.kt missing"
grep -q '^version: 0.14.0+25$' pubspec.yaml || fail "pubspec must identify Salus build 25"
grep -q 'Devices & Sources' "$SOURCES" || fail "device hub title missing"

# Native scan, inspection and Android/direct pairing must all survive styling.
for required in '"scanBle" ->' '"inspectBle" ->' '"pairBle" ->' 'SALUS_DIRECT_DEVICE_PAIRING_V023' 'createBond()' 'bondStateLabel'; do
  grep -q "$required" "$MAIN_ACTIVITY" || fail "native direct-device behavior missing: $required"
done
for required in "pairBle" "BlePairResult" "bondState" "protocolId" "deviceKind"; do
  grep -q "$required" "$BLE" || fail "BLE direct-device model missing: $required"
done
for required in \
  "ring-uart-v1" \
  "huami-zepp-family" \
  "no1-f1-family" \
  "garmin-family" \
  "fitcloud-family" \
  "moyoung-dafit-family" \
  "cpap-family" \
  "0000181d-0000-1000-8000-00805f9b34fb" \
  "0000181b-0000-1000-8000-00805f9b34fb"; do
  grep -q "$required" "$PROFILES" || fail "protocol/service profile missing: $required"
done
for required in "class DirectDeviceStore" "salus_direct_devices_v1" "SavedDirectDevice"; do
  grep -q "$required" "$DIRECT_STORE" || fail "direct-device persistence missing: $required"
done
for required in "SALUS_BUILD25_DIRECT_FIRST" "Scan for devices" "Connect" "_useWithSalus" "DirectDeviceStore"; do
  grep -q "$required" "$SOURCES" || fail "visible direct-device flow missing: $required"
done

grep -q "selectable: false" "$HUB" || fail "undecoded BLE devices must not masquerade as metric sources"
for required in "Health Connect import" "Your data providers" "Metric sources" "Sleep Stages"; do
  grep -q "$required" "$SOURCES" || fail "provider routing UI missing: $required"
done
if grep -q 'com.xs.imoni\|com.app.cq.ring' "$MAIN_ACTIVITY"; then
  fail "native routing must not hardcode vendor app packages"
fi

grep -q 'android:label="Salus"' android/app/src/main/AndroidManifest.xml || fail "Android label must be Salus"

echo "Salus build 25 direct-device + source registry contract passed."
