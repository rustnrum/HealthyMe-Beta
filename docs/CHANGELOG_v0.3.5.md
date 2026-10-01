# Healthy Me Beta v0.3.5

## Scope

This build turns the recent product decisions into the next working beta without pretending unsupported data exists.

## Fitness / body

- Removed the non-functional sun icon from the Home app bar. Healthy Me remains dark-only in this beta.
- Added app-resume Health Connect refresh so returning from a source app causes Healthy Me to reread available Health Connect data.
- Renamed sync language in the source UI to **Refresh data**. Refresh rereads Health Connect; it does not claim to force a watch or vendor app to sync.
- BMI is now a local **Calculated** value using current weight and profile height.
- Body fat remains a **Measured** Health Connect value only; it is not manually entered or confused with BMI.
- Rebuilt the body-measurement editor as a state-owned dialog so its text controllers are disposed with the dialog lifecycle. Added a regression widget test for opening/closing the measurement editor.

## Data sources

- Replaced the old detected-origins + preferred-source layout with one straightforward source control per metric.
- Default is **Health Connect recommended**.
- **Change** shows only sources that actually supplied that metric.
- Source choices remain dynamic and device-neutral; the health engine does not assume Garmin, Samsung, Fitbit, Apple, or another vendor.
- Raw Android package IDs are never intentionally shown in the source UI. Known apps get friendly names; unknown package-style origins are reduced to a readable app/vendor label.
- Activity now labels the default step source as **Health Connect recommended** instead of `Health Connect • Auto`.
- Metric-specific source availability is retained in the Health snapshot.

## Diet module

Diet navigation is now locked to four primary destinations:

- **Today** — future daily food logging, calories/macros/nutrients and Add Food flow.
- **Meals** — future saved meals, recipes, favorites, recent and frequent foods.
- **Plan** — future weekly meals and planned nutrition targets.
- **Grocery** — future consolidated shopping list from the meal plan.

The module remains a shell where real nutrition data does not exist yet. It does not invent calories, macros or food history.

## Health module

Added a separate **Health** section alongside Fitness and Diet.

- **Health** — overview using existing connected vitals and stored bloodwork.
- **Vitals** — resting HR, HRV, blood oxygen, respiratory rate and latest HR when already available through Health Connect.
- **Labs** — structured bloodwork entry.

No unsupported medication, glucose, blood-pressure or health-record features are faked into this build.

## Bloodwork

- Removed the CSV/XLSX button from the primary workflow.
- Added pre-populated common bloodwork groups users can fill in only when tested:
  - CBC
  - CMP / Metabolic
  - Lipids
  - Glucose control
  - Thyroid
  - Iron & nutrients
  - sex-appropriate Hormones
  - Advanced
- Common markers include WBC/RBC/hemoglobin/hematocrit/platelets, glucose/BUN/creatinine/eGFR/electrolytes/liver markers, lipids/ApoB/Lp(a), HbA1c, thyroid, ferritin/iron/B12/folate/vitamin D/magnesium, hormones, hs-CRP/cortisol/CK.
- Healthy Me continues to store raw result, unit, collection date and lab source without automatically diagnosing or labeling high/low.

## Module navigation

The app-section selector now exposes exactly:

- Fitness
- Diet
- Health

Unsupported future modules are not added just to fill navigation.
