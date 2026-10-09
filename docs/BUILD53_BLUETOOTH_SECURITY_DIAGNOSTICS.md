# Salus Build 53: evidence-based BLE diagnostics (not a notification fix)

The old Watch Settings logging did not capture Bluetooth bond status,
active encryption state, Android pairing errors, or GATT error codes. It showed
Garmin GFDI success but did not establish that a notification was displayed.

This overlay introduces **SalusBluetoothDiagnostics.kt** as a reusable,
protocol-independent Android diagnostic service. It is wired into the
existing Garmin GFDI driver and its per-device `SalusWatchTransportStatus`.

## Evidence in Watch Settings

- **Android bond:** Reported directly from `BluetoothDevice.bondState`. Bonded
  means keys were stored, **not** that the current session is encrypted.
- **Active BLE encryption:** Android 16.1/API 36.1+ `getEncryptionStatus(LE)`
  queried at refresh by reflection, with algorithm and key size. Reflection
  prevents compilation dependencies on a newer Android SDK. A null means
  **not encrypted OR not connected**; the app does not claim to distinguish.
- **Last BLE encryption event:** On Android 16/API 36+, record
  `ACTION_ENCRYPTION_CHANGE` for the matching device and LE transport:
  enabled, algorithm, key-size, controller status. Event can be absent if the
  app starts listening after encryption begins. Never infer from absence.
- **BLE key missing:** Record `ACTION_KEY_MISSING` when reported on Android 16+.
- **Raw GATT failures:** Show status 5 (authentication required), 8
  (authorization required), 15 (encryption required), 133 (generic GATT error),
  and other numeric failures. Status 0 means the **GATT operation** succeeded,
  not proof that the device showed an alert.
- **Protocol evidence:** Record confirmed Garmin Multi-Link V2 GFDI service,
  handle registration, 5036 subscription, 5034 content request and 5035 ACK.

## Test procedure

1. Install Build 53 over Build 52, preserving saved data and signing identity.
2. Keep the watch close, open Watch Settings, select the saved Garmin.
3. Tap Send Test Notification once, wait for completion, then Refresh.
4. Read **Bluetooth security and protocol** separately from **Bluetooth transport**.
5. Do not assume that ACK or encryption equals display. If the BLE link is
   encrypted and protocol acknowledgments succeed but nothing is displayed,
   record a single opt-in Android HCI snoop trace for side-by-side analysis
   with a known working Garmin client. Do not publish raw traces: they may
   include personal notification content and security-related metadata.

This work does not yet add Android CompanionDeviceManager, proprietary Garmin
cloud sync, or universal notification senders for every wearable family.
It adds an accurate **common evidence layer** that those drivers can reuse.
