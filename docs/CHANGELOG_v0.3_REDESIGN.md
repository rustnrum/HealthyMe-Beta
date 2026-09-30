# v0.3 Redesign Correction

This correction replaces the visually incorrect v0.2-style experience with the approved five-screen Healthy Me command-center design.

## Primary-shell changes

- Removed the old Today / Progress / Connect / Labs / Plan primary navigation.
- Primary navigation is now Home / Activity / Sleep / Body / More.
- Removed any visible Beta 0.2 badge from the primary shell.
- Replaced the oversized Material navigation selection treatment with a compact custom bottom navigation matching the approved mockup.

## Visual system

- Rebuilt the palette around deep navy surfaces sampled from the approved mockup.
- Replaced terminal-green styling with restrained cyan/blue, mint, purple, rose and amber accents.
- Reduced card radii, shadows and spacing for a denser modern command-center feel.
- Added reusable design-system widgets for tabs, metric cards, source/status pills, icon badges and empty states.

## Home

- Daily Body Report hero.
- Body-status ring based on real subsystem data coverage, not a made-up score.
- Six compact subsystem cards in a responsive 3-column layout on normal phone widths.
- What changed today.
- Data freshness.

## Activity

- Day / Week / Month / Year tabs.
- Steps vs goal card and progress bar.
- Step trend chart.
- Distance, active calories and active time.
- Workout list and weekly activity.

## Sleep

- Day / Week / Month / Year tabs.
- Total sleep, age-based target and explicitly named duration score.
- Connected sleep-stage distribution only; no fabricated timeline.
- Plain-language insight and seven-day consistency.
- Age 18–64 target corrected to 7–9 hours; 65+ remains 7–8 hours.

## Body

- Weight / Measurements / Composition tabs.
- Weight and goal trend.
- Clean measurement cards; no body silhouette.
- Body fat remains connected-source only.
- Progress photo strip.

## More / Sources & Plan

- Main More screen now follows the approved Sources & Plan composition.
- Health Connect plus actual detected source origins.
- Supported-vendor chips say “via Health Connect” and never falsely claim connection.
- Wellness plan suggestions shown directly.
- Bloodwork, Heart, Goals, Photos, Profile remain secondary tools.

## Secondary screens

- Bloodwork, Sources and Plan were restyled to the same design system while keeping their existing data/edit/import behavior.

## Build guard

`scripts/ui_contract_check.sh` now blocks a build if the old v0.2 primary-nav markers return or if required approved sections disappear.
