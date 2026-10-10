# Build 55 — Garmin real-watch diagnostics from Build 54 screenshot

Observed on Garmin vívoactive 6 / Build 54 2026-10-09:
- Non-MLR session: watch received and acknowledged 5035 text, then repeated 5034 attr requests. Salus rejected them as malformed/unknown.
- MLR session: registration requested=2, negotiated=1, handle=130. Inbound packets were repeatedly rejected as `invalid cumulative ACK`, and Garmin never requested notification attributes.

Code verification against Gadgetbridge:
- Gadgetbridge `NotificationAttribute.NEGATIVE_ACTION_LABEL(7)` has **no** length parameter. Salus Build 54 mistakenly consumed two request bytes after selector 7. Build 55 parses it correctly. This is a verified parser defect; the real request selector hasn't yet been captured.
- Gadgetbridge MLR data processing does not reject inbound data solely due to an out-of-window ACK piggyback. Salus Build 54 returned early before processing the inbound payload. Build 55 ignores the invalid *ack portion* while processing an in-sequence incoming fragment and records bounded protocol-level diagnostics. It does not accept impossible ACKs as transmit success.

This is a controlled correction, **not verified watch display**.
Build preserves package ID `com.rustnrum.healthyme.beta03`, permanent signing key, settings, user data and UI. Existing Build 54 first-connect lifecycle and 5034 app attributes retained. This ZIP is source overlay only. The regular GitHub action must compile/test/re-sign and the APK must be physically tested once.

Protocol reference: https://codeberg.org/Freeyourgadget/Gadgetbridge (AGPL-3.0-or-later); see prior Salus attribution.
