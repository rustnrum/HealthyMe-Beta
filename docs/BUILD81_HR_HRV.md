# Build 81: Home Resting HR / HRV correction

- Fix a 0px-width chart painter in the Home resting-HR trend card, which made the chart disappear even while real daily history was available.
- Add a regression widget test using the same loose Column layout and narrow width as the phone's card.
- HRV remains blank unless at least two verified history values exist. Replace vague empty copy with an action that links to existing provider-specific HRV detail/history.
- No changes to direct BLE Garmin HRV safety restrictions, provider choices, saved measurements, recovery score, module selector, themes, or Android package/signing.
