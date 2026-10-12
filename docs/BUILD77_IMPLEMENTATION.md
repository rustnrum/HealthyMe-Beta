# Salus Build 77 — Visual dashboard replacement

Actual Flutter source, not a concept poster.

## Replaced overview screens
- Home: photographed athlete hero, colorful metric tiles, source-aware recovery gauge, real data insights.
- Nutrition: Day/Week/Month filters; nutrient-energy donut; calorie/protein/carbs/fat/fiber metric grid; actual planned-vs-eaten 7-bar/6-period chart; meal rows with images **only where a logged source provides one**; editable goals; explicit missing nutrient handling; new food-themed photo banner cropped from the user's approved AI design reference.
- Training: photographed hero, completed/scheduled workout chart, real exercise-category workload and anatomical reference illustration, upcoming schedule, original Today/Schedule/Templates/History screens retained.
- Health: recovery gauge from existing RecoveryService, sleep-stage chart from source, HR/HRV/oxygen/breathing real metrics, HRV trend from saved records, contributing factors from RecoveryService; temperature route uses Health Intelligence rather than inventing measured temperature.

## Invariants
- Current module menu remains Main / Workout / Diet / Health.
- Home original bottom tabs Home / Activity / Sleep / Body / More; Diet Today / Discover / Meals / Calendar / Grocery; Health Health / Vitals / Labs; Training Overview + Today / Schedule / Templates / History.
- Build 76 Dark, Light, and Follow System appearance persists in premium overview screens; older details retain their existing legacy styling pending a separate migration.
- No mountain image; no demo physiological values; no fabricated hydration, workout tonnage, body battery, temperature or meal logs.
- Never uninstall or clear existing signed beta; storage keys, app ID, signing pipeline and providers are unchanged.

## Validation status
Local checks: ZIP structure and integrity, Python patch syntax and idempotence, shell syntax, GitHub source-anchor counts, balanced Dart delimiters.
GitHub-required checks: Flutter analyze, automated tests, APK compilation, signing, actual Fold7 layout and accessibility.
