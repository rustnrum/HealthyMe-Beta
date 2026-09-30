# Healthy Me Beta v0.3.1

This build tightens the app to the approved five-screen mockup and fixes the readability/overflow issues found in v0.3.

- Raised the primary UI readability floor; no explicit primary-screen text under 12sp.
- Increased section headings, card titles, secondary descriptions and bottom-nav labels.
- Rebuilt the Home hero to more closely match the approved atmospheric Body Status card.
- Increased subsystem card height and spacing so larger text does not clip.
- Added readable time/day labels to activity and consistency charts.
- Reworked Activity, Sleep and Body layouts to follow the approved mockup hierarchy.
- Added Weight range controls and separate Edit Goal / Log Weight actions.
- Reworked Sources & Plan into the five-provider list shown in the approved design while keeping connection states truthful.
- Added provider-name normalization so package IDs such as Samsung Health and Health Connect are never shown raw.
- Made metric source dropdowns expanded/ellipsis-safe to eliminate right-edge overflows.
- Added source-name tests and stronger UI contract checks.
- Version: 0.3.1+6; package remains com.rustnrum.healthyme.beta03 so it updates the separate Beta 0.3 app.
