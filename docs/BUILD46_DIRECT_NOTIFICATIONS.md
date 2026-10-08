# Salus Build 46 - automatic driver matching and direct notification transport

## Scope

* Salus automatically scans when Auto discovery opens; it probes GATT services and matches the local protocol registry. Pairing remains user-initiated.
* The local registry now includes 22 additional wearable discovery families. They are **recognition signatures**, NOT 22 functional notification drivers. Standard Bluetooth heart rate and battery readers and the existing direct ring/CPAP implementations remain unchanged.
* Salus's independent Android listener dispatches eligible alerts via the installed IDO/VeryFit sender or the new Garmin Multi-Link GFDI sender. No vendor companion app or relayed Android notification is involved.
* Garmin direct sender handles ML registration, COBS and Garmin CRC, GFDI notification updates and subscription responses, notification attribute requests and data chunks. It is **experimental** and needs a physical watch test. A successful GATT write is not a watch-delivery acknowledgement.
* A simple opt-in notifications switch is available on Watch settings, and saved watches link there from Auto discovery. Existing app/account filters are retained. Previously disabled Build 44 companion-relay master setting is not auto-enabled.
* Other third-party implementations (Huami, Huawei, Bangle.js, Pebble, FitPro, etc.) remain reference material and are NOT native Salus notification senders. Do not enable their switches or assert support until the native protocol is integrated.

## Protocol references, attribution, and licensing

Garmin GFDI/ML wire behavior and capability recognition informed by:
https://github.com/Freeyourgadget/Gadgetbridge/tree/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/garmin

Specific classes: CommunicatorV2, CobsCoDec, ChecksumCalculator, NotificationUpdateMessage, NotificationsHandler, and the notification-control/status messages. Gadgetbridge is licensed AGPL-3.0-or-later. The publication/distribution and source-availability obligations of that license must be evaluated before distributing a derivative. This implementation is new Salus Kotlin source adapted from published wire behavior and may fall under those obligations. Do not hide or strip credit.

## Verification and limitations

* Local Kotlin codec tests should exercise framing/deframing, GFDI checksum validation, ML registration packets, and notification update serialization.
* Flutter `analyze`, `test`, APK build and signing **must run in GitHub Actions**. They are not a substitute for an Android BLE physical-device test.
* Most watches use authentication/proprietary protocols. Auto discovery cannot infer keys or magically enable unsupported notification writers; supported family names do not imply functionality.
* The Garmin sender currently initiates a bounded BLE session for each eligible alert and returns without an end-to-end delivery acknowledgement. Persistent connection/reconnect arbitration, notification test injection and device-specific firmware quirks are outstanding for production reliability. The UI must report an experimental sender, not guaranteed delivery.
