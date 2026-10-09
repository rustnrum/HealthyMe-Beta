# Salus Garmin standalone driver pairing and handshake research

Pairing: Android BluetoothDevice.createBond() is asynchronous. SalusSafeBondManager listens for ACTION_BOND_STATE_CHANGED, filters by BluetoothDevice.address, confirms BOND_BONDED, handles denial and timeout, and cancels its receiver. BLUETOOTH_CONNECT is required on Android 12+.

**Do not force a new bond for already bonded devices.** No custom AES implementation is appropriate for the BLE link.

GATT: The Garmin vívoactive 6's discovered Multi-Link V2 service 6A4E2800 uses phone-as-GATT-client communication. Do NOT replace it with phone-as-GATT-server ANS (1811), which would have the wrong Bluetooth roles for this known Garmin path.

GFDI initialization: Reading the BLE battery and registering service handle 1 aren't enough to establish Garmin notification delivery. Gadgetbridge's GarminSupport and DeviceInformationMessage/ConfigurationMessage show further binary exchanges, acknowledgments, time and capability negotiation. The Build 47 screenshot shows stalled watch subscription after GFDI registration; bonding alone may not fix it.

Source references:
- https://developer.android.com/reference/android/bluetooth/BluetoothDevice#createBond()
- https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/garmin/GarminSupport.java
- https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/garmin/communicator/v2/CommunicatorV2.java
- https://gadgetbridge.org/gadgets/wearables/garmin-watches/

Code derived from Gadgetbridge protocol behavior requires AGPL-3.0 compliance review before distribution; preserve upstream notices where code is ported. Platform tests cannot confirm watch delivery. Don't report watch delivery unless watch initiates notification attribute retrieval and on-device display is verified.

## Build 48 implementation scope

- Only explicit enablement of watch notifications or a direct test can request an Android bond. Passive listener restart does not display system pairing UI.
- User-device matching ensures that bonding another Bluetooth headset does not authorize the watch.
- GFDI 5024 (device information), 5050 (configuration), 5052 (time request) and 5101 (auth negotiation) now have message handlers modeled on public Gadgetbridge protocol behavior. A 5030 SYNC_READY event follows configuration. This was **not** implemented in Build 47.
- Only GNCS, SMS_NOTIFICATIONS, CURRENT_TIME_REQUEST_SUPPORT and MULTI_LINK_SERVICE capability flags are advertised. These are a conservative experimental subset and **have not been validated on a physical vívoactive 6**.
- A 22-second diagnostic timeout reports if the watch never subscribes via GFDI 5036; queued notifications are not mislabeled as delivered.
- The Android BLE link bond can be necessary but does not replace Garmin GFDI protocol negotiation. Salus still cannot guarantee all device functions, all Garmin variants, or every brand listed in the registry.
- Native code compiled with local Kotlin Android API stubs, which catches Kotlin source errors but **is not equivalent to a real Android SDK or runtime test**. Packet framing/CRC self-tests also passed. GitHub CI is required for full Flutter/Android compilation, signing and installation.
