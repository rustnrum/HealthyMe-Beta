# Permanent Beta Update Channel

Current CI APKs are debug signed. A GitHub-hosted runner may create a different debug certificate, which can force Android to uninstall before installing a later APK.

The permanent beta channel must use:

- Stable package ID: `com.rustnrum.healthyme.beta03`
- Increasing version code: +8, +9, +10, ...
- One permanent release keystore kept out of the repository
- GitHub Secrets: `KEYSTORE_BASE64`, `RELEASE_KEYSTORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD`
- `flutter build apk --release` after release signing is configured

There may be one final uninstall when moving from the existing debug certificate to the permanent beta certificate. After that transition, new APKs signed by the same certificate and carrying a higher version code install as normal updates and retain app data.
