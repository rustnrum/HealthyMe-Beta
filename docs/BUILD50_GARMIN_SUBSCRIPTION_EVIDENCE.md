# Salus Build 50 — Garmin 5036 response and diagnostics

## Confirmed evidence from Build 49 watch log

- Android notification access and the phone's Salus opt-in are enabled.
- Garmin Multi-Link and GFDI were registered; device information and
  configuration exchanges were acknowledged.
- At 10:30:32, the watch sent GFDI 5036 with the **requested state off**.
- The later "5036 not yet received" line came from Salus's 22-second
  diagnostic timer. That line was false because the watch *had* sent 5036.
- No Bluetooth disconnection or 30-second heartbeat failure is confirmed by
  that log. There is no basis for inventing a 2-byte ML ACK or 12-second ping.

## Source-based correction

Gadgetbridge's `NotificationSubscriptionMessage` parses a Garmin-initiated
subscription request; its device-event handler passes the **watch request**
separately from the **phone's user preference** to
`NotificationSubscriptionStatusMessage`. The wire fields are: response-to
5036, ACK, phone permission (ENABLED/DISABLED), watch-request boolean,
reserved zero. The sequence number must echo the request if present.

Reference:
- https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/garmin/GarminSupport.java
- https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/garmin/messages/status/NotificationSubscriptionStatusMessage.java
- https://github.com/Freeyourgadget/Gadgetbridge/blob/master/app/src/main/java/nodomain/freeyourgadget/gadgetbridge/service/devices/garmin/communicator/v2/CommunicatorV2.java

Salus now returns phone permission based on the actual master toggle, echoes
Garmin's requested on/off bit, and retains the Garmin subscription state
separately. It only drains alerts if the watch requests on and the host is
allowed. It records that a 5036 message was seen even if the request is off,
fixes the misleading timeout, and shows the official on-watch setting path.

Garmin vívoactive 6 manual: Settings → Connectivity → Phone → Notifications →
Status → On.
https://www8.garmin.com/manuals/webhelp/GUID-8C2C402F-55AC-431F-9CF2-1442B89CE149/EN-US/vivoactive_6_OM_EN-US.pdf

This patch does not claim the watch is already subscribed. The real device
must request notifications on. No manufacturer companion application or
additional speculative protocol frames were introduced.

Tests:
```
kotlinc native/android/SalusGarminGfdiCodec.kt test/garmin_sequenced_gfdi_check.kt -include-runtime -d /tmp/salus50-check.jar
java -jar /tmp/salus50-check.jar
```

GitHub Actions will perform Flutter analysis, Flutter tests, build and
re-sign verification after the update ZIP is uploaded.
