# Salus Build 45 – local automatic BLE discovery

- When the user opens the device discovery page, Salus **automatically scans**
  nearby BLE advertisements **without a brand or service filter**.
- It automatically attempts read-only GATT inspection (maximum 16 candidates
  per pass; small concurrent batches), beginning with likely health devices.
- It keeps unidentified devices visible and shows the actual discovered GATT
  service/characteristic data, local protocol match and reader status.
- No auto-bond, device write, or account/companion-app handoff during scanning.
- The user's existing connected device records, data, source preferences,
  package ID, and permanent signing setup are preserved.
- The non-independent Build 44 companion relay is removed, and previously
  enabled companion-relay switches are migrated to OFF. The existing direct
  IDO/VeryFit sender and original Android notification listener are retained.
- Device pairing/registration requires tapping Add; reads require tapping Sync.
- Scanning refreshes on return to app after two minutes and on explicit refresh.
- Existing advanced Connections UI is retained for Health Connect, metric-source
  preferences, saved devices and notification permissions.

## Important scope
This implements independent BLE **discovery and capability inspection**.
It does not manufacture proprietary decoders, authentication, or watch
notification-writing protocols. The old Build 44 companion relay is now
removed, not replaced with another app. A separate verified local write driver
and a real-watch test are required for each nonstandard notification transport.
Salus must not label those as completed.

## Verification
This ZIP is source only. GitHub Actions must run flutter analyze, flutter test,
APK build, permanent signing and certificate verification before any APK
is offered. Real-device scanning, pairing and GATT support need on-device checks.
