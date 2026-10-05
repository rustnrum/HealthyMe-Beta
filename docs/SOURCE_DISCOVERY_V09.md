# Healthy Me Beta 0.9 — Source Discovery

This beta corrects the v0.8 source-discovery gap.

## Discovery paths

1. Health Connect record origins already supplying data.
2. Health Connect Matchmaking using AndroidX Health Connect 1.2.0-alpha06.
3. Direct Bluetooth LE scan plus GATT inspection, independent of Health Connect.

The build deliberately avoids the unreleased Android SDK 37 platform package. Google documents AndroidX Health Connect 1.2.0-alpha06 as the current integration path for Matchmaking.

The Bluetooth layer remains manufacturer-neutral in the UI/core. Standard health services map to universal metrics. Proprietary protocols stay isolated behind service fingerprints, including the `ring-uart-v1` profile.

This build discovers and inspects BLE devices. It does not yet convert proprietary ring packets into health-history readings.


## SDK 36 compatibility pins

The GitHub runner for this Flutter build compiles against Android SDK 36.

- `flutter_reactive_ble`, `reactive_ble_mobile`, and `reactive_ble_platform_interface`
  are deliberately pinned to **5.5.0**. Version 5.6.0 moved the BLE Android build
  to SDK 37.
- Health Connect is deliberately pinned to **1.2.0-alpha04**, the release that
  introduced Matchmaking. The later alpha06 artifact requires compile SDK 37.

Do not upgrade either family until the Healthy Me Android toolchain has SDK 37
available and its Android Gradle Plugin supports it.


## Runtime matchmaking bridge (SDK 36 build)

The Matchmaking APIs exist in the Android platform on Android 14 with U-extension
21+ (and API 37), but the AndroidX 1.2 alpha artifacts require compile SDK 37.

Healthy Me therefore does **not** compile against the AndroidX matchmaking alpha.
The Android bridge checks the U-extension at runtime and uses reflection for:
- `android.health.connect.HealthConnectManager`
- `android.health.connect.MatchmakingRequest.Builder`
- `isMatchmakingPossible`
- `createMatchmakingIntent`

This preserves real platform matchmaking on supported devices while allowing the
current CI toolchain to remain on compile SDK 36.


## Native Android BLE bridge

`flutter_reactive_ble` was removed from v0.9 after CI proved that:
- 5.6.0 requires Android SDK 37.
- 5.5.0 compiles its Android plugin module against SDK 33 while its AndroidX
  dependencies require SDK 34+.

Healthy Me now uses Android's own `BluetoothLeScanner` and `BluetoothGatt`
through the existing MethodChannel. Dart still performs manufacturer-neutral
service UUID capability matching and protocol-profile matching.

This removes the BLE plugin's Gradle/compileSdk constraints entirely.
