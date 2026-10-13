# Salus Build 83 — provider-neutral HRV and COLMI protocol correction

## What changes
- One source-aware HrvSourceService resolves both qualified RMSSD and device-reported firmware HRV indexes for Home, Health, and HRV Details.
- Automatic routing prefers a qualified HRV measurement. Manual routing never silently substitutes a different provider.
- Any direct device or Health Connect provider emitting **HRV (RMSSD ms)** can feed HRV, Recovery, and Energy through the existing health snapshot source routing.
- COLMI/QRing command 57 is read correctly: 12 values from first data page, 13 values per continuation page. Page 2+ is not a new slot offset. Packets are checksum-verified; malformed or future readings are rejected.
- Ring command-57 readings are a **proprietary firmware index**, not verified RMSSD (milliseconds). They are graphed as an index and remain excluded from physiological Recovery HRV scoring.
- Source choices are capability based, not hard-coded to a ring brand. Index-only providers appear with an explicit explanation.

## Preserved
- Existing Android package identity and permanent signing key.
- User data, source selections, saved direct readings, Recovery formula, and legacy provider imports.
- Salus layout, full-screen mountain artwork, appearance settings, module navigation.

## Tests
- A standalone Kotlin fixture compiles and executes against the actual protocol decoder (run locally; included in docs for reference).
- Dart source unit tests cover automatic vs manual routing, true RMSSD vs index, source isolation, and missing/future values.
- CI must still pass flutter analyze, flutter test, build and signing before an APK is distributed.

## Limitations
- QRing's firmware index is not a medically validated HRV measurement in ms. No mathematical conversion to RMSSD is invented.
- If no device emits RMSSD, Recovery correctly displays HRV as unavailable, although device-index trends can be viewed.
- The actual firmware version's packet replies should be checked on the user's handset to confirm reading counts and timestamps.
