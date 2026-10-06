#!/usr/bin/env bash
set -euo pipefail

# Base repo may be build 23/24. Ensure direct-device UI exists, then apply v25.
python3 scripts/direct_device_patch.py
python3 scripts/salus_brand_patch.py

fail() { echo "UI CONTRACT FAILURE: $1" >&2; exit 1; }

THEME="lib/core/theme/app_theme.dart"
HOME="lib/screens/home_screen.dart"
SHELL="lib/screens/home_shell.dart"
SOURCES="lib/screens/sources_screen.dart"
WIDGETS="lib/widgets/salus_widgets.dart"
APP="lib/app.dart"

# Identity and routes.
grep -q '^version: 0.14.0+25$' pubspec.yaml || fail "pubspec must identify build 25"
grep -q "title: 'Salus'" "$APP" || fail "app title missing"
grep -q "'/sources': (_) => const SourcesScreen()" "$APP" || fail "device route missing"
grep -q 'ThemeMode.dark' "$APP" || fail "dark theme missing"

# Locked v25 background and fixed calendar.
for required in "class _SalusLandscapePainter" "Dotted biometric landscape" "class SalusWeekStrip" "class SalusGlassMetricCard" "class SalusRecoveryOrb"; do
  grep -q "$required" "$WIDGETS" || fail "v25 visual primitive missing: $required"
done
grep -q 'child: SalusWeekStrip()' "$SHELL" || fail "weekday calendar is not pinned in Home app bar"
grep -q 'Size.fromHeight(132)' "$SHELL" || fail "Home app bar height does not include weekday calendar"
if grep -q 'class _WeekStrip' "$HOME"; then fail "obsolete scroll-only week strip remains"; fi

# Overflow prevention is structural: taller cards plus one-line scaled status and
# recovery subtitle outside the orb painter.
grep -q 'height: 134' "$HOME" || fail "top metric cards were not enlarged"
grep -q 'height: 126' "$HOME" || fail "secondary metric cards were not enlarged"
grep -q 'softWrap: false' "$WIDGETS" || fail "metric status text is not constrained"
grep -q 'fit: BoxFit.scaleDown' "$WIDGETS" || fail "scaled metric text protection missing"
grep -q 'width: 280' "$WIDGETS" || fail "recovery subtitle not separated beneath orb"

# Direct device scanner/pairing must be first-class and visible near the top.
for required in "SALUS_BUILD25_DIRECT_FIRST" "Direct devices" "Scan for devices" "Connect" "Connected" "_bluetoothCard(bluetoothSources)"; do
  grep -q "$required" "$SOURCES" || fail "working direct-device UI missing: $required"
done

# New launcher sources must be present in the overlay/repo.
for folder in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  [ -s "branding/android/mipmap-${folder}/ic_launcher.png" ] || fail "new launcher missing for ${folder}"
done

# No primary text below 12sp in reference surfaces.
python3 - <<'PY'
from pathlib import Path
import re
files = [
    'lib/screens/home_screen.dart',
    'lib/screens/home_shell.dart',
    'lib/widgets/salus_widgets.dart',
    'lib/screens/sources_screen.dart',
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

echo "Salus build 25 UI contract passed."
