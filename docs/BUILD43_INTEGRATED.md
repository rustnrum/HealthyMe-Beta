# Salus integrated Build 43 — v0.21.5+43

One source-overlay release for the existing HealthyMe-Beta signing/build workflow.

## Included and wired
- Today: HRV, resting HR and respiration cards open dedicated history charts;
  SpO2 uses its dedicated history chart; other existing card routes remain intact.
- New metric-history detail page: selectable day/week/month windows, actual
  source IDs, labeled value axes, measured points, timestamps, source picker,
  latest/low/high/average. No interpolation or provider mixing.
- Health: vital summaries and rows link into individual charts; Bloodwork
  links into real Labs UI.
- Diet: manual logged servings and explicitly entered nutrients persisted to
  local preferences, saved reusable meals, logged meal records, editable manual
  grocery checklist, existing meal-planning tab preserved.
- Body: new high-resolution front/back illustration and measured reference with recorded tape and
  measured composition values, without estimating body fat.
- Device Gallery: eight device-type images from the supplied BLE proposal,
  installed-driver status distinct from recognition-only, real battery values.
- More: direct navigable entries for device gallery, source settings, body
  illustration, plans and other existing screens; sleep/activity plan items
  open the corresponding module instead of generic Trends.
- Existing source routing, working BLE readers, Recovery orb, permanent
  Android application package, signing key, and saved-data keys preserved.

## Important restrictions
- Diet food entry is manual. No fake photo/barcode/voice support.
- Grocery items are entered manually because existing meal-planning entries
  are plain text without a structured ingredient/quantity breakdown.
- Proprietary watch notifications are **not** universally supported just
  because a watch is identified or its metrics can be read. No false sender.
- Proprietary BLE decoder support is unchanged; this update exposes
  installed-versus-recognized driver status, not invented decoding.
- Recovery baseline requirements are unchanged. A missing score does not
  automatically imply a bug; see contributor coverage in Recovery details.
- Old historical data cannot be created if a provider does not supply it.

## Validation
- Source navigation/data tests included in test/build43_navigation_contract_test.dart,
  test/diet_log_state_test.dart, and test/metric_history_service_test.dart.
- MUST pass `flutter pub get`, `flutter analyze`, `flutter test` and an Android
  APK build/sign/verify in GitHub Actions before the release can be called built.
- Hardware Bluetooth and notification behavior requires real-device testing.
