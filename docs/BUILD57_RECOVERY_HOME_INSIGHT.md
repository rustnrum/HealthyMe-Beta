SALUS BUILD 57 — HOME INSIGHTS, RECOVERY CLARITY AND SYNC FEEDBACK

Base: v0.21.18+56. Keeps Build 55/56 Garmin MLR and notification code unchanged.
Android application ID, signing certificate, saved data, source routes preserved.

Changes:
- One small evidence-based insight beneath Recovery, not another metrics dashboard.
- Uses explicit freshness metadata within the prior rolling 24 hours.
- Provenance/source shown; stale/unattributed data not passed off as fresh.
- Can prioritize today's voluntary subjective check-in when stress is high,
  sleep shorter than configured age guidance, lower personal HRV, elevated RHR.
- No clinical diagnoses, no medication advice or fabricated missing values.
- Recovery service exposes a preliminary labelled numeric estimate if at least
  two independent measured contributors exist but coverage below 50%.
  Confidence stays low; one sleep-only signal still yields no number.
- Blank Recovery now displays the percent of real signal coverage and a path
  to contributor details. Full recovery score still follows existing threshold.
- Main-page Sync icon truly rotates only while the sync provider is loading,
  and last successful import/error is labelled separately.
- Existing tests plus new evidence, freshness, and preview tests.

Important limitations:
- 'Last 24 hours' refers to individual input record timestamps, not a
  synthetic 24-hour aggregate.
- Direct Garmin FIT historical sync is not implemented in this update.
- Automated tests / GitHub build must pass before APK is called verified.
- Recovery values are nonclinical heuristics; don't infer diagnosis or fitness.
