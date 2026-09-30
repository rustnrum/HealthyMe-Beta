# Healthy Me Beta

Clean rebuild starting at **Beta v0.1.0**.

## Structure

- `lib/models` — health data models
- `lib/providers` — Riverpod app state
- `lib/services` — import/guidance/integration logic
- `lib/screens` — user-facing screens
- `lib/widgets` — reusable UI pieces
- `.github/workflows` — build pipeline only, no application source embedded in YAML

## First local setup

Install Flutter, then run:

```bash
chmod +x scripts/bootstrap_android.sh
./scripts/bootstrap_android.sh
flutter pub get
flutter analyze
flutter test
flutter run
```

The bootstrap script creates the Android platform shell once. Commit the generated `android/`
directory to Git afterward. The app source remains in normal Dart files.

## Build

```bash
flutter build apk --debug
```

Release signing is intentionally not hard-coded into the repository. Before distributing
Beta v0.1 updates, configure a permanent beta signing key through GitHub Actions secrets.
