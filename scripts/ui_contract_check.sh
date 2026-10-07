#!/usr/bin/env bash
set -euo pipefail

# Build 29 source is already validated and committed on main.
# Build 30 applies only its own source/UI delta.
python3 scripts/salus_brand_patch.py
python3 scripts/build30_connections_patch.py
python3 scripts/build30_resmed_patch.py

fail() { echo "UI CONTRACT FAILURE: $1" >&2; exit 1; }

grep -q '^version: 0.14.0+30$' pubspec.yaml || fail "build 30 version missing"
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

grep -q "class ConnectionsScreen" lib/screens/connections_screen.dart || fail "normal Connections screen missing"
grep -q "'/sources': (_) => const ConnectionsScreen()" lib/app.dart || fail "normal /sources route missing"
grep -q "'/sources-debug':" lib/app.dart || fail "debug route missing"
grep -q "SALUS_SHOW_DEVICE_DEBUG" lib/app.dart || fail "release debug gate missing"
grep -q "Open device debug" lib/screens/connections_screen.dart || fail "debug page link missing"
grep -q "SALUS_BUILD30_DEBUG_BANNER" lib/screens/sources_screen.dart || fail "debug development banner missing"
grep -q "Device Debug" lib/screens/sources_screen.dart || fail "debug page title missing"
if grep -q "String _lastSeen(DateTime? value)" lib/screens/connections_screen.dart; then
  fail "unused Connections _lastSeen analyzer regression present"
fi
grep -q "resMedAdvertisedService" lib/services/ble_protocol_profiles.dart || fail "ResMed advertised-service fingerprint missing"
grep -q "resMedDeviceService" lib/services/ble_protocol_profiles.dart || fail "ResMed proprietary-service fingerprint missing"
grep -q "'resmed'" lib/services/ble_protocol_profiles.dart || fail "ResMed name fingerprint missing"
grep -q "ResMed name is classified as CPAP health hardware" test/ble_protocol_profiles_test.dart || fail "ResMed name regression test missing"
grep -q "ResMed advertised service identifies CPAP" test/ble_protocol_profiles_test.dart || fail "ResMed advertised-service regression test missing"

echo "Salus build 30 UI contract passed."
