# Healthy Me Product Spec — Locked Direction

## Product idea

Healthy Me is a personal body command center. It should ingest health telemetry from connected sources, normalize it, track freshness and confidence, compare it with personal baselines, detect meaningful changes, summarize body systems, and turn those signals into plain-language wellness suggestions.

Healthy Me is not a diagnosis engine and does not produce treatment plans.

## Core pipeline

Data sources → normalization → freshness/quality → personal baselines → trend/anomaly engine → body subsystem status → daily body report → suggested actions.

Every metric should conceptually carry: value, source, timestamp, freshness, confidence, baseline, trend.

## Data speeds

Fast telemetry: heart rate, resting heart rate, HRV, steps, activity, workouts, sleep, respiratory rate, blood oxygen and other supported sensor data.

Daily/weekly: weight, body fat from compatible connected scale/source, body measurements, blood pressure, progress photos and fitness performance.

Slow/inspection: bloodwork such as A1C, lipids, CBC, CMP, thyroid, testosterone/hormones, vitamin D, ferritin and other relevant wellness markers.

## Primary navigation

Home / Activity / Sleep / Body / More

The previous Today / Progress / Connect / Labs / Plan primary navigation is retired.

## Home

A Daily Body Report with one calm Body Status hero, six subsystem cards (Recovery, Sleep, Activity, Cardio, Body, Labs), What changed today, and Data freshness.

The app should surface anomalies and changes rather than asking the user to watch raw numbers all day.

## Activity

Day / Week / Month / Year views, steps vs goal, activity trend, distance, active calories, active time, workouts and weekly activity.

Provider selection is dynamic and never Samsung-only.

## Sleep

Sleep target is calculated from age/profile, not entered arbitrarily by the user. Adult 18–64 guidance is 7–9 hours; 65+ is 7–8 hours. Healthy Me may display a clearly described duration score, but must not pretend to have a proprietary recovery/readiness score it cannot calculate. The Plan experience may include a circular bedtime/wake planner with draggable handles and planned sleep duration in the center.

## Body

Weight / Measurements / Composition tabs. Body measurements use a clean grid with no human silhouette. Body fat is not manually entered; it comes from a compatible connected scale/source. Progress photos are supported.

## Bloodwork

Bloodwork stores test name, result, unit, collection date and lab/source. CSV/XLSX import and editable predefined markers are supported. Raw values are displayed without automatically labeling high/low or diagnosing disease. Marker suggestions can vary by sex/profile where appropriate.

## Sources

Health Connect is the Android aggregation layer. Healthy Me must show real detected source names and support Auto/Recommended plus per-metric overrides. Vendor names are never shown in Connected Sources unless real records identify that vendor; Health Connect itself may still be shown as the aggregation hub.

## Suggestions

Suggestions may use profile, connected metrics, labs, trends and freshness. They remain wellness suggestions and should advise clinical evaluation when a medical issue requires diagnosis or treatment.

## Nutrition direction

Nutrition should not require exact manual logging. Future modes may include simple meal checks, photo estimation with correction, repeated-meal recognition, barcode scanning, or detailed optional logging. Nutrition confidence should be explicit rather than falsely precise.

## Visual contract

The approved five-phone mockup supplied by the user is the UI target: deep navy command-center background, compact dark cards, restrained cyan/blue/mint/purple/rose/amber accents, modern spacing, readable typography, and no terminal-green/retro-computer appearance.


## Healthy Me sections / future modules

The primary app bar includes a section launcher so Healthy Me can grow into multiple coordinated modules without crowding the Fitness navigation. Fitness remains the current section with Home / Activity / Sleep / Body / More. Diet is reserved as a future section and will use its own bottom navigation: Diet / Menu / Planning / Grocery List. Future menu planning can feed planned calories/macros back into shared daily wellness context. Only the launcher is implemented in this build; Diet functionality remains future work.
