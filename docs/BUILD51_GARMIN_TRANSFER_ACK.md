# Build 51 — Garmin notification data acknowledgement fix

Evidence: Build 50 logs reached `Watch requested content` then prematurely reported `Notification content sent`; on-screen delivery was absent.

This update follows Gadgetbridge `NotificationsHandler.Upload.processUploadProgress()`: each GFDI `5035` notification-data chunk waits for a Garmin `5000` status response identifying `5035`. The last successful chunk response triggers a final `5035` ACK status sent to Garmin. A written GATT packet is NOT proof that the watch accepted or displayed the notification.

New Kotlin-only transfer state (`SalusGarminNotificationTransfer.kt`) separates chunk sequencing, cumulative CRC, accepted/rejected chunks, and completion. The sender reports `Notification data awaiting Garmin ACK`, `Garmin accepted notification data`, `Garmin rejected notification data`, or `Garmin notification ACK timeout`. Upon successful last ACK, Salus transmits the final `notificationDataAck` status (type 5000, in response to type 5035), like Gadgetbridge.

Existing Android BLE bonding, application ID `com.rustnrum.healthyme.beta03`, signing workflow, auto discovery, and other modules are unchanged.

Code tests: `test/garmin_notification_transfer_check.kt`, `test/build51_garmin_notification_transfer_contract_test.dart`.

**Unverified:** The update has not been built as an Android APK or validated on a physical Garmin; notification rendering is not confirmed by transport acknowledgment. Gadgetbridge source is available under AGPL-3.0; derived implementations need to comply with that license.
