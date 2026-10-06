#!/usr/bin/env bash
set -euo pipefail

python3 scripts/direct_device_patch.py
python3 scripts/salus_brand_patch.py
python3 scripts/build27_patch.py
python3 scripts/build28_visual_patch.py
python3 scripts/build29_ble_scan_patch.py

fail() { echo "UI CONTRACT FAILURE: $1" >&2; exit 1; }

grep -q '^version: 0.14.0+29$' pubspec.yaml || fail "build 29 version missing"
grep -q "protocolId == 'ring-uart-v1'" lib/services/source_hub_service.dart || fail "ring/watch identity fix missing"
grep -q 'refreshInspection' lib/services/direct_device_store.dart || fail "saved device identity refresh missing"
grep -q 'Read data to sync' lib/screens/sources_screen.dart || fail "direct reader status copy missing"
grep -q 'DirectMetricService' lib/screens/sources_screen.dart || fail "direct reader UI missing"

grep -q 'SALUS_BUILD28_LOCKED_HOME_BACKGROUND' lib/widgets/salus_widgets.dart || fail "locked home background missing"
grep -q 'class _SalusLandscapePainter' lib/widgets/salus_widgets.dart || fail "landscape visual missing"
grep -q 'class SalusWeekStrip' lib/widgets/salus_widgets.dart || fail "weekday strip missing"
grep -q 'child: SalusWeekStrip()' lib/screens/home_shell.dart || fail "weekday strip not pinned"
grep -q "Today’s Focus" lib/screens/home_screen.dart || fail "Today’s Focus missing"

grep -q 'SALUS_BUILD29_AUTO_IDENTIFY' lib/screens/sources_screen.dart || fail "scan auto-identify missing"
grep -q 'Other Bluetooth devices' lib/screens/sources_screen.dart || fail "other Bluetooth section missing"
grep -q 'healthCandidate: false' lib/screens/sources_screen.dart || fail "non-health device routing missing"
grep -q 'SALUS_BUILD29_HEALTH_CANDIDATE' lib/services/source_hub_service.dart || fail "health candidate classifier missing"
grep -q "return 'Bluetooth device';" lib/services/ble_protocol_profiles.dart || fail "generic Bluetooth label missing"
grep -q "expect(sources.single.label, 'R02_TEST');" test/source_hub_service_test.dart || fail "stale Smart ring regression test not updated"
grep -q "expect(report.deviceKind, 'Heart-rate sensor');" test/ble_protocol_profiles_test.dart || fail "stale standard-HR device-kind test not updated"

echo "Salus build 29 UI contract passed."
