# Healthy Me Beta v0.3.2

Healthy Me is a personal body command center built around connected health telemetry, personal baselines, freshness, trends and plain-language wellness suggestions.

This build continues the approved five-screen design and fixes live-data/source issues found during device testing:

- Home / Daily Body Report
- Activity
- Sleep
- Body
- More / Sources & Plan

The old v0.2 primary navigation (Today / Progress / Connect / Labs / Plan) is retired and blocked by the UI-contract check.

## v0.3.2 fixes

- Larger, readable text throughout the primary UI
- No explicit primary-screen font sizes below 12sp
- Source/package IDs normalized to readable provider names
- Overflow-safe source selectors
- More faithful Body Status hero, chart labels, card spacing and visual hierarchy
- Sources & Plan structure matching the approved mockup while only showing vendors actually detected
- Connected Sources now shows Health Connect plus only vendors actually detected in Health Connect records
- Activity shows the selected step source and step-data freshness
- Distance conversion is normalized from the Health Connect record unit and motion metrics are anchored to one provider to prevent multi-source double counting
- Protect your sleep window now includes a draggable 24-hour circular bedtime/wake dial with planned sleep in the center
- Added a top Healthy Me section launcher for future modules; Fitness is current and Diet is staged for a future Diet / Menu / Planning / Grocery List module
- Improved Weight & Goal, measurements, body fat and progress-photo layout

## Data principles

- Health Connect is the Android aggregation layer.
- Body fat is connected-source only; it is not manually entered.
- Bloodwork stores raw values, units, dates and sources without automatic high/low diagnosis.
- Sleep targets are derived from age/profile.
- Suggestions are wellness guidance, not medical diagnosis or treatment.

See `docs/HEALTHY_ME_PRODUCT_SPEC.md`, `docs/UI_ACCEPTANCE.md` and `docs/CHANGELOG_v0.3.2.md`.
