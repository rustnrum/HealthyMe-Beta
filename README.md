# Healthy Me Beta v0.3

Healthy Me is being built as a **personal body command center** rather than another generic fitness
tracker.

## v0.3

This build implements the approved dark command-center design and connects the major screens to one
shared data model.

Bottom navigation:
- Home
- Activity
- Sleep
- Body
- More

Deeper screens:
- Heart Health
- Devices & Sources
- Labs
- Goals
- Progress Photos
- Profile
- Plan

## Real Android health data

v0.3 uses Google Health Connect through the Flutter `health` package. Health Connect authorization is
real: the app requests read access and syncs available health data. Vendor cards are not marked
connected unless data from those sources is actually detected.

Direct Garmin/Fitbit/Withings cloud OAuth integrations are not represented as connected until those
vendor APIs are implemented.

Healthy Me gives wellness status and guidance. It does not diagnose medical conditions.
