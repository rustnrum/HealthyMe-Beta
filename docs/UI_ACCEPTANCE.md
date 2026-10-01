# Healthy Me v0.3.2 UI Acceptance Contract

The approved five-phone command-center mockup is the visual/product contract for this build. The implementation should match its structure, density, hierarchy and accent language while remaining truthful to available data.

## Required primary navigation

Home / Activity / Sleep / Body / More

The previous v0.2 navigation (Today / Progress / Connect / Labs / Plan) is not allowed in the primary shell.

## Readability

- Primary-screen text must not be explicitly sized below 12sp.
- Secondary explanatory text should normally be 13sp or larger.
- Section headings should be ~21sp and primary card titles 15–18sp.
- Layouts must reflow instead of clipping or using tiny text.
- Source dropdowns must never overflow horizontally.

## Home / Daily Body Report

- Greeting and date
- Illustrated/atmospheric Body Status hero with one calm status ring
- Six subsystem cards: Recovery, Sleep, Activity, Cardio, Body, Labs
- What changed today
- Data freshness

## Activity

- Day / Week / Month / Year selector
- Steps vs goal
- Time/trend chart with readable axis labels
- Distance, active calories, active time
- Workouts
- Weekly activity

## Sleep

- Total sleep
- Age-based target calculated from birthday/profile
- Duration score clearly labeled Sleep Score
- Sleep-stage distribution from connected data only
- Plain-language insight
- Seven-day consistency

## Body

- Weight / Measurements / Composition tabs
- Weight and goal with real trend data and range selector
- Clean measurement grid; no human silhouette
- Body fat from connected source only
- Progress photos

## More / Sources & Plan

- Health Connect plus only vendor rows actually detected from Health Connect records
- Never list Fitbit, Withings, Samsung, Garmin or another vendor merely as a static option in Connected Sources
- Never display raw package IDs as provider names
- Metric routing remains available in detailed Sources screen
- Personalized wellness suggestions from PlanService
- Bloodwork, Heart, Goals, Photos and Profile remain accessible as secondary tools

## Visual language

- Deep navy background
- Bright cyan, mint, purple, rose and amber accents used selectively
- Rounded dark-blue cards with subtle borders and restrained shadows
- White primary text with clearly readable secondary text
- No terminal-green / retro-computer look
- No giant Material selection pill
- No visible Beta 0.2 badge
- Responsive layouts must avoid overflow on common Android phone widths


## Section launcher

- A top-level Healthy Me sections menu is present in the primary app bar.
- Fitness is the active section.
- Diet is visible as future/coming soon only; it does not replace the current bottom navigation yet.
- Future Diet navigation is reserved as Diet / Menu / Planning / Grocery List.
