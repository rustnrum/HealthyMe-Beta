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

grep -q '^version: 0.19.0+36$' pubspec.yaml || fail "build 36 version missing"
for required in   '"scanBle" ->'   '"inspectBle" ->'   '"pairBle" ->'   '"readStandardMetrics" ->'   '"readProtocolMetrics" ->'   '"submitCpapPasskey" ->'   '"openNotificationAccess" ->'; do
  grep -Fq "$required" "$MAIN_ACTIVITY" || fail "MethodChannel action missing: $required"
done

for required in   'SALUS_PROTOCOL_METRICS_V036'   'RequestSession'   'CheckSessionIntegrity'   'StartKeyExchange'   'ConfirmKeyExchange'   'StartSpool'   'PullSpoolFragments'   'SpoolFragment'   'parseCpapSummaryPayload'   'historySamples'   'addHistoryMetric("Sleep"'   'dailyTotal / dailyCount.toDouble()'   'metrics["Usage time"]'   'metrics["AHI"]'   'metrics["Leak rate"]'   'metrics["Therapy pressure"]'; do
  grep -Fq "$required" "$PROTO_READER" || fail "Build 36 reader missing: $required"
done

for forbidden in '"Set"' '"EnterTherapy"' '"EnterStandby"' '"EnterMaskFit"' '"EraseData"' '"ResetDevice"'; do
  if grep -Fq "$forbidden" "$PROTO_READER"; then
    fail "forbidden mutating ResMed RPC present: $forbidden"
  fi
done

grep -q 'SalusNotificationListenerService' android/app/src/main/AndroidManifest.xml || fail "notification listener declaration missing"

echo "Salus build 36 Today + watch + history contract passed."
