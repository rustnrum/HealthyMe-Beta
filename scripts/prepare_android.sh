#!/usr/bin/env bash
set -euo pipefail

MANIFEST="android/app/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST" ]; then
  echo "AndroidManifest.xml not found"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

path = Path("android/app/src/main/AndroidManifest.xml")
text = path.read_text()

marker = "HEALTHY_ME_SOURCE_DISCOVERY_V09"
if marker not in text:
    permissions = (
        "\n    <!-- " + marker + ": Health Connect read + Bluetooth source discovery -->\n"
        '    <uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />\n'
        '    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />\n'
        '    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />\n'
        '    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />\n'
        '    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />\n'
        '    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />\n'
        '    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />\n'
        '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />\n'
        '    <uses-permission android:name="android.permission.health.READ_STEPS" />\n'
        '    <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED" />\n'
        '    <uses-permission android:name="android.permission.health.READ_DISTANCE" />\n'
        '    <uses-permission android:name="android.permission.health.READ_HEART_RATE" />\n'
        '    <uses-permission android:name="android.permission.health.READ_RESTING_HEART_RATE" />\n'
        '    <uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY" />\n'
        '    <uses-permission android:name="android.permission.health.READ_RESPIRATORY_RATE" />\n'
        '    <uses-permission android:name="android.permission.health.READ_OXYGEN_SATURATION" />\n'
        '    <uses-permission android:name="android.permission.health.READ_WEIGHT" />\n'
        '    <uses-permission android:name="android.permission.health.READ_BODY_FAT" />\n'
        '    <uses-permission android:name="android.permission.health.READ_BODY_WATER_MASS" />\n'
        '    <uses-permission android:name="android.permission.health.READ_LEAN_BODY_MASS" />\n'
        '    <uses-permission android:name="android.permission.health.READ_SLEEP" />\n'
        '    <uses-permission android:name="android.permission.health.READ_EXERCISE" />\n'
        '    <uses-permission android:name="android.permission.health.READ_HEALTH_DATA_HISTORY" />\n'
    )

    manifest_end = text.find(">")
    text = text[:manifest_end + 1] + permissions + text[manifest_end + 1:]

    queries = (
        "\n    <queries>\n"
        '        <package android:name="com.google.android.apps.healthdata" />\n'
        "        <intent>\n"
        '            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />\n'
        "        </intent>\n"
        "        <intent>\n"
        '            <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />\n'
        '            <category android:name="android.intent.category.HEALTH_PERMISSIONS" />\n'
        "        </intent>\n"
        "    </queries>\n"
    )
    text = text.replace("    <application", queries + "\n    <application", 1)

    rationale = (
        "\n            <intent-filter>\n"
        '                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />\n'
        "            </intent-filter>\n"
    )
    text = text.replace("        </activity>", rationale + "        </activity>", 1)

    alias = (
        "\n        <activity-alias\n"
        '            android:name="ViewPermissionUsageActivity"\n'
        '            android:exported="true"\n'
        '            android:targetActivity=".MainActivity"\n'
        '            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">\n'
        "            <intent-filter>\n"
        '                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />\n'
        '                <category android:name="android.intent.category.HEALTH_PERMISSIONS" />\n'
        "            </intent-filter>\n"
        "        </activity-alias>\n"
    )
    text = text.replace("    </application>", alias + "    </application>", 1)

path.write_text(text)
PY

MAIN_ACTIVITY="$(find android/app/src/main/kotlin -name MainActivity.kt -print -quit 2>/dev/null || true)"
if [ -z "$MAIN_ACTIVITY" ]; then
  echo "MainActivity.kt not found"
  exit 1
fi

