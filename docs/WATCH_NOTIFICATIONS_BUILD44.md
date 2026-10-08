# Salus Build 44 — watch notification bridge

This changes only notification forwarding, watch settings and required Android permission. Salus app ID, permanent signing key, Health Connect routing, health metrics, device records, and recovery data are unchanged.

## Route selection

- IDO/VeryFit: pre-existing packet sender over supported device GATT. The listener sends only through the installed direct sender. BLE writes are not an acknowledgement from the watch.
- Garmin and other devices managed by a companion app: Salus does not invent a proprietary BLE alert endpoint. The opt-in listener reposts selected source notifications into the `Watch companion relay` **Android notification channel**. The device's independent companion app must be connected, allowed to access Android notifications, and set to mirror **Salus** alerts. Watch delivery cannot be detected/guaranteed by Salus.
- A device that has no companion app and no native outbound driver cannot receive direct watch alerts, even if discovery can read its battery or health metrics.

## User check after installing

1. Open Salus > Device batteries > watch > Watch settings.
2. Enable Android notification listener access if requested.
3. Turn on `Phone notifications on this watch`; for companion mode accept Android's Salus notification permission prompt.
4. Enable **Salus** under Garmin Connect (or the corresponding companion app) app notification choices. The watch must be connected in its companion app.
5. Enable Text messages or another desired app under Salus watch settings.
6. Send a genuine incoming message from another phone, unlock the phone, and inspect `Last notification seen` and `Last allowed for forwarding` in Salus.
7. Verify an alert shows in the phone's notification shade from **Salus**. Then check the watch. If the Salus phone alert exists but the watch never receives it, the companion app mirroring layer is the blocker, not an undiscovered standard GATT notification writer.

## Safety and honesty

- Master is off until the user enables it; previously saved app filters are preserved.
- Own-package alerts, group summaries, and most persistent notifications are excluded. Original phone alerts are never canceled or deleted.
- Only one companion relay notification is posted per original alert, even with multiple opted-in watches; updates replace their prior notification with the same original ID. The Android relay expires after 30 seconds to avoid clutter.
- Gmail account filter remains opt-in. Message text is passed through Android notification APIs without persistent content storage; it may still be visible on the phone/watch while unlocked.
- Users may get duplicates if their companion already mirrors original apps; turn off Salus relay for that app if so.
- A successful CI build cannot verify delivery to Garmin/other hardware. Physical end-to-end tests are required.
