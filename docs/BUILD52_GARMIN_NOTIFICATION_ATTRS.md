# Salus Build 52 — Garmin notification attribute encoding

Build 51 (v0.21.13+51) received a Garmin 5036 subscription, 5034 content
request, and successful 5000/5035 data transfer acknowledgment, but the
notification did **not** appear on the vívoactive 6. The transfer ACK verifies
acceptance of a fragment, not watch UI rendering.

Compared Salus with Gadgetbridge `NotificationsHandler.java`, `getNotificationDataMessage`,
`NotificationAttribute.getNotificationSpecAttribute` and the `ACTIONS` encoder
(AGPL-3.0):

- Gadgetbridge deliberately serializes `MESSAGE_SIZE` last even if Garmin requests it first.
  Salus previously preserved request order. Build 52 writes it last.
- For an alert with no actions, Gadgetbridge writes four NUL bytes. Salus wrote
  an empty attribute. Build 52 writes the exact four-byte sentinel.
- The parser now handles requested UTF-8 byte limits and avoids silently inventing
  values for unknown/malformed attribute types; Garmin attribute IDs are recorded
  without recording private message text.
- No changes to Android package ID, signing key, bond state or saved app data.

The resulting GFDI 5035 data still requires the Garmin per-chunk ACK and final
status already implemented in Build 51.

**Not a confirmed display fix**. To confirm, install the signed APK and test
on the physical Garmin. Even if the watch accepts the transfer, a separate
watch UI notification preference/firmware behavior can suppress display.

Protocol reference: https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/garmin/NotificationsHandler.java
Gadgetbridge source is AGPL-3.0; keep appropriate license obligations and attribution.
