#!/usr/bin/env bash
set -euo pipefail

# Build 35 is already the validated source committed on main.
# Do not replay older non-idempotent migrations.
python3 scripts/salus_brand_patch.py
python3 scripts/build36_daily_history_watch_patch.py

fail() { echo "UI CONTRACT FAILURE: $1" >&2; exit 1; }

grep -q '^version: 0.19.0+36$' pubspec.yaml || fail "build 36 version missing"
grep -q 'SALUS_BUILD28_LOCKED_HOME_BACKGROUND' lib/widgets/salus_widgets.dart || fail "locked home background missing"
grep -q 'class TodayPlanNotifier' lib/state/today_plan_state.dart || fail "daily meal plan state missing"
grep -q 'What’s on the plan today' lib/screens/home_screen.dart || fail "Today command center missing"
grep -q 'Device batteries' lib/screens/home_screen.dart || fail "device batteries missing"
grep -q 'class WatchDeviceScreen' lib/screens/watch_device_screen.dart || fail "watch page missing"
grep -q 'Android notification access' lib/screens/watch_device_screen.dart || fail "notification access action missing"
grep -q 'Watch settings' lib/screens/connections_screen.dart || fail "watch settings button missing"
grep -q 'final List<DirectMetricSample> history' lib/services/direct_metric_service.dart || fail "history bridge missing"
grep -q 'GATT characteristics read' lib/screens/cpap_screen.dart || fail "CPAP diagnostic wording missing"
grep -q 'class CpapScreen' lib/screens/cpap_screen.dart || fail "CPAP dashboard missing"
if grep -q 'const FilledButton\.tonalIcon' lib/screens/sources_screen.dart; then
  fail "non-const FilledButton.tonalIcon analyzer regression present"
fi

echo "Salus build 36 UI contract passed."
