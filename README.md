# Healthy Me Beta v0.3.5

Healthy Me is a personal body command center built around connected health telemetry, personal baselines, freshness, trends and plain-language wellness suggestions.

## v0.3.5 focus

- Fitness, Diet and Health as the three current top-level sections
- Diet navigation locked to **Today • Meals • Plan • Grocery** without fake nutrition data
- New Health section using data Healthy Me already has: connected vitals + structured bloodwork
- Common bloodwork markers pre-populated for easy manual entry; CSV/XLSX is no longer the primary workflow
- One clear source-selection flow per metric with human-readable app names only
- **Health Connect recommended** as the neutral default rather than assuming a device vendor
- Refresh wording made honest: Healthy Me rereads Health Connect but does not claim to force source apps to sync
- Automatic Health Connect reread when the app resumes
- BMI calculated locally from height + current weight and labeled **Calculated**
- Body fat remains a connected measured value
- Body-measurement dialog lifecycle rebuilt to address the framework crash seen during measurement entry
- Non-functional sun icon removed; the current beta remains dark-only

## Update-channel direction

The beta keeps the stable package ID `com.rustnrum.healthyme.beta03` and increasing version codes. The permanent in-place update channel will switch to one stable release signing key stored only in GitHub Secrets. That transition may require one final uninstall from the current debug-signed beta; after it, later APKs signed by the same key can install as normal updates and preserve app data.

## Data principles

- Health Connect is the Android aggregation layer.
- Vendor names are presentation/source attribution, not hard-coded health-engine rules.
- BMI is calculated locally from data Healthy Me already has.
- Body fat is connected-source only; it is not manually entered.
- Bloodwork stores raw values, units, dates and sources without automatic high/low diagnosis.
- Sleep targets are derived from age/profile.
- Suggestions are wellness guidance, not medical diagnosis or treatment.

See `docs/HEALTHY_ME_PRODUCT_SPEC.md`, `docs/UI_ACCEPTANCE.md`, `docs/CHANGELOG_v0.3.5.md`, `docs/RECOVERY_MODEL.md` and `docs/PERMANENT_BETA_UPDATES.md`.
