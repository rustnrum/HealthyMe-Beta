# Salus local device drivers — Build 41

Salus does not assume that identifying a wearable means it can decode its data.

* Scan and inspect devices using the existing BLE discovery service.
* Recognize standard GATT characteristics and bundled protocol fingerprints.
* Dispatch reads through `SalusLocalDeviceDrivers` in Dart; the native
  Android protocol reader remains the backend for existing proprietary code.
* Only the implemented Bluetooth standard Heart Rate and Battery decoders can
  be claimed as generic GATT data readers in this build.
* Preserve source IDs, timestamps, and stored readings through the existing
  `DirectMetricService` code. Do not invent backfill or unavailable metrics.
* An unsupported proprietary family remains **recognized-only** until a
  decoder that can authenticate, request and parse real data is provided.
* No runtime-downloaded code or Python source mutators.

## Remaining protocol boundary

The large Android `SalusProtocolReader.kt` still contains legacy proprietary
parsers. It is now behind the Dart registry/transport interface, but physical
extraction into independent native driver classes is a separate refactor. Do
not claim that every proprietary device works by scanning alone. A native
backend may be in use by the original companion app; a read may temporarily
interrupt notifications. Avoid resets, invasive probes or replaying unknown
commands automatically.
