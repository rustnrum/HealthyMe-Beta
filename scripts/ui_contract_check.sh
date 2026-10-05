#!/usr/bin/env bash
set -euo pipefail

# Apply Salus product name, version, Android label, and launcher icon after the
# generated Android shell exists and before either UI/source contract validates it.
python3 scripts/salus_brand_patch.py

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
LABS_FILE="lib/screens/labs_screen.dart"
LAB_SERVICE_FILE="lib/services/lab_service.dart"
HEALTH_FILE="lib/services/health_connect_service.dart"
RECOVERY_FILE="lib/services/recovery_service.dart"
BODY_STATUS_FILE="lib/services/body_status_service.dart"
BODY_DETAIL_FILE="lib/screens/body_status_detail_screen.dart"
RECOVERY_DETAIL_FILE="lib/screens/recovery_detail_screen.dart"
DIET_SHELL_FILE="lib/screens/diet/diet_shell.dart"
DIET_HOME_FILE="lib/screens/diet/diet_home_screen.dart"
HEALTH_SHELL_FILE="lib/screens/health/health_shell.dart"
HEALTH_HOME_FILE="lib/screens/health/health_home_screen.dart"
HEALTH_VITALS_FILE="lib/screens/health/health_vitals_screen.dart"
MODULE_MENU_FILE="lib/widgets/module_menu_button.dart"
SALUS_WIDGETS_FILE="lib/widgets/salus_widgets.dart"

# Main module shell remains the same functional navigation, but branded Salus.
for required in "'Home'" "'Activity'" "'Sleep'" "'Body'" "'More'" "'Salus'"; do
  grep -q "$required" "$SHELL_FILE" || fail "main module shell missing: $required"
done

for forbidden in "Beta 0.2" "Healthy Me"; do
  if grep -q "$forbidden" "$SHELL_FILE"; then
    fail "stale main-module branding found: $forbidden"
  fi
done

# Approved Salus parchment home layout replaces the old mountain/status-card design.
for required in "SalusPaper" "Today" "At a glance" "Sources" "Connected to a clearer you" "Check-in"; do
  grep -q "$required" "$HOME_FILE" || fail "Salus home screen missing approved element: $required"
done
if grep -q "hero_mountains.jpg" "$HOME_FILE"; then
  fail "old mountain hero must not remain in Salus home"
fi

for required in "class SalusPaper" "class SalusSectionTitle" "class SalusMetric" "class SalusModuleRow" "class SalusStatusDot"; do
  grep -q "$required" "$SALUS_WIDGETS_FILE" || fail "Salus shared visual system missing: $required"
done


# The approved visual direction is asset-driven, not a Material-icon approximation.
for asset in \
  lib/assets/salus/paper_texture.png \
  lib/assets/salus/dark_texture.png \
  lib/assets/salus/branch_gold.png \
  lib/assets/salus/metric_weight.png \
  lib/assets/salus/metric_sleep.png \
  lib/assets/salus/metric_steps.png \
  lib/assets/salus/metric_recovery.png \
  lib/assets/salus/tile_body.png \
  lib/assets/salus/tile_sleep.png \
  lib/assets/salus/tile_activity.png \
  lib/assets/salus/tile_notes.png \
  lib/assets/salus/art_body.png \
  lib/assets/salus/art_sleep.png \
  lib/assets/salus/art_activity.png \
  lib/assets/salus/art_notes.png; do
  [ -s "$asset" ] || fail "required Salus visual asset missing or empty: $asset"
done

grep -q "lib/assets/salus/" pubspec.yaml || fail "pubspec must package Salus visual assets"
grep -q "SalusAssets.metricWeight" "$HOME_FILE" || fail "home must use the approved metric image assets"
grep -q "SalusAssets.tileBody" "$HOME_FILE" || fail "home must use the approved module tile image assets"
grep -q "SalusAssets.artSleep" "$HOME_FILE" || fail "home must use the approved decorative line-art assets"
grep -q "AssetImage(SalusAssets.paperTexture)" "$SALUS_WIDGETS_FILE" || fail "shared Salus paper surface must use the parchment texture asset"

# Existing functional detail screens remain required while their visual refresh can evolve incrementally.
for required in "Day" "Week" "Month" "Year" "Workouts" "Weekly activity" "Automatic"; do
  grep -q "$required" "$ACTIVITY_FILE" || fail "activity screen missing approved element: $required"
done
for required in "Total Sleep" "Sleep Stages" "Sleep Insight" "Sleep Consistency"; do
  grep -q "$required" "$SLEEP_FILE" || fail "sleep screen missing approved section: $required"
done
for required in "Weight" "Measurements" "Composition" "Body Measurements" "Body Fat" "Progress Photos" "BMI" "Calculated"; do
  grep -q "$required" "$BODY_FILE" || fail "body screen missing approved section: $required"
done
grep -q "_MeasurementsDialog" "$BODY_FILE" || fail "body measurement entry must use an owned dialog lifecycle"

for required in "Data Sources" "Your Plan" "Health"; do
  grep -q "$required" "$MORE_FILE" || fail "More screen missing approved element: $required"
done

