#!/usr/bin/env bash
set -euo pipefail

# Build 33 is the verified baseline already committed on main.
python3 scripts/salus_brand_patch.py
python3 scripts/build34_resmed_session_patch.py

fail() { echo "UI CONTRACT FAILURE: $1" >&2; exit 1; }

grep -q '^version: 0.17.0+34$' pubspec.yaml || fail "build 34 version missing"
grep -q 'SALUS_BUILD28_LOCKED_HOME_BACKGROUND' lib/widgets/salus_widgets.dart || fail "locked home background missing"
grep -q 'class ConnectionsScreen' lib/screens/connections_screen.dart || fail "Connections screen missing"
grep -q 'class CpapScreen' lib/screens/cpap_screen.dart || fail "CPAP dashboard missing"
grep -q 'class CpapTherapyService' lib/services/cpap_therapy_service.dart || fail "CPAP trend service missing"
grep -q "strongCpapIdentity" lib/services/ble_protocol_profiles.dart || fail "CPAP identity priority missing"
grep -q 'final List<String> observations' lib/services/direct_metric_service.dart || fail "Build 33 diagnostics missing"
grep -q "String? cpapPasskey" lib/services/direct_metric_service.dart || fail "Build 34 passkey bridge missing"
grep -q "'cpapPasskey': cpapPasskey" lib/services/direct_metric_service.dart || fail "Build 34 native passkey map missing"
grep -q "labelText: 'ResMed 4-digit code'" lib/screens/cpap_screen.dart || fail "Build 34 secure pairing field missing"
grep -q 'Secure sync CPAP data' lib/screens/cpap_screen.dart || fail "Build 34 secure sync action missing"
grep -q 'secure read-only therapy sync' lib/screens/cpap_screen.dart || fail "Build 34 secure provider state missing"
if grep -q 'const FilledButton\.tonalIcon' lib/screens/sources_screen.dart; then
  fail "non-const FilledButton.tonalIcon analyzer regression present"
fi

echo "Salus build 34 UI contract passed."