cat > "$MAIN_ACTIVITY" <<'KOTLIN'
package com.rustnrum.healthyme.beta03

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.OutcomeReceiver
import android.os.ext.SdkExtensions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.InvocationTargetException
import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "com.rustnrum.healthyme/source_discovery"
        private const val MATCHMAKING_REQUEST_CODE = 9041
        private const val HEALTH_CONNECT_SERVICE_NAME = "health_connect"
        private const val MATCHMAKING_EXTENSION_VERSION = 21
        private const val DEFAULT_SCAN_MS = 8000L
        private const val GATT_TIMEOUT_MS = 12000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingMatchmakingResult: MethodChannel.Result? = null
    private var activeScanCallback: ScanCallback? = null
    private var activeScanResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "discoveryStatus" -> discoveryStatus(result)
                "launchMatchmaking" -> launchMatchmaking(result)
                "scanBle" -> {
                    val durationMs =
                        (call.argument<Number>("durationMs")?.toLong()
                            ?: DEFAULT_SCAN_MS).coerceIn(1000L, 30000L)
                    scanBle(durationMs, result)
                }
                "inspectBle" -> {
                    val deviceId = call.argument<String>("deviceId")
                    if (deviceId.isNullOrBlank()) {
                        result.error(
                            "BLE_DEVICE_ID_MISSING",
                            "Bluetooth device id is required.",
                            null,
                        )
                    } else {
                        inspectBle(deviceId, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun bluetoothManager(): BluetoothManager? =
        getSystemService(BluetoothManager::class.java)

    private fun hasBluetoothPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) ==
            PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
    }

    @SuppressLint("MissingPermission")
    private fun scanBle(durationMs: Long, result: MethodChannel.Result) {
        if (!hasBluetoothPermission()) {
            result.error(
                "BLE_PERMISSION_DENIED",
                "Bluetooth scan/connect permission is required.",
                null,
            )
            return
        }

        val manager = bluetoothManager()
        val adapter = manager?.adapter
        if (adapter == null) {
            result.error(
                "BLE_UNSUPPORTED",
                "Bluetooth LE is not supported on this device.",
                null,
            )
            return
        }
        if (!adapter.isEnabled) {
            result.error("BLE_OFF", "Bluetooth is turned off.", null)
            return
        }
        if (activeScanCallback != null) {
            result.error(
                "BLE_SCAN_BUSY",
                "A Bluetooth scan is already running.",
                null,
            )
            return
        }

        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            result.error(
                "BLE_SCANNER_UNAVAILABLE",
                "Bluetooth LE scanner is unavailable.",
                null,
            )
            return
        }

        val seen = linkedMapOf<String, MutableMap<String, Any?>>()
        val completed = AtomicBoolean(false)

        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult) {
                val device = scanResult.device ?: return
                val id = try {
                    device.address
                } catch (_: SecurityException) {
                    return
                }

                val record = scanResult.scanRecord
                val advertised =
                    record?.serviceUuids?.map { it.uuid.toString() } ?: emptyList()

                val name =
                    record?.deviceName
                        ?: try {
                            device.name
                        } catch (_: SecurityException) {
                            null
                        }
                        ?: ""

                seen[id] = mutableMapOf(
                    "id" to id,
                    "name" to name,
                    "rssi" to scanResult.rssi,
                    "advertisedServices" to advertised,
                    "manufacturerDataHex" to manufacturerDataHex(scanResult),
                )
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                for (item in results) {
                    onScanResult(0, item)
                }
            }

            override fun onScanFailed(errorCode: Int) {
                if (!completed.compareAndSet(false, true)) return
                try {
                    scanner.stopScan(this)
                } catch (_: Throwable) {
                }
                activeScanCallback = null
                activeScanResult = null
                mainHandler.post {
                    result.error(
                        "BLE_SCAN_FAILED",
                        "Bluetooth scan failed with code $errorCode.",
                        errorCode,
                    )
                }
            }
        }

        activeScanCallback = callback
        activeScanResult = result

        try {
            val settings =
                ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                    .build()
            scanner.startScan(null, settings, callback)
        } catch (error: Throwable) {
            activeScanCallback = null
            activeScanResult = null
            result.error(
                "BLE_SCAN_START_FAILED",
                error.message ?: error.javaClass.simpleName,
                null,
            )
            return
        }

        mainHandler.postDelayed({
            if (!completed.compareAndSet(false, true)) return@postDelayed

            try {
                scanner.stopScan(callback)
            } catch (_: Throwable) {
            }

            activeScanCallback = null
            activeScanResult = null
            result.success(seen.values.toList())
        }, durationMs)
    }

    private fun manufacturerDataHex(scanResult: ScanResult): String {
        val data = scanResult.scanRecord?.manufacturerSpecificData ?: return ""
        val builder = StringBuilder()

        for (index in 0 until data.size()) {
            val companyId = data.keyAt(index)
            builder.append(companyId.toString(16).padStart(4, '0'))
            val bytes = data.valueAt(index) ?: continue
            for (byte in bytes) {
                builder.append(
                    (byte.toInt() and 0xff)
                        .toString(16)
                        .padStart(2, '0')
                )
            }
        }

        return builder.toString()
    }

    @SuppressLint("MissingPermission")
    private fun inspectBle(deviceId: String, result: MethodChannel.Result) {
        if (!hasBluetoothPermission()) {
            result.error(
                "BLE_PERMISSION_DENIED",
                "Bluetooth scan/connect permission is required.",
                null,
            )
            return
        }

        val adapter = bluetoothManager()?.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error(
                "BLE_UNAVAILABLE",
                "Bluetooth is unavailable or turned off.",
                null,
            )
            return
        }

        val device = try {
            adapter.getRemoteDevice(deviceId)
        } catch (error: Throwable) {
            result.error(
                "BLE_DEVICE_INVALID",
                error.message ?: "Bluetooth device address is invalid.",
                null,
            )
            return
        }

        val completed = AtomicBoolean(false)
        var gattRef: BluetoothGatt? = null

        fun closeGatt() {
            try {
                gattRef?.disconnect()
            } catch (_: Throwable) {
            }
            try {
                gattRef?.close()
            } catch (_: Throwable) {
            }
        }

        fun fail(code: String, message: String) {
            if (!completed.compareAndSet(false, true)) return
            closeGatt()
            mainHandler.post {
                result.error(code, message, null)
            }
        }

        val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(
                gatt: BluetoothGatt,
                status: Int,
                newState: Int,
            ) {
                gattRef = gatt

                if (status == BluetoothGatt.GATT_SUCCESS &&
                    newState == BluetoothProfile.STATE_CONNECTED
                ) {
                    val started = try {
                        gatt.discoverServices()
                    } catch (_: Throwable) {
                        false
                    }
                    if (!started) {
                        fail(
                            "BLE_GATT_DISCOVERY_FAILED",
                            "Could not start GATT service discovery.",
                        )
                    }
                    return
                }

                if (newState == BluetoothProfile.STATE_DISCONNECTED &&
                    !completed.get()
                ) {
                    fail(
                        "BLE_GATT_DISCONNECTED",
                        "Device disconnected before GATT inspection completed.",
                    )
                } else if (status != BluetoothGatt.GATT_SUCCESS &&
                    !completed.get()
                ) {
                    fail(
                        "BLE_GATT_CONNECTION_FAILED",
                        "Bluetooth GATT connection failed with status $status.",
                    )
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    fail(
                        "BLE_GATT_DISCOVERY_FAILED",
                        "GATT service discovery failed with status $status.",
                    )
                    return
                }
                if (!completed.compareAndSet(false, true)) return

                val services = gatt.services.map { serviceMap(it) }
                closeGatt()
                mainHandler.post {
                    result.success(mapOf("services" to services))
                }
            }
        }

        try {
            gattRef =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    device.connectGatt(
                        this,
                        false,
                        callback,
                        BluetoothDevice.TRANSPORT_LE,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    device.connectGatt(this, false, callback)
                }
        } catch (error: Throwable) {
            fail(
                "BLE_GATT_CONNECT_FAILED",
                error.message ?: error.javaClass.simpleName,
            )
            return
        }

        mainHandler.postDelayed({
            if (!completed.compareAndSet(false, true)) return@postDelayed
            closeGatt()
            result.error(
                "BLE_GATT_TIMEOUT",
                "Timed out while inspecting Bluetooth services.",
                null,
            )
        }, GATT_TIMEOUT_MS)
    }

    private fun serviceMap(service: BluetoothGattService): Map<String, Any> =
        mapOf(
            "serviceUuid" to service.uuid.toString(),
            "characteristics" to
                service.characteristics.map { characteristicDescription(it) },
        )

    private fun characteristicDescription(
        characteristic: BluetoothGattCharacteristic,
    ): String {
        val properties = characteristic.properties
        val flags = mutableListOf<String>()

        if (properties and BluetoothGattCharacteristic.PROPERTY_READ != 0) {
            flags.add("read")
        }
        if (properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) {
            flags.add("notify")
        }
        if (properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0) {
            flags.add("indicate")
        }
        if (properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) {
            flags.add("write")
        }
        if (properties and
            BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0
        ) {
            flags.add("write-no-response")
        }

        val details =
            if (flags.isEmpty()) "no exposed properties" else flags.joinToString(", ")
        return "${characteristic.uuid} • $details"
    }

    private fun uExtensionVersion(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            SdkExtensions.getExtensionVersion(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
        } else {
            0
        }
    }

    private fun platformMatchmakingAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return false
        }
        if (uExtensionVersion() < MATCHMAKING_EXTENSION_VERSION) {
            return false
        }
        return try {
            Class.forName("android.health.connect.HealthConnectManager")
            Class.forName("android.health.connect.MatchmakingRequest\$Builder")
            getSystemService(HEALTH_CONNECT_SERVICE_NAME) != null
        } catch (_: Throwable) {
            false
        }
    }

    private fun healthConnectManager(): Any? {
        if (!platformMatchmakingAvailable()) return null
        return getSystemService(HEALTH_CONNECT_SERVICE_NAME)
    }

    private fun emptyMatchmakingRequest(): Any {
        val builderClass =
            Class.forName("android.health.connect.MatchmakingRequest\$Builder")
        val builder = builderClass.getConstructor().newInstance()
        return builderClass.getMethod("build").invoke(builder)
    }

    private fun visibleHealthApps(): List<Map<String, String>> {
        val packages = linkedMapOf<String, String>()
        val intents = listOf(
            Intent("androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"),
            Intent("android.intent.action.VIEW_PERMISSION_USAGE").apply {
                addCategory("android.intent.category.HEALTH_PERMISSIONS")
            },
        )

        for (intent in intents) {
            @Suppress("DEPRECATION")
            val activities = packageManager.queryIntentActivities(intent, 0)
            for (info in activities) {
                val packageName = info.activityInfo?.packageName ?: continue
                if (packageName == this.packageName) continue

                val label = try {
                    @Suppress("DEPRECATION")
                    val appInfo = packageManager.getApplicationInfo(packageName, 0)
                    packageManager.getApplicationLabel(appInfo).toString()
                } catch (_: PackageManager.NameNotFoundException) {
                    packageName
                }

                packages[packageName] = label
            }
        }

        return packages.map { (packageName, label) ->
            mapOf("packageName" to packageName, "label" to label)
        }
    }

    private fun discoveryStatus(result: MethodChannel.Result) {
        val manager = healthConnectManager()
        if (manager == null) {
            result.success(
                mapOf(
                    "matchmakingSupported" to false,
                    "matchmakingPossible" to false,
                    "healthExtensionVersion" to uExtensionVersion(),
                    "visibleApps" to visibleHealthApps(),
                    "message" to
                        "Health Connect matchmaking needs Android 14 with U-extension 21 or newer.",
                )
            )
            return
        }

        try {
            val request = emptyMatchmakingRequest()
            val method =
                manager.javaClass.methods.firstOrNull {
                    it.name == "isMatchmakingPossible" &&
                        it.parameterTypes.size == 3
                }

            if (method == null) {
                result.success(
                    mapOf(
                        "matchmakingSupported" to false,
                        "matchmakingPossible" to false,
                        "healthExtensionVersion" to uExtensionVersion(),
                        "visibleApps" to visibleHealthApps(),
                        "message" to
                            "Health Connect matchmaking API is not exposed by this system module.",
                    )
                )
                return
            }

            val executor: Executor = mainExecutor
            val receiver = object : OutcomeReceiver<Any, Throwable> {
                override fun onResult(response: Any) {
                    val possible = try {
                        val getter =
                            response.javaClass.methods.firstOrNull {
                                it.name == "isMatchmakingPossible" &&
                                    it.parameterTypes.isEmpty()
                            }
                        getter?.invoke(response) as? Boolean ?: false
                    } catch (_: Throwable) {
                        false
                    }

                    result.success(
                        mapOf(
                            "matchmakingSupported" to true,
                            "matchmakingPossible" to possible,
                            "healthExtensionVersion" to uExtensionVersion(),
                            "visibleApps" to visibleHealthApps(),
                            "message" to if (possible) {
                                "Health Connect found a compatible app or device that can provide data Healthy Me can read."
                            } else {
                                "Health Connect did not find an unconnected compatible source right now."
                            },
                        )
                    )
                }

                override fun onError(error: Throwable) {
                    result.error(
                        "MATCHMAKING_CHECK_FAILED",
                        error.message ?: error.javaClass.simpleName,
                        null,
                    )
                }
            }

            method.invoke(manager, request, executor, receiver)
        } catch (error: InvocationTargetException) {
            val cause = error.targetException ?: error
            result.error(
                "MATCHMAKING_CHECK_FAILED",
                cause.message ?: cause.javaClass.simpleName,
                null,
            )
        } catch (error: Throwable) {
            result.error(
                "MATCHMAKING_CHECK_FAILED",
                error.message ?: error.javaClass.simpleName,
                null,
            )
        }
    }

    private fun launchMatchmaking(result: MethodChannel.Result) {
        val manager = healthConnectManager()
        if (manager == null) {
            result.error(
                "MATCHMAKING_UNAVAILABLE",
                "Health Connect matchmaking is not available on this device.",
                null,
            )
            return
        }

        try {
            val request = emptyMatchmakingRequest()
            val method =
                manager.javaClass.methods.firstOrNull {
                    it.name == "createMatchmakingIntent" &&
                        it.parameterTypes.size == 1
                } ?: throw NoSuchMethodException("createMatchmakingIntent")

            val intent = method.invoke(manager, request) as? Intent
                ?: throw IllegalStateException(
                    "Health Connect did not return a matchmaking Intent.",
                )

            pendingMatchmakingResult = result
            @Suppress("DEPRECATION")
            startActivityForResult(intent, MATCHMAKING_REQUEST_CODE)
        } catch (error: InvocationTargetException) {
            pendingMatchmakingResult = null
            val cause = error.targetException ?: error
            result.error(
                "MATCHMAKING_LAUNCH_FAILED",
                cause.message ?: cause.javaClass.simpleName,
                null,
            )
        } catch (error: Throwable) {
            pendingMatchmakingResult = null
            result.error(
                "MATCHMAKING_LAUNCH_FAILED",
                error.message ?: error.javaClass.simpleName,
                null,
            )
        }
    }

    @Deprecated("Retained for Health Connect matchmaking result delivery.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != MATCHMAKING_REQUEST_CODE) return

        pendingMatchmakingResult?.success(
            mapOf(
                "granted" to (resultCode == Activity.RESULT_OK),
                "resultCode" to resultCode,
            )
        )
        pendingMatchmakingResult = null
    }
}
KOTLIN

