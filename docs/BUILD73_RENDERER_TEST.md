# Salus Build 73 — screen renderer diagnostic

## Observed problem

On Galaxy Z Fold7, Build 72 showed a near-opaque red tint over the main application viewport across multiple pages, while the bottom navigation remained legible. This is a real on-device rendering regression. Flutter analysis, tests, Kotlin build and APK signing passing did **not** validate the appearance.

## Change (deliberately narrow)

* Version 0.21.35+73.
* Android embedding: `io.flutter.embedding.android.EnableImpeller=false`. This instructs Flutter to use the alternate Android rendering backend for an isolation test. It does not change source metrics, permissions, UI design, saved preferences, encrypted backup format, or package/signing identities.
* A source-contract test verifies manifest and version metadata.

## Validation limits

This does **not** establish the original red-screen root cause or guarantee that it is fixed. The repository's existing CI builds **debug** APKs. CI still must pass, and the actual Fold7 must be checked again. Do not uninstall or clear app data. A properly signed release-mode CI workflow is a separate necessary improvement, not delivered by this renderer-only overlay.
