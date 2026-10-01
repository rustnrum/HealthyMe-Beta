# Healthy Me Beta v0.3.4

Healthy Me is a personal body command center built around connected health telemetry, personal baselines, freshness, trends and plain-language wellness suggestions.

This build focuses on making Home behave like a command center rather than another tracker.

## v0.3.4 focus

- Scenic, tappable Body Status hero
- Body Status detail page explaining what affected the rating, positive signals and suggested actions
- Real Recovery calculation from sleep, cardio recovery and recent training load
- Recovery detail page with contributor scores and confidence
- Nutrition explicitly excluded from Recovery until Diet has real food data
- Weight tile colors based on weekly progress toward the user's goal instead of always showing green
- Cardio tile supports resting heart rate plus respiratory rate when available
- HRV and respiratory-rate history retained for personal-baseline logic
- Today's focus/action strip on Home
- Existing source detection, step source/freshness, distance normalization, sleep-window dial and future Diet section launcher remain in place

## Update-channel direction

The beta keeps the stable package ID `com.rustnrum.healthyme.beta03` and increasing version codes. The permanent in-place update channel will switch to one stable release signing key stored only in GitHub Secrets. That transition may require one final uninstall from the current debug-signed beta; after it, later APKs signed by the same key can install as normal updates and preserve app data.

## Data principles

- Health Connect is the Android aggregation layer.
- Body fat is connected-source only; it is not manually entered.
- Bloodwork stores raw values, units, dates and sources without automatic high/low diagnosis.
- Sleep targets are derived from age/profile.
- Suggestions are wellness guidance, not medical diagnosis or treatment.

See `docs/HEALTHY_ME_PRODUCT_SPEC.md`, `docs/UI_ACCEPTANCE.md`, `docs/CHANGELOG_v0.3.4.md` and `docs/PERMANENT_BETA_UPDATES.md`.
