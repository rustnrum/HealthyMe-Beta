# Salus Build 56: Garmin session recovery and third-party notifications

## Trigger: real Garmin logs, October 10, 2026

Build 55 directly displayed a Salus test notification on a Garmin vívoactive 6.
Subsequently, an email was not displayed; the watch logs showed a second GFDI
registration on the same handle (135), followed by out-of-window MLR ACKs with
Garmin seq=21 while Salus nextSend=0. The later notification received no 5034
attribute request. These traces indicate MLR state reset and/or a stale session,
not proof that Gmail specifically failed to reach the Android listener.

## Correction

- Treat duplicate GFDI register responses for the current handle/reliability
  as duplicates. Preserve live MLR send and receive windows and subscriptions.
- When Garmin truly changes handle or reliability, invalidate old transport,
  requeue current notification, reset startup/subscription negotiation and
  require fresh 5036 approval. Never reuse stale watch subscription state.
- After one notification gets no Garmin 5034 within nine seconds, restart the
  BLE session and replay the alert once; never endlessly retry it.
- Show the difference between Gmail delivered to Android's notification
  listener, app/account filtered, and actually queued for Garmin. Only package
  names, coarse decisions and no content/account identity appear in diagnostics.
- Existing Build 55 wire payload and attributes unchanged. Preserve app ID,
  signing, settings, data, connection/source choices, and other modules.

## Validation

- `kotlinc native/android/SalusGarminRegistrationPolicy.kt test/garmin_build56_registration_check.kt -include-runtime -d /tmp/...jar`
- `java -jar /tmp/...jar`
- `flutter analyze` and `flutter test` via GitHub Actions.
- `flutter build apk --debug`, permanent key re-sign and certificate verify via
  existing GitHub Actions workflow.
- Physical-watch test is still required; a passing build is not proof of
  third-party Gmail/SMS delivery.

## Important deployment note

The repo has already committed Build 55's source fixes. The source overlay
installs `patch_build56.py` and its invocation in `prepare_android.sh`; the
previous `patch_build55.py` invocation is removed so subsequent builds with
version 0.21.18+56 do not attempt a downgrade. No userdata is deleted.
