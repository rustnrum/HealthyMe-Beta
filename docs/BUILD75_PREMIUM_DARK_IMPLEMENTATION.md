# Salus Build 75 — approved premium dark implementation

Baseline: successful Build 74 (v0.21.36+74). Target v0.21.37+75.

## Visual implementation

- Premium dark mode defaults for previously built premium panels, with local light-mode toggle preserved. A new preference key deliberately defaults to the approved dark design rather than inheriting the previous light-first experiment.
- Shared color system in `lib/widgets/salus_premium_visuals.dart`: rich navy surfaces, cyan active states, green activity/recovery, orange nutrition, blue training, purple sleep/HRV, rose heart-rate cues. Rounded glass cards, subdued borders, date strip, night-photo hero, visual gauges, macro ring, progress bars and recorded-history sparklines.
- Home uses existing app profile, available steps, actual logged nutrition, completed workouts, last recorded sleep, existing RecoveryService, and HomeInsightService; no sample data.
- Nutrition retains actual journal, saved recipe assignment integration, missing-nutrient handling, goal editing, daily planned-versus-eaten data, and recipe search. Adds multicolor macro ring and brightly colored actual macro tiles; the bowl artwork is explicitly labeled illustration, never a logged meal.
- Training retains real scheduled and completed sessions and set distribution. Adds training photography, timeline and anatomical *reference* illustration. The anatomical colors are **not** patient-specific muscle activation or growth; muscle workload bars remain driven by logged exercise sets.
- Health introduces a dark overview with only verified provider vitals, last recorded sleep with real stages when available, RecoveryService score with confidence, HR/HRV history, SpO2, respiratory rate, and prominent links to Health Intelligence/temperature, Garmin Body Battery, labs and encrypted backup. No invented temperature reading or proxy Body Battery.
- Health and Training overview routes get the same core 5-destination navigation, while detailed screens and workflow actions remain accessible.
- No app-wide `MaterialApp.builder` Stack; Build 74's red-overlay fix is preserved. Local voice launchers remain.

## Authored supporting assets

`assets/premium/salus_night_mountains.jpg`: custom original night-mountain digital art.
`assets/premium/training_hero.jpg`: content-only athlete photograph crop from the user's previously generated Salus marketing artwork, with dark overlay suitable for text.
`assets/premium/muscle_reference.jpg`: cropped front/back anatomical reference from a user-approved generated Salus concept; this is generic reference art and never shown as personalized data.
`assets/premium/meal_illustration.jpg`: original food illustration; appears only as a discover-browse promotion, never as a user food-entry photo.

No branded external sports or health company images are embedded, no font files are packaged, and no sample measurement records are created.

## Preservation rules

No changes to `lib/services/` providers, direct BLE, Health Connect, ring temperature, Garmin, recovery scoring, encryption/backup, signing configuration, app ID, saved model schemas, or stored user data.

## Validation

ZIP structure/CRC, Python script compile, shell syntax, static source anchors and authored-Dart bracket checks are local pre-upload checks. **Flutter analyzer, widget tests, Android compilation, APK signing and real-device rendering must pass GitHub before this build is installable.**
