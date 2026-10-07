#!/usr/bin/env bash
set -euo pipefail

python3 scripts/native_source_registry_patch.py
python3 scripts/direct_device_native_patch.py
python3 scripts/direct_metric_native_patch.py
python3 scripts/protocol_metric_native_patch.py

fail() { echo "SOURCE REGISTRY CONTRACT FAILURE: $1" >&2; exit 1; }

MAIN_ACTIVITY="$(find android/app/src/main/kotlin -name MainActivity.kt -print -quit)"
[ -n "$MAIN_ACTIVITY" ] || fail "MainActivity.kt missing"
PROTO_READER="$(dirname "$MAIN_ACTIVITY")/SalusProtocolReader.kt"
[ -s "$PROTO_READER" ] || fail "SalusProtocolReader.kt missing"

grep -q '^version: 0.18.0+35$' pubspec.yaml || fail "build 35 version missing"
for required in \
  '"scanBle" ->' \
  '"inspectBle" ->' \
  '"pairBle" ->' \
  '"readStandardMetrics" ->' \
  '"readProtocolMetrics" ->' \
  '"submitCpapPasskey" ->'; do
  grep -Fq "$required" "$MAIN_ACTIVITY" || fail "MethodChannel action missing: $required"
done

grep -q 'coerceIn(5000L, 90000L)' scripts/protocol_metric_native_patch.py || fail "Build 35 extended pairing window missing"
grep -q 'SalusProtocolReader.submitCpapPasskey' scripts/protocol_metric_native_patch.py || fail "Build 35 native passkey submit bridge missing"
for required in \
  'SALUS_PROTOCOL_METRICS_V035' \
  'a6220002-35f1-4b20-afae-cb089d2044aa' \
  'a6220003-35f1-4b20-afae-cb089d2044aa' \
  'RequestSession' \
  'CheckSessionIntegrity' \
  'StartKeyExchange' \
  'ConfirmKeyExchange' \
  'ACTIVE_CPAP_PAIRINGS' \
  'submitCpapPasskey' \
  'cpapAwaitingPasskey' \
  'continueCpapKeyExchange' \
  'AirSense one-time pairing code is being displayed' \
  'AES/CBC/NoPadding' \
  'RESMED_VCID_ENC_TX = 0x0397' \
  'RESMED_VCID_ENC_RX = 0x0396' \
  '.put("_OUD")' \
  '.put("_AHI")' \
  '.put("_LK9")' \
  '.put("_PM9")' \
  'metrics["Usage time"]' \
  'metrics["AHI"]' \
  'metrics["Leak rate"]' \
  'metrics["Therapy pressure"]'; do
  grep -Fq "$required" "$PROTO_READER" || fail "Build 35 ResMed reader missing: $required"
done

# Hard safety boundary: authenticate/session and read-only Get only. Never
# expose therapy or settings mutation RPCs in this app reader.
for forbidden in '"Set"' '"EnterTherapy"' '"EnterStandby"' '"EnterMaskFit"' '"EraseData"' '"ResetDevice"'; do
  if grep -Fq "$forbidden" "$PROTO_READER"; then
    fail "forbidden mutating ResMed RPC present: $forbidden"
  fi
done

grep -q "class CpapScreen" lib/screens/cpap_screen.dart || fail "CPAP dashboard missing"
grep -q "registeredDevices" lib/services/direct_metric_service.dart || fail "provider registry missing"

echo "Salus build 35 ResMed two-stage pairing contract passed."
