#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "SOURCE HUB CONTRACT FAILURE: $1" >&2
  exit 1
}

SOURCES="lib/screens/sources_screen.dart"
HUB="lib/services/source_hub_service.dart"
HEALTH="lib/services/health_connect_service.dart"
SYNC="lib/state/health_sync_provider.dart"
NAMES="lib/services/source_name_service.dart"
BLE="lib/services/ble_discovery_service.dart"
PROFILES="lib/services/ble_protocol_profiles.dart"
ANDROID="scripts/prepare_android.sh"
PUBSPEC="pubspec.yaml"

for required in \
  "Beta 0.10.0+14 • Healthy Me Source Hub" \
  "Health Connect import" \
  "Your data providers" \
  "Metric sources" \
  "Nearby devices" \
  "Automatic" \
  "Change" \
  "availableSources" \
  "SourceNameService.friendly"; do
  grep -q "$required" "$SOURCES" || fail "Sources screen missing: $required"
done

for forbidden in \
  "Visible Health Connect apps" \
  "Find compatible sources" \
  "Health Connect aggregate step data"; do
  if grep -q "$forbidden" "$SOURCES"; then
    fail "obsolete/misleading source UI remains: $forbidden"
  fi
done

for required in \
  "class SourceHubService" \
  "class HealthyDataSource" \
  "healthChoicesForMetric" \
  "healthSourcesMissingMetric" \
  "SourceTransport.healthConnect" \
  "SourceTransport.directBluetooth"; do
  grep -q "$required" "$HUB" || fail "Source hub missing: $required"
done

grep -q "isTransportOnly" "$NAMES" || fail "transport/source separation missing"
grep -q "com.android.healthconnect.phone." "$NAMES" || fail "2026 phone Steps SPN handling missing"
grep -q "via Health Connect" "$NAMES" || fail "Health Connect transport attribution missing"

grep -q "HEALTHY_ME_SOURCE_HUB_V010" "$HEALTH" \
  || fail "provider-routing patch missing from Health Connect service"
grep -q "A manual source choice is authoritative" "$HEALTH" \
  || fail "manual source must not silently fall back"
if grep -q "Health Connect aggregate" "$HEALTH"; then
  fail "Health Connect aggregate must not be exposed as a provider"
fi
if grep -q "getTotalStepsInInterval" "$HEALTH"; then
  fail "automatic steps must preserve provider attribution"
fi
grep -q "HEALTHY_ME_SOURCE_HUB_ROUTE_SANITIZER_V010" "$SYNC" \
  || fail "saved transport pseudo-routes must be migrated back to Automatic"

# Direct BLE remains manufacturer-neutral: identify by capabilities/protocol,
# but do not make a device selectable until a reader actually exists.
grep -q "MethodChannel('com.rustnrum.healthyme/source_discovery')" "$BLE" \
  || fail "native BLE MethodChannel missing"
grep -q "ring-uart-v1" "$PROFILES" || fail "ring protocol fingerprint missing"
grep -q "6e40fff0-b5a3-f393-e0a9-e50e24dcca9e" "$PROFILES" \
  || fail "ring UART service fingerprint missing"
grep -q "selectable: false" "$HUB" \
  || fail "BLE discovery must not pretend to be a working metric reader"

grep -q '"scanBle" ->' "$ANDROID" || fail "native scanBle handler missing"
grep -q '"inspectBle" ->' "$ANDROID" || fail "native inspectBle handler missing"
grep -q "BluetoothGattCallback" "$ANDROID" || fail "native GATT inspection missing"

if grep -q "flutter_reactive_ble" "$PUBSPEC"; then
  fail "flutter_reactive_ble must not be reintroduced"
fi
if grep -q "androidx.health.connect:connect-client:1.2.0-alpha" "$ANDROID"; then
  fail "SDK-37 Health Connect matchmaking AAR must not be present"
fi
if grep -q "compileSdk = 37" "$ANDROID"; then
  fail "SDK 37 must not be required"
fi

grep -q '^version: 0.10.0+14$' "$PUBSPEC" \
  || fail "pubspec must identify the Source Hub build"

echo "Healthy Me v0.10 source-hub contract passed."
