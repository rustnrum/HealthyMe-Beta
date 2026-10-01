#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "UI CONTRACT FAILURE: $1" >&2
  exit 1
}

SHELL_FILE="lib/screens/home_shell.dart"
HOME_FILE="lib/screens/home_screen.dart"
ACTIVITY_FILE="lib/screens/activity_screen.dart"
SLEEP_FILE="lib/screens/sleep_screen.dart"
BODY_FILE="lib/screens/body_screen.dart"
MORE_FILE="lib/screens/more_screen.dart"
SOURCES_FILE="lib/screens/sources_screen.dart"
PLAN_FILE="lib/screens/plan_screen.dart"
HEALTH_FILE="lib/services/health_connect_service.dart"
RECOVERY_FILE="lib/services/recovery_service.dart"
BODY_STATUS_FILE="lib/services/body_status_service.dart"
BODY_DETAIL_FILE="lib/screens/body_status_detail_screen.dart"
RECOVERY_DETAIL_FILE="lib/screens/recovery_detail_screen.dart"
DIET_SHELL_FILE="lib/screens/diet/diet_shell.dart"

for required in "'Home'" "'Activity'" "'Sleep'" "'Body'" "'More'"; do
  grep -q "$required" "$SHELL_FILE" || fail "missing bottom-nav destination $required"
done

for forbidden in "Beta 0.2" "label: 'Today'" "label: 'Progress'" "label: 'Connect'" "label: 'Labs'" "label: 'Plan'"; do
  if grep -q "$forbidden" "$SHELL_FILE"; then
    fail "stale v0.2 primary-nav marker found: $forbidden"
  fi
done

for required in "Body Status" "Today's focus" "Data freshness" "Signals to watch" "hero_mountains.jpg"; do
  grep -q "$required" "$HOME_FILE" || fail "home screen missing approved section: $required"
done

for required in "Day" "Week" "Month" "Year" "Workouts" "Weekly activity"; do
  grep -q "$required" "$ACTIVITY_FILE" || fail "activity screen missing approved section: $required"
done

for required in "Total Sleep" "Sleep Stages" "Sleep Insight" "Sleep Consistency"; do
  grep -q "$required" "$SLEEP_FILE" || fail "sleep screen missing approved section: $required"
done

for required in "Weight" "Measurements" "Composition" "Body Measurements" "Body Fat" "Progress Photos"; do
  grep -q "$required" "$BODY_FILE" || fail "body screen missing approved section: $required"
done

for required in "Connected Sources" "Your Plan" "detectedFriendlyProviders"; do
  grep -q "$required" "$MORE_FILE" || fail "More screen missing detection-driven source element: $required"
done

for required in "Healthy Me sections" "Fitness" "Diet" "Diet • Menu • Planning • Grocery List"; do
  grep -q "$required" "$SHELL_FILE" || fail "section launcher missing: $required"
done

grep -q "Source: \$stepSourceLabel" "$ACTIVITY_FILE" || fail "activity must identify the selected step source"
grep -q "Step data" "$ACTIVITY_FILE" || fail "activity must show step data freshness"
grep -q "SleepWindowDial" "$PLAN_FILE" || fail "plan must include the circular sleep-window control"
grep -q "distanceValueToMiles" "$HEALTH_FILE" || fail "distance must be normalized before display"
grep -q "resolvedMotionSource" "$HEALTH_FILE" || fail "motion metrics must avoid multi-provider double counting"
grep -q "respiratoryRate30" "$HEALTH_FILE" || fail "respiratory history must be retained for personal baseline logic"
grep -q "hrv30" "$HEALTH_FILE" || fail "HRV history must be retained for recovery baseline logic"
grep -q "class RecoveryService" "$RECOVERY_FILE" || fail "recovery must be a calculated service"
grep -q "_hrvContributor" "$RECOVERY_FILE" || fail "recovery must use HRV when a baseline is available"
grep -q "_restingHeartRateContributor" "$RECOVERY_FILE" || fail "recovery must use resting HR against personal baseline"
grep -q "_breathingContributor" "$RECOVERY_FILE" || fail "recovery must use respiratory stability when available"
grep -q "Training load" "$RECOVERY_FILE" || fail "recovery must include recent training load"
grep -q "report.score" "$BODY_STATUS_FILE" || fail "home Recovery tile must show a numeric recovery score"
grep -q "Not included until Diet has real food data" "$RECOVERY_FILE" || fail "recovery must not guess nutrition"
grep -q "weightTrend" "$BODY_STATUS_FILE" || fail "body status must use weekly goal-directed weight trend"
grep -q "respiratoryRate" "$BODY_STATUS_FILE" || fail "cardio tile must support respiratory rate"
grep -q "What.s affecting your status" "$BODY_DETAIL_FILE" || fail "Body Status detail must explain the rating"
grep -q "Recovery contributors" "$RECOVERY_DETAIL_FILE" || fail "Recovery detail must show contributors"
for required in "Diet" "Menu" "Planning" "Grocery List"; do
  grep -q "$required" "$DIET_SHELL_FILE" || fail "Diet module shell missing bottom-nav destination: $required"
done
grep -q "DietShell" "$SHELL_FILE" || fail "Fitness section must open the Diet module shell"
test -f lib/assets/images/hero_mountains.jpg || fail "scenic Body Status hero asset missing"

grep -q "isExpanded: true" "$SOURCES_FILE" || fail "source dropdowns must be overflow-safe"
grep -q "SourceNameService" "$SOURCES_FILE" || fail "source screen must normalize raw provider IDs"

python3 - <<'PY'
from pathlib import Path
import re, sys
files = [
    'lib/screens/home_screen.dart',
    'lib/screens/activity_screen.dart',
    'lib/screens/sleep_screen.dart',
    'lib/screens/body_screen.dart',
    'lib/screens/more_screen.dart',
    'lib/screens/sources_screen.dart',
    'lib/screens/home_shell.dart',
    'lib/screens/plan_screen.dart',
    'lib/screens/body_status_detail_screen.dart',
    'lib/screens/recovery_detail_screen.dart',
    'lib/widgets/sleep_window_dial.dart',
    'lib/screens/diet/diet_shell.dart',
    'lib/screens/diet/diet_home_screen.dart',
    'lib/screens/diet/diet_menu_screen.dart',
    'lib/screens/diet/diet_planning_screen.dart',
    'lib/screens/diet/grocery_list_screen.dart',
]
violations=[]
for name in files:
    text=Path(name).read_text()
    for m in re.finditer(r'fontSize:\s*([0-9]+(?:\.[0-9]+)?)', text):
        size=float(m.group(1))
        if size < 12:
            violations.append(f'{name}:{size}')
if violations:
    print('UI CONTRACT FAILURE: primary UI contains text below 12sp:', ', '.join(violations), file=sys.stderr)
    raise SystemExit(1)
PY

echo "Healthy Me approved UI contract markers + readability checks present."
