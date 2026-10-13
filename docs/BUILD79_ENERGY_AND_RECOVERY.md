# Salus Build 79 — mountain hero, Recovery transparency, experimental Energy

## Design
Restores cinematic mountain photography to Home greeting/hero using `assets/premium/salus_mountain_79.webp`. Original Main / Workout / Diet / Health module menu and internal tabs remain unchanged. Uses bright cyan, mint and purple rather than muted accents. Supports existing Dark, Light and Follow System preferences.

## Recovery
Original objective safety rule remains: a sleep record alone gives no 0–100 Recovery number. With three actual daily resting-heart-rate points (two for an early baseline plus current) and recent sleep, a **Preliminary** score may appear at 45% signal coverage rather than being blank. Scores with three RHR points are deliberately given only 10 points of coverage versus 15 for longer histories. Provisional numeric scores shrink toward neutral when objective coverage is low, preventing a single great sleep reading from yielding a misleading 98/100. HRV, RHR, breathing, daily state and training-load contributors remain source-based. Actual Body Battery is *not* fed back into Recovery, avoiding counting sleep/HRV twice.

## Salus Energy
A separate **experimental, provisional daily energy estimate**, not Garmin's trademarked/proprietary Body Battery nor a clinical metric. It uses selected source health records regardless of watch brand: recent sleep + personal RHR baseline or HRV baseline (required), with movement as an optional adjustment. No synthetic readings. Insufficient input gives `—` and a list of missing signals. Current integration cannot reproduce minute-by-minute charging/discharging without real intraday HRV/stress/activity timestamps. Estimates shrink toward neutral while the personal baseline grows over the first 14 days. User-specific validation is a future task, not a claim of current accuracy.

A genuine BLE `Body battery` sample is displayed as a *device reading* if measured within 12 hours. Its source is labeled. Device data is never mislabeled as an estimate, and estimated Salus Energy is never shown as genuine Garmin Body Battery.

## Source and continuity
No package ID change, no signing key change, no migrations or resets. Does not modify dietary log, Garmin protocol, CPAP, skin temperature, or backup data. All previous modules and navigation preserved.

## Remaining tests
GitHub must pass Flutter analysis, unit/widget tests and signed Android debug APK compilation. On Fold7, visually verify no hero layout overflows and that Recovery remains truthful with the actual available signals.
