# Salus Build 71 / 0.21.33+71

## Adds
- Direct COLMI 0xBC / 0x25 **read-only** skin-temperature history request, 30-minute slot decoder and historical timestamps. Temperature absent or unsupported remains missing. Firmware validation is pending actual hardware confirmation.
- Health Connect SKIN_TEMPERATURE / BODY_TEMPERATURE import, separately permissioned and provider-attributed. Delta-only records are never passed off as absolute temperatures.
- Health Intelligence screen under Health. Latest skin/body temperature, sources, trend requiring four separate days from one source, recent readings, and source sync/import actions. Medical/longevity risk scores not yet claimed.
- Backup & Restore under Health. Password-derived AES-256-GCM encrypted backup to user-selected SAF file outside app storage; manual restore after reinstall. Exports current state via SharedPreferencesAsync and separate classic SharedPreferences histories. No account credentials; backup password not stored.
- Direct metric retention expanded to 365 days / 24k samples; historical Health Connect records retained separately where imported. Existing storage keys, schema, package ID and signing key not changed.

## Limits and checks
- Android device must supply valid 0x25 packets. No claims about core temperature, fever, or disease detection.
- On Android, selected Documents/Drive folder backups survive uninstall, but a file inside app-private storage does not. Backups are manual, not scheduled in Build 71.
- External Health Connect original database, file-based photos and account credentials are not in the backup; reauthorization and independent copies required.
- New APK updates in place: **do not uninstall Build 70**.
- CI must pass analysis, tests, APK build, signature verification and upload before providing APK.
- On-device testing: confirm BLE temp on RT02CR_V3.1, import permission/error, backup/restore to a test device or safe sandbox. No uninstallation tests on only copy of data.
