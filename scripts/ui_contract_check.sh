#!/usr/bin/env bash
set -euo pipefail

python3 scripts/direct_device_patch.py
python3 scripts/salus_brand_patch.py
python3 scripts/build26_fix_patch.py

fail() { echo "UI CONTRACT FAILURE: $1" >&2; exit 1; }

HOME="lib/screens/home_screen.dart"
SHELL="lib/screens/home_shell.dart"
WIDGETS="lib/widgets/salus_widgets.dart"
SOURCES="lib/screens/sources_screen.dart"

grep -q '^version: 0.14.0+26$' pubspec.yaml || fail "build 26 version missing"
grep -q 'SALUS_BUILD26_ACTIVE_SOURCES' lib/services/source_hub_service.dart || fail "active-source pruning missing"
grep -q 'SALUS_BUILD26_CURRENT_SOURCE_STATE' lib/state/health_sync_provider.dart || fail "current-source sync missing"
grep -q 'DirectMetricService' "$SOURCES" || fail "direct metric reader UI missing"
grep -q "'Read data'" "$SOURCES" || fail "Read data action missing"
grep -q "'Pair'" "$SOURCES" || fail "truthful Pair action missing"
grep -q "'vívoactive'," lib/services/ble_protocol_profiles.dart || fail "Vivoactive accented identity missing"

# Preserve the actual build-25 home implementation. The pinned calendar lives
# in salus_widgets.dart and home_shell.dart, not in home_screen.dart.
for required in \
  "class _SalusLandscapePainter" \
  "Dotted biometric landscape" \
  "class SalusWeekStrip" \
  "class SalusGlassMetricCard" \
  "class SalusRecoveryOrb"; do
  grep -q "$required" "$WIDGETS" || fail "build 25 visual primitive missing: $required"
done
grep -q 'child: SalusWeekStrip()' "$SHELL" || fail "weekday calendar is not pinned in Home app bar"
grep -q 'Size.fromHeight(132)' "$SHELL" || fail "Home app bar height does not include weekday calendar"
grep -q "Today’s Focus" "$HOME" || fail "Today’s Focus missing"

# Build 26 fixes for the hardware strip overflow seen on-device.
grep -q 'height: 170' "$SOURCES" || fail "device card viewport height fix missing"
grep -q 'height: 66' "$WIDGETS" || fail "device artwork height fix missing"
grep -q 'overflow: TextOverflow.ellipsis' "$WIDGETS" || fail "device card text overflow protection missing"

echo "Salus build 26 UI contract passed."
