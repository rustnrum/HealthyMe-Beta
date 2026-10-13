# Salus Build 80 — agreed visual refinements

- Full-viewport alpine background is behind the entire scrollable Home dashboard instead of clipped into a hero card. Dark and light overlay strengths differ for legibility.
- Recovery ring is wider with less dominant center type. Four overview tiles have 82 px progress rings instead of 68 px rings, and smaller type. All fractions still represent available real goals only.
- Resting heart rate has its own axis-aware trend painter. It displays the original recorded bpm samples, with ticks, padding and evenly spaced observed data points; it does **not** interpolate fabricated readings.
- Cross-device **Salus Energy** is always the primary Energy metric; genuine Garmin Body Battery handling remains available in device-specific sources but is not used or relabeled as Salus Energy.
- The Salus launcher name and display title were already Salus. We deliberately retain the internal `healthy_me` package import namespace, Android application ID `com.rustnrum.healthyme.beta03`, saved keys and signing identity so Build 80 installs over Build 79 without deleting the user's data. No consumer-facing Healthy Me branding is introduced.
- All existing module selection, nested tabs, foods, fitness data, Recovery, backups, voice and source providers remain intact.
- Build workflow compiles a permanently signed debug APK, not a production release APK.
