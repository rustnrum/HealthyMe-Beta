# Salus bundled compatibility packs

Salus discovers Bluetooth devices capability-first.

1. Standard Bluetooth GATT services work without vendor identity.
2. The bundled local registry identifies proprietary protocol families from service UUIDs and exact name tokens.
3. Only built-in readers may claim proprietary metrics.
4. Unsupported families may be identified, but Salus must not invent capabilities or health values.
5. Compatibility packs are bundled with the app. There is no runtime download or remote code execution.

The bundled registry lives at `assets/protocols/registry.json`.

The first migration build moves the already-working current `SalusProtocolReader.kt.template`
into `native/android/SalusProtocolReader.kt` and removes the old Python mutation layer.
Future builds use permanent Dart/Kotlin source.
