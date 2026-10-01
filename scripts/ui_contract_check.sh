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

for required in "'Home'" "'Activity'" "'Sleep'" "'Body'" "'More'"; do
  grep -q "$required" "$SHELL_FILE" || fail "missing bottom-nav destination $required"
done

for forbidden in "Beta 0.2" "label: 'Today'" "label: 'Progress'" "label: 'Connect'" "label: 'Labs'" "label: 'Plan'"; do
  if grep -q "$forbidden" "$SHELL_FILE"; then
    fail "stale v0.2 primary-nav marker found: $forbidden"
  fi
done

for required in "Body Status" "What changed today" "Data freshness"; do
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
    'lib/widgets/sleep_window_dial.dart',
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
