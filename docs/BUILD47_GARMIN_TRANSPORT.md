# Build 47 — persistent direct Garmin transport and diagnostics

Build 46's per-notification BLE session was insufficient. Build 47 adds:

- One persisted-in-process Garmin BLE/GFDI session per saved, opted-in watch (rather than a new connection for each alert).
- Startup of enabled Garmin sessions when Android binds the Salus notification listener and when the master toggle is enabled.
- Bounded notification queue, reconnect backoff, and session cleanup on disable.
- Explicit Garmin-only **Send test notification** button through the native Flutter channel. No extra Android notification or manufacturer companion app is required for this test.
- Diagnostics reporting Bluetooth connection, GFDI service discovery and registration, watch notification subscription, notification update, attribute requests, and transfer errors. Watch Settings refreshes transport status every four seconds.
- Preserves existing automatic BLE device discovery, profiles and IDO/VeryFit sender. Other registry families remain recognition-only if no corresponding sender is installed.

## Known limits, not yet resolved

- The Garmin driver is still **experimental**, not proven against a physical vívoactive 6. The watch may require further pairing, encrypted services, initialization, or protocol support. A protocol registration or GATT write does not confirm the alert appears on-screen.
- BLE persistence is within the Android notification listener service lifetime; Android may kill/restart that service. Sessions restart when the service is rebound; this is not a guaranteed always-on foreground connection.
- The current Garmin notification driver supports GFDI v2 only; additional watch brands need actual protocol drivers, not just registry names.
- Native transport checks can run with Kotlin stubs locally. Only GitHub's full Android+Flutter build and physical watch testing can confirm an installable APK and runtime behavior.

## How to verify on the phone

1. Install Build 47 over the current beta without clearing app data.
2. Open Watch Settings for the Garmin; enable **Phone notifications on this watch**.
3. Tap **Send test notification**.
4. Read **Bluetooth transport** and **Bluetooth event history**. A subscription or content request proves the watch reached that protocol stage. If connection fails, the status should show the actual stage and Android/GATT error.
5. Report the final stage and history if it still does not appear. Do not treat "notification allowed" as delivered.

## Protocol acknowledgements

Garmin GFDI framing and message handling are based on publicly available reference code from the Gadgetbridge project (AGPL-3.0-or-later) and should be reviewed for license compliance before redistribution under incompatible terms.
