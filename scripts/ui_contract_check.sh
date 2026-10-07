#!/usr/bin/env bash
set -euo pipefail

# Build 30 source is already validated and committed on main.
# Build 31 applies only its CPAP metric/read-routing correction.
python3 scripts/salus_brand_patch.py
python3 scripts/build31_cpap_metrics_patch.py

fail() { echo "UI CONTRACT FAILURE: $1" >&2; exit 1; }

grep -q '^version: 0.14.0+31$' pubspec.yaml || fail "build 31 version missing"
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



grep -q "'Usage time'" lib/services/ble_protocol_profiles.dart || fail "CPAP usage metric missing"
grep -q "'AHI'" lib/services/ble_protocol_profiles.dart || fail "CPAP AHI metric missing"
grep -q "'Leak rate'" lib/services/ble_protocol_profiles.dart || fail "CPAP leak metric missing"
grep -q "'Therapy pressure'" lib/services/ble_protocol_profiles.dart || fail "CPAP pressure metric missing"
grep -q "isTherapyOnlyProtocol" lib/services/direct_metric_service.dart || fail "CPAP reader guard missing"
grep -q "CPAP therapy sync is not enabled yet" lib/services/direct_metric_service.dart || fail "CPAP reader message missing"
grep -q "Connected • CPAP therapy sync pending" lib/screens/connections_screen.dart || fail "normal CPAP pending state missing"
grep -q "saved && isCpap" lib/screens/sources_screen.dart || fail "debug CPAP guard missing"
if grep -q 'const FilledButton\.tonalIcon' lib/screens/sources_screen.dart; then
  fail "non-const FilledButton.tonalIcon incorrectly invoked with const"
fi
grep -q "CPAP protocol never falls through to wearable metric reader" test/direct_metric_service_test.dart || fail "CPAP routing regression test missing"

echo "Salus build 31 UI contract passed."
