# Healthy Me — Health Connect / Source Plan

Updated: 2026-10-04

## Scope for today's beta
Focus only on Health Connect discovery, refresh, source identity, source selection, and source diagnostics. Do not change Daily State, dashboard design, diet, or unrelated features.

## Problems confirmed in current code
- Source discovery is record-based, not true installed-app discovery. A provider only appears after Health Connect returns at least one supported record from it inside the query window.
- Healthy Me currently uses `sourceName` as the primary source identity and discards `sourceId`. This is too fragile for Android Health Connect origins.
- User-selected metric sources are persisted indefinitely and can become stale if a provider stops writing or its source identity changes.
- `availableSources` is rebuilt only from records found in the current sync, so providers can disappear from the UI instead of being maintained as a persistent discovered-source registry.
- Auto / “Health Connect recommended” is only truly aggregate-aware for steps. Raw metrics such as sleep, HR, weight, body fat, and workouts currently accept all matching-source records when Auto is selected.
- Refresh currently happens on app startup, resume, or manual refresh; there is no periodic foreground refresh while Healthy Me stays open.
- Current refresh is heavier than needed because steps are queried repeatedly for hourly/daily/monthly totals.

## Source architecture rules
1. Use stable Health Connect data-origin identity (`sourceId` / package origin) as the source key. Use `sourceName` only as display metadata/fallback.
2. Maintain a persistent discovered-provider registry with provider key/package, friendly display name, metrics actually supplied, last-seen timestamp per metric, and latest record timestamp per metric.
3. Re-scan sources on app resume, Data Sources screen open, manual refresh, and a modest foreground interval while app remains open.
4. If a selected source stops providing fresh data, flag it clearly and offer Auto / another currently active provider. Do not silently return stale/blank data.
5. Show exactly which provider is feeding each metric.
6. Do not label a raw multi-source read “Health Connect recommended” unless Health Connect aggregate/priority handling is actually being used.
7. Add a diagnostics view showing raw sourceId, sourceName, metric type, and latest record time.
8. Reduce duplicate Health Connect calls during one refresh.

## COLMI R02 / QRing
User device: COLMI R02 using QRing.

Confirmed hardware / BLE capabilities from COLMI specs and independent reverse engineering:
- STK8321 accelerometer
- Vcare VC30F optical HR / SpO2 sensor
- Heart rate history and real-time HR
- SpO2 real-time measurement and stored/history data
- Steps / activity, calories and distance
- Sleep records/stages
- Battery / charge state
- Raw accelerometer and PPG streams are accessible over BLE in open-source implementations
- HRV is exposed by newer reverse-engineered protocol implementations, but should be treated as experimental/firmware-dependent until validated on this exact ring
- “Stress” is exposed by some reverse-engineered implementations, but should be treated as vendor/firmware-derived rather than a clinical measurement
- Some newer community implementations report skin-temperature support on R02 firmware variants; official R02 hardware docs do not list a temperature sensor, so Healthy Me must not assume temperature exists until direct device probing confirms it on this ring

Important: SpO2 is definitely available from the R02 hardware over BLE even if QRing is not exporting it into Health Connect. Healthy Me should therefore support a direct BLE R02 source path for ring metrics that QRing fails to publish.

## iMoni / body-composition scale
User scale path has iMoni and provides measured body-composition values including Body Fat %.

Source precedence rule:
- Prefer a direct measured metric from the device/scale when available.
- Do not replace a measured scale Body Fat % with a calculated or estimated value.
- BMI may be calculated from measured height + weight because BMI is inherently calculated.
- For composition metrics not directly exposed by Health Connect, Healthy Me may derive or import from other trustworthy device data only when the metric is not already directly measured by the scale.

Known iMoni-side composition set previously observed includes weight, BMI, body fat %, body water %, muscle mass, skeletal muscle mass, bone mass, protein %, visceral fat, BMR and related composition outputs. Health Connect availability for each field must be verified from actual records, not assumed from what the iMoni UI displays.

## Design principle
Measured > directly device-derived > Health Connect aggregate > calculated > estimated.
Never hide the origin. Label values as Measured / Calculated / Estimated and show the source provider.
