#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "UI CONTRACT FAILURE: $1" >&2
  exit 1
}

SHELL_FILE="lib/screens/home_shell.dart"
HOME_FILE="lib/screens/home_screen.dart"
BODY_FILE="lib/screens/body_screen.dart"
MORE_FILE="lib/screens/more_screen.dart"

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

for required in "Weight" "Measurements" "Composition" "Progress Photos"; do
  grep -q "$required" "$BODY_FILE" || fail "body screen missing approved section: $required"
done

for required in "Connected Sources" "Your Plan"; do
  grep -q "$required" "$MORE_FILE" || fail "More screen missing approved section: $required"
done

echo "Healthy Me approved UI contract markers present."