# The three top-level Salus modules must stay distinct.
for required in "SALUS MODULES" "Main" "Diet" "Health" "Today • Meals • Plan • Grocery" "Overview • Vitals • Labs"; do
  grep -q "$required" "$MODULE_MENU_FILE" || fail "Salus module launcher missing: $required"
done

for required in "Today" "Meals" "Plan" "Grocery" "SALUS"; do
  grep -q "$required" "$DIET_SHELL_FILE" || fail "Diet module shell missing destination/brand: $required"
done
for required in "Nourish with intention" "Daily nutrition" "Add Food" "Focus Today" "Meals"; do
  grep -q "$required" "$DIET_HOME_FILE" || fail "Diet Today screen missing approved Salus element: $required"
done

for required in "Health" "Vitals" "Labs" "SALUS"; do
  grep -q "$required" "$HEALTH_SHELL_FILE" || fail "Health module shell missing destination/brand: $required"
done
for required in "A broader picture" "Current Vitals" "Bloodwork" "Health Context"; do
  grep -q "$required" "$HEALTH_HOME_FILE" || fail "Health overview missing approved Salus element: $required"
done
grep -q "Current signals" "$HEALTH_VITALS_FILE" || fail "Vitals screen missing Salus section language"

# Source-routing and lab rules remain intact.
grep -q "Automatic" "$SOURCES_FILE" || fail "source selection must have one clear automatic default"
grep -q "Change" "$SOURCES_FILE" || fail "source selection must expose one clear change action"
grep -q "availableSources" "$SOURCES_FILE" || fail "source options must be metric-specific"
grep -q "SourceNameService.friendly" "$SOURCES_FILE" || fail "raw provider/package names must be normalized"

for required in "Common bloodwork" "Add other result"; do
  grep -q "$required" "$LABS_FILE" || fail "labs screen missing structured-entry element: $required"
done
for required in "CBC" "CMP / Metabolic" "Lipids" "HbA1c" "Total testosterone" "Progesterone"; do
  grep -q "$required" "$LAB_SERVICE_FILE" || fail "lab definitions missing $required"
done

# Core telemetry rules.
grep -q "Source: \$stepSourceLabel" "$ACTIVITY_FILE" || fail "activity must identify the selected step source"
grep -q "Step data" "$ACTIVITY_FILE" || fail "activity must show step data freshness"
grep -q "SleepWindowDial" "$PLAN_FILE" || fail "plan must include the circular sleep-window control"
grep -q "distanceValueToMiles" "$HEALTH_FILE" || fail "distance must be normalized before display"
grep -q "resolvedMotionSource" "$HEALTH_FILE" || fail "motion metrics must avoid multi-provider double counting"
grep -q "availableSources" "$HEALTH_FILE" || fail "Health Connect sync must retain metric-specific source options"
grep -q "respiratoryRate30" "$HEALTH_FILE" || fail "respiratory history must be retained for personal baseline logic"
grep -q "hrv30" "$HEALTH_FILE" || fail "HRV history must be retained for recovery baseline logic"
grep -q "class RecoveryService" "$RECOVERY_FILE" || fail "recovery must be a calculated service"
grep -q "_hrvContributor" "$RECOVERY_FILE" || fail "recovery must use HRV when a baseline is available"
grep -q "_restingHeartRateContributor" "$RECOVERY_FILE" || fail "recovery must use resting HR against personal baseline"
grep -q "_breathingContributor" "$RECOVERY_FILE" || fail "recovery must use respiratory stability when available"
grep -q "Training load" "$RECOVERY_FILE" || fail "recovery must include recent training load"
grep -q "report.score" "$BODY_STATUS_FILE" || fail "recovery status must expose a numeric score"
grep -q "Not included until Diet has real food data" "$RECOVERY_FILE" || fail "recovery must not guess nutrition"
grep -q "weightTrend" "$BODY_STATUS_FILE" || fail "body status must use weekly goal-directed weight trend"
grep -q "respiratoryRate" "$BODY_STATUS_FILE" || fail "cardio status must support respiratory rate"
grep -q "What.s affecting your status" "$BODY_DETAIL_FILE" || fail "Body Status detail must explain the rating"
grep -q "Recovery contributors" "$RECOVERY_DETAIL_FILE" || fail "Recovery detail must show contributors"

# Readability floor: no primary app UI text below 12sp.
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
    'lib/screens/labs_screen.dart',
    'lib/screens/body_status_detail_screen.dart',
    'lib/screens/recovery_detail_screen.dart',
    'lib/widgets/sleep_window_dial.dart',
    'lib/widgets/module_menu_button.dart',
    'lib/widgets/salus_widgets.dart',
    'lib/screens/diet/diet_shell.dart',
    'lib/screens/diet/diet_home_screen.dart',
    'lib/screens/diet/diet_menu_screen.dart',
    'lib/screens/diet/diet_planning_screen.dart',
    'lib/screens/diet/grocery_list_screen.dart',
    'lib/screens/health/health_shell.dart',
    'lib/screens/health/health_home_screen.dart',
    'lib/screens/health/health_vitals_screen.dart',
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

echo "Salus v0.13 asset-driven UI contract + readability checks passed."
