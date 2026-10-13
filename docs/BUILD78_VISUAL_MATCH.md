# Salus Build 78 — approved-design implementation correction

Original approved dark and light reference boards remain the design specification; there are no newly proposed or generated concepts in this update.

- Original Main / Workout / Diet / Health module switching and each module's own tabs remain unchanged.
- Module entry is a high-contrast, explicit Modules pill on each premium overview in both modes, not a replacement navigation system.
- Home now follows the reference's recovery-led hierarchy: premium hero, large circular Recovery indicator with actual underlying readings and signal coverage, compact AI insight, four true circular progress metrics, and separate real-data HRV / resting-heart-rate line charts.
- Health contains adjacent HRV and RHR plots and real Recovery contributors. No synthetic trends or values.
- Light cards use stronger borders, shadows and accent separation; Dark retains the established navy / teal / cyan look. Dark, Light, and Follow System preference remains functional and persistent.
- All readings remain sourced from providers/food log/workout history. Missing values never become fictitious examples. No mountain images are used.
- App package ID, signing configuration, storage keys, and watch interfaces are untouched.

The GitHub workflow must verify Dart analysis, all Flutter tests, debug APK, and signing. The layout itself still needs phone screenshots to verify against the reference art.
