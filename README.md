# Healthy Me Beta v0.3

Healthy Me is a personal body command center built around connected health telemetry, personal baselines, freshness, trends and plain-language wellness suggestions.

This v0.3 source package implements the approved five-screen redesign:

- Home / Daily Body Report
- Activity
- Sleep
- Body
- More / Sources & Plan

The old v0.2 primary navigation (Today / Progress / Connect / Labs / Plan) is retired and blocked by a CI UI-contract check.

## Data principles

- Health Connect is the Android aggregation layer.
- Body fat is connected-source only; it is not manually entered.
- Bloodwork stores raw values, units, dates and sources without automatic high/low diagnosis.
- Sleep targets are derived from age/profile.
- Suggestions are wellness guidance, not medical diagnosis or treatment.

See `docs/HEALTHY_ME_PRODUCT_SPEC.md` and `docs/UI_ACCEPTANCE.md`.
