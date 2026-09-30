# Healthy Me Beta v0.3.1

Healthy Me is a personal body command center built around connected health telemetry, personal baselines, freshness, trends and plain-language wellness suggestions.

This build tightens the approved five-screen design and fixes the problems found in the first v0.3 APK:

- Home / Daily Body Report
- Activity
- Sleep
- Body
- More / Sources & Plan

The old v0.2 primary navigation (Today / Progress / Connect / Labs / Plan) is retired and blocked by the UI-contract check.

## v0.3.1 fixes

- Larger, readable text throughout the primary UI
- No explicit primary-screen font sizes below 12sp
- Source/package IDs normalized to readable provider names
- Overflow-safe source selectors
- More faithful Body Status hero, chart labels, card spacing and visual hierarchy
- Five-provider Sources & Plan list matching the approved mockup structure while keeping connection states truthful
- Improved Weight & Goal, measurements, body fat and progress-photo layout

## Data principles

- Health Connect is the Android aggregation layer.
- Body fat is connected-source only; it is not manually entered.
- Bloodwork stores raw values, units, dates and sources without automatic high/low diagnosis.
- Sleep targets are derived from age/profile.
- Suggestions are wellness guidance, not medical diagnosis or treatment.

See `docs/HEALTHY_ME_PRODUCT_SPEC.md`, `docs/UI_ACCEPTANCE.md` and `docs/CHANGELOG_v0.3.1.md`.
