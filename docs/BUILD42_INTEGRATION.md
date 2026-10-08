# Salus v0.21.4+42 — home integration fix

- The existing generic `SalusDeviceBatteryIndicator` is now actually rendered
  by `HomeScreen._BatteryChip`. Device kind determines ring/watch/other symbol;
  battery fill and numerical percentage use the last recorded real battery
  sample. Device name is retained as a tooltip rather than on the chip.
- Home SpO2 tap directly routes to `/spo2-history` (the Health home card is
  already linked there).
- SpO2 history loads both saved direct BLE observations and Health Connect
  BLOOD_OXYGEN observations when Health Connect is authorized. Raw provider IDs
  and sample timestamps are preserved; readings aren't mixed across sources.
  Chart windows remain 24 hours, 7 days, and 30 days.
- Health Connect history failure doesn't hide working direct-device readings.
- Recovery UI, local driver routing, native Bluetooth drivers, storage IDs,
  package ID, and Android signing settings are unchanged.
- Source-only overlay. GitHub Actions must analyze/test/build/re-sign and verify
  before calling it an installed build. No Python code is shipped.
