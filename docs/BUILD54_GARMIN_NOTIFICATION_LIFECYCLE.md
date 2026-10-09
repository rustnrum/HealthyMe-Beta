# Salus Build 54 — Garmin notification lifecycle and MLR

## Goal
Fix concrete defects found when comparing Build 53 to newer Gadgetbridge Garmin code.
This beta is not declared to show notifications until verified on the vivoactive 6.

## Changes
- Request Garmin Multi-Link Reliable at GFDI registration, inspect actual
  returned reliability byte, use stateful MLR only when negotiated; retry normal
  Multi-Link on explicit reliable-registration refusal.
- Implement real 2-byte MLR headers, cumulative 6-bit sequence/ACKs, delayed
  ACKs, duplicate suppression, fragmentation, retransmit backoff and teardown.
- Perform guarded first-time Garmin PAIR_COMPLETE, SYNC_COMPLETE and
  SETUP_WIZARD_COMPLETE system events after info and configuration exchanges.
  Do not transmit those events on every re-connect after acknowledgment.
- Support Garmin 5034 `GET_APP_ATTRIBUTES` (command 1), application-name
  metadata response, and short-term notification ID retention.
- Record Garmin response status to the 5033 notification update, along with
  system-event status codes, instead of logging only the final 5035 data ACK.
- Keep established bond, AES-encrypted BLE link, 5036 subscription handling,
  5034 notification attributes, 5035 transfer ACK handling, local app data,
  UI/branding and permanent signing workflow unchanged.

## Build and verification
The supplied archive is a **source overlay**, NOT an APK.
Existing `.github/workflows/UPDATE-v0.9-source-discovery.yml` expands it,
executes the guarded Build-53 to Build-54 migration before compilation,
then runs Flutter analyze/test, Android debug build, permanent APK re-sign and
certificate verification before uploading the resulting artifact.

A local standalone Kotlin MLR test checked framing, fragmentation, duplicate
suppression, delayed ACK, retransmission and close behavior. It does not test
physical Garmin watch behavior or Android background notification display.
New Flutter source-contract tests must pass during GitHub Actions.

## References and license
Gadgetbridge is AGPL-3.0-or-later:
https://codeberg.org/Freeyourgadget/Gadgetbridge
https://github.com/darkydtm/Gadgetbridge/tree/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/garmin
Garmin source classes consulted: CommunicatorV2, MlrCommunicator,
GarminSupport, NotificationsHandler, NotificationControlMessage,
NotificationUpdateMessage, NotificationDataStatusMessage, SystemEventMessage.
Preserve copyright notices and assess AGPL source-distribution obligations
before distributing a derivative app.

## Physical test protocol
After the GitHub signed APK is built: upgrade without uninstalling, keep all
existing permissions/pairing, open Salus Watch settings, send a single Salus
notification, then inspect event history for reliability selection,
first-time application setup ACKs, 5033 update response and 5035 transfer ACK.
The watch's actual screen and Notification Center remain the display truth.
