# Salus Build 58 · source-matched recovery history

Fix: the direct-device snapshot merger previously replaced the current HRV,
resting-HR, and respiratory-rate fields but did not replace their histories.
Thus the main screen could display valid data while Recovery reported N/A.

- Rebuild a 30-day, one-reading-per-calendar-day history only from the same
  direct device that supplied the current metric. No mixed-source baselines,
  no duplicated same-day Bluetooth polls inflating history counts.
- Keep imported Health Connect histories when the selected reading is from HC.
- Show current objective readings in Recovery even when there are too few
  historical measurements for a trend score; explain the count.
- Show completed manually tracked Salus workouts as present but not scored,
  because the current workout completion model does not contain actual duration.
- Use those completed workout records in both the home and Recovery screens.
- Preserve existing HealthSnapshot persisted schema, direct sample storage key,
  Garmin BLE/GFDI native sources, and signing/package identity.

Regression tests added for direct-source filtering, one-reading-per-day
baselines, visible current numbers, and handling of completed workout records.

The existing recovery score safety gate stays in place, so a single sleep
measurement cannot turn into a full recovery score.
