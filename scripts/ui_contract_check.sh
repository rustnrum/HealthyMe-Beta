#!/usr/bin/env bash
set -euo pipefail

# Ensure the build-23 direct-device Sources UI exists before applying v24 styling.
python3 scripts/direct_device_patch.py
python3 scripts/salus_brand_patch.py

fail() { echo "UI CONTRACT FAILURE: $1" >&2; exit 1; }

THEME="lib/core/theme/app_theme.dart"
HOME="lib/screens/home_screen.dart"
SHELL="lib/screens/home_shell.dart"
ONBOARD="lib/screens/onboarding_screen.dart"
AI="lib/screens/ai_coach_screen.dart"
SOURCES="lib/screens/sources_screen.dart"
WIDGETS="lib/widgets/salus_widgets.dart"
APP="lib/app.dart"

# Build identity and core routes.
grep -q '^version: 0.14.0+24$' pubspec.yaml || fail "pubspec must identify build 24"
grep -q "title: 'Salus'" "$APP" || fail "app title missing"
grep -q "'/coach': (_) => const AiCoachScreen()" "$APP" || fail "Salus AI route missing"
grep -q "'/sources': (_) => const SourcesScreen()" "$APP" || fail "direct-device source route missing"
grep -q 'ThemeMode.dark' "$APP" || fail "Salus v24 must use dark visual system"

# Locked visual direction: midnight glass, cyan/mint light, modern sans typography.
for required in "0xFF05090D" "0xFF62E8F2" "glassGradient" "Brightness.dark"; do
  grep -q "$required" "$THEME" || fail "new visual system missing: $required"
done
if grep -q 'warm parchment' "$THEME"; then fail "old parchment theme remains"; fi

for required in \
  "class SalusPageBackground" \
  "class SalusPaper" \
  "class SalusRecoveryOrb" \
  "class SalusGlassMetricCard" \
  "class SalusDeviceTypeCard" \
  "salus_profile_hero.png" \
  "salus_ai_orb.png" \
  "salus_sources_orbit.png"; do
  grep -q "$required" "$WIDGETS" || fail "shared Salus v24 visual primitive missing: $required"
done

for asset in \
  lib/assets/salus/salus_profile_hero.png \
  lib/assets/salus/salus_ai_orb.png \
  lib/assets/salus/salus_sources_orbit.png \
  lib/assets/salus/salus_device_ring.png \
  lib/assets/salus/salus_device_watch.png \
  lib/assets/salus/salus_device_scale.png \
  lib/assets/salus/salus_device_cpap.png; do
  [ -s "$asset" ] || fail "new Salus visual asset missing: $asset"
done

# Onboarding reference layout and data capture.
for required in "Create your" "Salus profile" "Select Height" "Select Weight" "Primary goal" "Typical activity"; do
  grep -q "$required" "$ONBOARD" || fail "onboarding missing: $required"
done
for required in "SalusRecoveryOrb" "Good Morning" "Respiration" "SpO₂" "Today’s Focus" "pushNamed('/sources')" "pushNamed('/coach')"; do
  grep -q "$required" "$HOME" || fail "dashboard missing: $required"
done
for required in "class AiCoachScreen" "SALUS AI" "MEET YOUR AI COACH" "TRY ASKING"; do
  grep -q "$required" "$AI" || fail "AI coach visual missing: $required"
done
for required in "S a l u s" "Home" "Activity" "Sleep" "Body" "More"; do
  grep -q "$required" "$SHELL" || fail "main shell missing: $required"
done
for required in "Devices & Sources" "CONNECT YOUR WORLD" "SalusDeviceTypeCard" "Pair direct devices" "Saved direct devices"; do
  grep -q "$required" "$SOURCES" || fail "device/source hub missing: $required"
done

# Existing app modules remain present.
for path in \
  lib/screens/activity_screen.dart \
  lib/screens/sleep_screen.dart \
  lib/screens/body_screen.dart \
  lib/screens/more_screen.dart \
  lib/screens/trends_screen.dart \
  lib/screens/recovery_detail_screen.dart \
  lib/screens/workout_screen.dart; do
  [ -s "$path" ] || fail "existing module missing: $path"
done

# Readability floor in the new reference surfaces.
python3 - <<'PY'
from pathlib import Path
import re
files = [
    'lib/screens/home_screen.dart',
    'lib/screens/home_shell.dart',
    'lib/screens/onboarding_screen.dart',
    'lib/screens/ai_coach_screen.dart',
    'lib/widgets/salus_widgets.dart',
]
violations=[]
for name in files:
    text=Path(name).read_text()
    for m in re.finditer(r'fontSize:\s*([0-9]+(?:\.[0-9]+)?)', text):
        if float(m.group(1)) < 12:
            violations.append(f'{name}:{m.group(1)}')
if violations:
    raise SystemExit('UI CONTRACT FAILURE: text below 12sp: ' + ', '.join(violations))
PY

echo "Salus build 24 locked visual system contract passed."