python3 - <<'PYGRADLE'
from pathlib import Path
import re

for name in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    path = Path(name)
    if not path.exists():
        continue

    text = path.read_text()

    if name.endswith('.kts'):
        text = text.replace('minSdk = flutter.minSdkVersion', 'minSdk = 26')
        text = re.sub(
            r'namespace\s*=\s*["\'][^"\']+["\']',
            'namespace = "com.rustnrum.healthyme.beta03"',
            text,
        )
        text = re.sub(
            r'applicationId\s*=\s*["\'][^"\']+["\']',
            'applicationId = "com.rustnrum.healthyme.beta03"',
            text,
        )
    else:
        text = text.replace(
            'minSdkVersion flutter.minSdkVersion',
            'minSdkVersion 26',
        )
        text = re.sub(
            r'applicationId\s+["\'][^"\']+["\']',
            'applicationId "com.rustnrum.healthyme.beta03"',
            text,
        )

    # Critical: do not add any SDK-37 Health Connect matchmaking AAR here.
    text = re.sub(
        r'\ndependencies\s*\{\s*implementation\(["\']androidx\.health\.connect:connect-client:[^"\']+["\']\)\s*implementation\(["\']org\.jetbrains\.kotlinx:kotlinx-coroutines-android:[^"\']+["\']\)\s*\}\s*',
        '\n',
        text,
        flags=re.S,
    )
    text = re.sub(
        r'\ndependencies\s*\{\s*implementation\s+["\']androidx\.health\.connect:connect-client:[^"\']+["\']\s*implementation\s+["\']org\.jetbrains\.kotlinx:kotlinx-coroutines-android:[^"\']+["\']\s*\}\s*',
        '\n',
        text,
        flags=re.S,
    )

    path.write_text(text)
PYGRADLE

if ! grep -q '^android.useAndroidX=true' android/gradle.properties 2>/dev/null; then
  echo 'android.useAndroidX=true' >> android/gradle.properties
fi
if ! grep -q '^android.enableJetifier=true' android/gradle.properties 2>/dev/null; then
  echo 'android.enableJetifier=true' >> android/gradle.properties
fi

python3 - <<'PYLABEL'
from pathlib import Path
import re

path = Path('android/app/src/main/AndroidManifest.xml')
text = path.read_text()
text = re.sub(
    r'android:label="[^"]+"',
    'android:label="Healthy Me Beta 0.9"',
    text,
    count=1,
)
path.write_text(text)
PYLABEL

echo "Healthy Me Beta 0.9 runtime Health Connect matchmaking + BLE bridge applied."

bash scripts/ui_contract_check.sh
bash scripts/source_discovery_contract.sh
