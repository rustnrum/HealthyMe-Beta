#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "SOURCE DISCOVERY CONTRACT FAILURE: $1" >&2
  exit 1
}

SOURCES="lib/screens/sources_screen.dart"
BLE="lib/services/ble_discovery_service.dart"
PROFILES="lib/services/ble_protocol_profiles.dart"
NATIVE="lib/services/native_source_discovery_service.dart"
ANDROID="scripts/prepare_android.sh"
PUBSPEC="pubspec.yaml"

for required in \
  "Beta 0.9.0+13 • Source Discovery" \
  "Find compatible sources" \
  "Nearby Bluetooth health devices" \
  "Scan nearby BLE" \
  "Protocol profile"; do
  grep -q "$required" "$SOURCES" || fail "Sources screen missing: $required"
done

# Dart side must use our native source-discovery channel, not a BLE plugin.
grep -q "MethodChannel('com.rustnrum.healthyme/source_discovery')" "$BLE" \
  || fail "native BLE MethodChannel missing"
grep -q "'scanBle'" "$BLE" || fail "native BLE scan call missing"
grep -q "'inspectBle'" "$BLE" || fail "native BLE inspection call missing"

if grep -q "flutter_reactive_ble" "$PUBSPEC"; then
  fail "flutter_reactive_ble must not be present"
fi
if grep -q "reactive_ble_mobile" "$PUBSPEC"; then
  fail "reactive_ble_mobile must not be present"
fi
if grep -q "reactive_ble_platform_interface" "$PUBSPEC"; then
  fail "reactive_ble_platform_interface must not be present"
fi
if grep -q "flutter_reactive_ble" "$BLE"; then
  fail "Dart BLE adapter still imports flutter_reactive_ble"
fi

# Protocol/capability layer stays manufacturer-neutral.
grep -q "ring-uart-v1" "$PROFILES" || fail "protocol profile registry missing"
grep -q "6e40fff0-b5a3-f393-e0a9-e50e24dcca9e" "$PROFILES" \
  || fail "ring UART fingerprint missing"

# Native Android bridge: BLE scan + GATT service inspection.
grep -q '"scanBle" ->' "$ANDROID" || fail "native scanBle handler missing"
grep -q '"inspectBle" ->' "$ANDROID" || fail "native inspectBle handler missing"
grep -q "BluetoothGattCallback" "$ANDROID" || fail "native GATT callback missing"
grep -q "bluetoothLeScanner" "$ANDROID" || fail "native BLE scanner missing"
grep -q "discoverServices()" "$ANDROID" || fail "native GATT service discovery missing"
grep -q "BLUETOOTH_SCAN" "$ANDROID" || fail "Bluetooth scan permission missing"
grep -q "BLUETOOTH_CONNECT" "$ANDROID" || fail "Bluetooth connect permission missing"

# Health Connect matchmaking remains runtime/reflection based; no SDK-37 AAR.
grep -q "com.rustnrum.healthyme/source_discovery" "$NATIVE" \
  || fail "native source-discovery channel missing"
grep -q 'Class.forName("android.health.connect.HealthConnectManager")' "$ANDROID" \
  || fail "runtime HealthConnectManager discovery missing"
grep -q 'Class.forName("android.health.connect.MatchmakingRequest\\\$Builder")' "$ANDROID" \
  || fail "runtime MatchmakingRequest builder missing"
grep -q 'it.name == "isMatchmakingPossible"' "$ANDROID" \
  || fail "runtime matchmaking availability check missing"
grep -q 'it.name == "createMatchmakingIntent"' "$ANDROID" \
  || fail "runtime matchmaking launcher missing"
grep -q "MATCHMAKING_EXTENSION_VERSION = 21" "$ANDROID" \
  || fail "U-extension matchmaking gate missing"

if grep -q "androidx.health.connect:connect-client:1.2.0-alpha" "$ANDROID"; then
  fail "SDK-37 Health Connect matchmaking AAR must not be present"
fi
if grep -q "compileSdk = 37" "$ANDROID"; then
  fail "SDK 37 must not be required"
fi

echo "Healthy Me v0.9 native BLE + runtime matchmaking contract passed."
