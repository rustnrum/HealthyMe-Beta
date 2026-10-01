# Healthy Me Recovery Model — v0.3.4

Healthy Me Recovery is a transparent wellness/readiness estimate from 0–100. It does not claim to reproduce Oura, WHOOP, Garmin, Apple, or any proprietary score.

## Inputs and maximum weights
- Sleep: 35 points — last-night duration relative to age guidance plus recent sleep balance.
- HRV: 20 points — current HRV relative to the user's personal baseline. Not scored until a usable baseline exists.
- Resting heart rate: 15 points — current RHR relative to the user's personal baseline. Elevated RHR reduces readiness.
- Respiratory rate: 10 points — stability around the user's personal baseline. Larger deviations reduce readiness.
- Training load: 20 points — recent workout duration × modality intensity with time decay, compared with the user's recent training pattern where enough history exists.
- Nutrition: 0 points in v0.3.4. It remains explicitly excluded until the Diet module has real food/fueling data.

Missing signals are excluded from the weighted score rather than assigned guessed values. Confidence equals the percentage of the 100-point signal-weight budget that has usable data/baselines.

## Score bands
- 80–100: High
- 60–79: Moderate
- 40–59: Low
- 0–39: Very low

## Why these signal families
Garmin Training Readiness uses sleep score, recovery time, HRV status, acute load, sleep history, and stress history. Oura Readiness uses personal-baseline contributors including resting heart rate, HRV balance, sleep, sleep balance/regularity, and activity balance. Healthy Me uses the overlapping signal families that Health Connect currently gives us and avoids pretending we have stress, temperature, food, or proprietary EPOC metrics when we do not.

Sources reviewed September/October 2026:
- https://www8.garmin.com/manuals/webhelp/GUID-A315BE5B-E191-4238-9712-D9C368997ADB/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html
- https://www.garmin.com/en-CA/garmin-technology/running-science/physiological-measurements/training-readiness/
- https://support.ouraring.com/hc/en-us/articles/360057791533-Readiness-Contributors
