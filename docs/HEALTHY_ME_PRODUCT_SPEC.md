# Healthy Me Product Spec

## Product principle

Healthy Me should turn a small set of useful health inputs into understandable progress and practical
wellness suggestions without feeling like a medical chart or a bloated fitness app.

## Locked design rules

- Body fat is not a required manual input. It comes from a compatible data source when available.
- Steps and other metrics are not tied to Samsung. Sources are selected per metric.
- The source picker supports Auto/Recommended plus compatible providers.
- Sleep targets are suggested from age/profile context using published guidance.
- Bloodwork stores the user's observed numerical result, unit, date, and lab source.
- Bloodwork does not show diagnostic high/low labels.
- Lab entry supports predefined markers, sex-aware markers, custom values, CSV, and XLSX.
- User-entered data is editable.
- Diet and workout output is wellness guidance, not a treatment plan.
- The UI should favor useful summaries, charts, and progressive disclosure over dense settings screens.

## v0.2 scope

v0.2 establishes the real UI, data model, persistence, charts, onboarding, lab import, body measurements,
connections model, and suggestion engine.

Native OAuth / Health Connect / vendor authorization is a later implementation layer and must never be
represented as connected before it actually is.
