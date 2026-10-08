# Build 44 acceptance checks

## CI checks (automated in GitHub Actions)
- `flutter pub get`
- `flutter analyze`
- `flutter test` including Build 44 notification routing tests
- `flutter build apk --debug`
- APK re-sign and SHA-256 certificate fingerprint check

## Physical device checks (require an Android phone and actual watch)
- Existing app installs without removing or losing any saved data.
- Existing ring/Garmin metrics and battery continue reading.
- Android 13+ grants `POST_NOTIFICATIONS` for Salus when enabling companion relay.
- Android notification-listener access is enabled.
- From Watch settings, turn on notifications and enable desired apps.
- In Garmin Connect (or equivalent companion), allow notifications **from Salus**.
- Send a real text from another phone. In watch settings, check last seen and last eligible times.
- Android status bar has the reposted Salus notification (with correct title/text).
- Verify physical-watch receipt. If absent, check companion app routing and device mode; Salus cannot force watch firmware/companion behavior.
- For IDO/VeryFit, confirm original direct BLE sender still triggers watch. Existing packet sender does not have a definitive watch acknowledgement.
- Confirm no infinite alert loops or repeated stacks of duplicate Salus phone notifications.

## Explicit non-goals
This does NOT implement Garmin's undocumented proprietary BLE notification protocol, force-enable permissions in a third-party companion app, or guarantee phone-call ringing on unsupported watches. These need vendor-specific APIs/hardware verification.
