package com.rustnrum.healthyme.beta03

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
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
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.sqrt

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "com.rustnrum.healthyme/source_discovery"
        private const val DEFAULT_SCAN_MS = 8000L
        private const val GATT_TIMEOUT_MS = 12000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var activeScanCallback: ScanCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
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
                "pairBle" -> {
                    val deviceId = call.argument<String>("deviceId")
                    if (deviceId.isNullOrBlank()) {
                        result.error(
                            "BLE_DEVICE_ID_MISSING",
                            "Bluetooth device id is required.",
                            null,
                        )
                    } else {
                        pairBle(deviceId, result)
                    }
                }
                "readStandardMetrics" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val durationMs =
                        (call.argument<Number>("durationMs")?.toLong()
                            ?: 8000L).coerceIn(3000L, 30000L)
                    if (deviceId.isNullOrBlank()) {
                        result.error(
                            "BLE_DEVICE_ID_MISSING",
                            "Bluetooth device id is required.",
                            null,
                        )
                    } else {
                        readStandardMetrics(deviceId, durationMs, result)
                    }
                }
                "readProtocolMetrics" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val deviceName = call.argument<String>("deviceName") ?: ""
                    val protocolId = call.argument<String>("protocolId") ?: ""
                    val durationMs =
                        (call.argument<Number>("durationMs")?.toLong()
                            ?: 16000L).coerceIn(5000L, 90000L)
                    val cpapPasskey = call.argument<String>("cpapPasskey")

                    if (deviceId.isNullOrBlank()) {
                        result.error(
                            "BLE_DEVICE_ID_MISSING",
                            "Bluetooth device id is required.",
                            null,
                        )
                    } else {
                        val protectedResult =
                            if (protocolId == "cpap-family") {
                                protectCpapPairing(deviceId, result)
                            } else {
                                result
                            }
                        SalusProtocolReader(this, mainHandler).read(
                            deviceId,
                            deviceName,
                            protocolId,
                            durationMs,
                            cpapPasskey,
                            protectedResult,
                        )
                    }
                }
                "submitCpapPasskey" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val cpapPasskey = call.argument<String>("cpapPasskey")
                    result.success(
                        !deviceId.isNullOrBlank() &&
                            !cpapPasskey.isNullOrBlank() &&
                            SalusProtocolReader.submitCpapPasskey(
                                deviceId,
                                cpapPasskey,
                            )
                    )
                }
                "cpapHasSavedPairing" -> {
                    val deviceId = call.argument<String>("deviceId")
                    result.success(
                        !deviceId.isNullOrBlank() &&
                            hasSavedCpapPairing(deviceId)
                    )
                }
                "resetCpapPairing" -> {
                    val deviceId = call.argument<String>("deviceId")
                    result.success(
                        !deviceId.isNullOrBlank() &&
                            resetCpapPairing(deviceId)
                    )
                }
                "getWatchNotificationState" -> {
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    val deviceName =
                        call.argument<String>("deviceName") ?: "Watch"
                    val protocolId =
                        call.argument<String>("protocolId") ?: ""
                    result.success(
                        SalusWatchNotificationStore.state(
                            this,
                            deviceId,
                            deviceName,
                            protocolId,
                            isNotificationServiceEnabled(),
                        ) + SalusWatchTransportStatus.state(this, deviceId)
                    )
                }
                "setWatchNotificationMaster" -> {
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    val deviceName =
                        call.argument<String>("deviceName") ?: "Watch"
                    val protocolId =
                        call.argument<String>("protocolId") ?: ""
                    val enabled =
                        call.argument<Boolean>("enabled") == true
                    if (deviceId.isNotBlank()) {
                        SalusWatchNotificationStore.setMaster(
                            this,
                            deviceId,
                            deviceName,
                            protocolId,
                            enabled,
                        )
                        if (protocolId == "garmin-family") {
                            if (enabled) SalusGarminNotificationSender.watch(this, deviceId, true)
                            else SalusGarminNotificationSender.unwatch(deviceId)
                        }
                    }
                    result.success(true)
                }
                "setWatchNotificationApp" -> {
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    val packageName =
                        call.argument<String>("packageName") ?: ""
                    val enabled =
                        call.argument<Boolean>("enabled") == true
                    if (deviceId.isNotBlank() &&
                        packageName.isNotBlank()
                    ) {
                        SalusWatchNotificationStore.setApp(
                            this,
                            deviceId,
                            packageName,
                            enabled,
                        )
                    }
                    result.success(true)
                }
                "setWatchNotificationAllAccounts" -> {
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    val packageName =
                        call.argument<String>("packageName") ?: ""
                    val enabled =
                        call.argument<Boolean>("enabled") == true
                    if (deviceId.isNotBlank() &&
                        packageName.isNotBlank()
                    ) {
                        SalusWatchNotificationStore.setAllAccounts(
                            this,
                            deviceId,
                            packageName,
                            enabled,
                        )
                    }
                    result.success(true)
                }
                "setWatchNotificationAccount" -> {
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    val packageName =
                        call.argument<String>("packageName") ?: ""
                    val account = call.argument<String>("account") ?: ""
                    val enabled =
                        call.argument<Boolean>("enabled") == true
                    if (deviceId.isNotBlank() &&
                        packageName.isNotBlank() &&
                        account.isNotBlank()
                    ) {
                        SalusWatchNotificationStore.setAccount(
                            this,
                            deviceId,
                            packageName,
                            account,
                            enabled,
                        )
                    }
                    result.success(true)
                }
                "sendWatchTestNotification" -> {
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    val target = SalusWatchNotificationStore.targets(this)
                        .firstOrNull { it.deviceId == deviceId && it.protocolId == "garmin-family" }
                    if (target != null && isNotificationServiceEnabled()) {
                        SalusGarminNotificationSender.test(this, deviceId)
                        result.success(true)
                    } else result.success(false)
                }
                "notificationAccessStatus" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "openNotificationAccess" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        )
                        result.success(true)
                    } catch (error: Throwable) {
                        result.error(
                            "NOTIFICATION_ACCESS_FAILED",
                            error.message ?: error.javaClass.simpleName,
                            null,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun cpapPrefs() =
        getSharedPreferences("salus_resmed_session_v1", 0)

    private fun cpapKey(deviceId: String): String =
        deviceId.replace(":", "").lowercase()

    private fun hasSavedCpapPairing(deviceId: String): Boolean {
        val key = cpapKey(deviceId)
        val prefs = cpapPrefs()
        val clientId = prefs.getString("${key}_clientId", null)
        val master = prefs.getString("${key}_masterPairKey", null)
        return !clientId.isNullOrBlank() && !master.isNullOrBlank()
    }

    private fun resetCpapPairing(deviceId: String): Boolean {
        val key = cpapKey(deviceId)
        cpapPrefs().edit()
            .remove("${key}_clientId")
            .remove("${key}_masterPairKey")
            .apply()
        return true
    }

    private fun protectCpapPairing(
        deviceId: String,
        delegate: MethodChannel.Result,
    ): MethodChannel.Result {
        val key = cpapKey(deviceId)
        val prefs = cpapPrefs()
        val savedClientId = prefs.getString("${key}_clientId", null)
        val savedMaster = prefs.getString("${key}_masterPairKey", null)

        if (savedClientId.isNullOrBlank() || savedMaster.isNullOrBlank()) {
            return delegate
        }

        fun restoreIfReaderClearedSavedPairing() {
            val currentClientId =
                prefs.getString("${key}_clientId", null)
            val currentMaster =
                prefs.getString("${key}_masterPairKey", null)
            if (currentClientId.isNullOrBlank() ||
                currentMaster.isNullOrBlank()
            ) {
                prefs.edit()
                    .putString("${key}_clientId", savedClientId)
                    .putString("${key}_masterPairKey", savedMaster)
                    .apply()
            }
        }

        return object : MethodChannel.Result {
            override fun success(result: Any?) {
                restoreIfReaderClearedSavedPairing()
                delegate.success(result)
            }

            override fun error(
                errorCode: String,
                errorMessage: String?,
                errorDetails: Any?,
            ) {
                restoreIfReaderClearedSavedPairing()
                delegate.error(errorCode, errorMessage, errorDetails)
            }

            override fun notImplemented() {
                restoreIfReaderClearedSavedPairing()
                delegate.notImplemented()
            }
        }
    }

    private fun bluetoothManager(): BluetoothManager? =
        getSystemService(BluetoothManager::class.java)

    private fun isNotificationServiceEnabled(): Boolean {
        val flat =
            Settings.Secure.getString(
                contentResolver,
                "enabled_notification_listeners",
            ) ?: return false

        val ownPackage = packageName.lowercase()
        return flat
            .split(':')
            .any { component ->
                component
                    .substringBefore('/')
                    .lowercase() == ownPackage
            }
    }

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

        val adapter = bluetoothManager()?.adapter
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
                    "bondState" to bondStateLabel(device.bondState),
                )
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                for (item in results) onScanResult(0, item)
            }

            override fun onScanFailed(errorCode: Int) {
                if (!completed.compareAndSet(false, true)) return
                try {
                    scanner.stopScan(this)
                } catch (_: Throwable) {
                }
                activeScanCallback = null
                result.error(
                    "BLE_SCAN_FAILED",
                    "Bluetooth scan failed with code $errorCode.",
                    errorCode,
                )
            }
        }

        activeScanCallback = callback

        try {
            scanner.startScan(
                null,
                ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                    .build(),
                callback,
            )
        } catch (error: Throwable) {
            activeScanCallback = null
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

    private fun bondStateLabel(state: Int): String =
        when (state) {
            BluetoothDevice.BOND_BONDED -> "bonded"
            BluetoothDevice.BOND_BONDING -> "bonding"
            BluetoothDevice.BOND_NONE -> "not-bonded"
            else -> "unknown"
        }

    @SuppressLint("MissingPermission")
    private fun pairBle(deviceId: String, result: MethodChannel.Result) {
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
                error.message ?: "Invalid Bluetooth address.",
                null,
            )
            return
        }

        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            result.success(
                mapOf(
                    "usable" to true,
                    "bonded" to true,
                    "state" to "bonded",
                    "message" to "Android pairing is already established.",
                )
            )
            return
        }

        val started = try {
            device.createBond()
        } catch (_: Throwable) {
            false
        }

        if (!started) {
            result.success(
                mapOf(
                    "usable" to true,
                    "bonded" to false,
                    "state" to bondStateLabel(device.bondState),
                    "message" to
                        "This BLE device does not require Android bonding. Salus can still use direct GATT.",
                )
            )
            return
        }

        var checks = 0
        fun pollBond() {
            val state = try {
                device.bondState
            } catch (_: Throwable) {
                BluetoothDevice.BOND_NONE
            }

            if (state == BluetoothDevice.BOND_BONDED || checks++ >= 60) {
                result.success(
                    mapOf(
                        "usable" to true,
                        "bonded" to (state == BluetoothDevice.BOND_BONDED),
                        "state" to bondStateLabel(state),
                        "message" to if (state == BluetoothDevice.BOND_BONDED) {
                            "Paired with Android."
                        } else {
                            "Android bonding did not finish. Salus can still try direct GATT."
                        },
                    )
                )
                return
            }

            mainHandler.postDelayed({ pollBond() }, 500L)
        }

        pollBond()
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
                    if (!gatt.discoverServices()) {
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

            override fun onServicesDiscovered(
                gatt: BluetoothGatt,
                status: Int,
            ) {
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
            if (flags.isEmpty()) "no exposed properties"
            else flags.joinToString(", ")

        return "${characteristic.uuid} • $details"
    }

    @SuppressLint("MissingPermission")
    private fun readStandardMetrics(
        deviceId: String,
        durationMs: Long,
        result: MethodChannel.Result,
    ) {
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
                error.message ?: "Invalid Bluetooth address.",
                null,
            )
            return
        }

        val completed = AtomicBoolean(false)
        val metrics = linkedMapOf<String, Double>()
        val rrIntervalsMs = mutableListOf<Double>()
        var gattRef: BluetoothGatt? = null
        var heartMeasurement: BluetoothGattCharacteristic? = null

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

        fun finish(message: String? = null) {
            if (!completed.compareAndSet(false, true)) return

            if (rrIntervalsMs.size >= 3) {
                var sumSquares = 0.0
                for (index in 1 until rrIntervalsMs.size) {
                    val delta =
                        rrIntervalsMs[index] - rrIntervalsMs[index - 1]
                    sumSquares += delta * delta
                }
                metrics["HRV"] =
                    sqrt(sumSquares / (rrIntervalsMs.size - 1))
            }

            closeGatt()
            mainHandler.post {
                result.success(
                    mapOf(
                        "metrics" to metrics,
                        "reader" to "standard-gatt",
                        "message" to
                            (message ?: if (metrics.isEmpty()) {
                                "No supported standard measurement was available."
                            } else {
                                "Read standard Bluetooth health data."
                            }),
                    )
                )
            }
        }

        fun handleHeartRate(bytes: ByteArray) {
            if (bytes.size < 2) return
            val flags = bytes[0].toInt() and 0xff
            val sixteen = flags and 0x01 != 0
            var offset = 1

            val bpm =
                if (sixteen) {
                    if (bytes.size < 3) return
                    offset = 3
                    (bytes[1].toInt() and 0xff) or
                        ((bytes[2].toInt() and 0xff) shl 8)
                } else {
                    bytes[1].toInt() and 0xff
                }

            metrics["Heart rate"] = bpm.toDouble()

            if (flags and 0x08 != 0) offset += 2
            if (flags and 0x10 == 0) return

            while (offset + 1 < bytes.size) {
                val raw =
                    (bytes[offset].toInt() and 0xff) or
                        ((bytes[offset + 1].toInt() and 0xff) shl 8)
                if (raw > 0) {
                    rrIntervalsMs.add(raw * 1000.0 / 1024.0)
                }
                offset += 2
            }
        }

        fun subscribeHeartRate(gatt: BluetoothGatt) {
            val characteristic = heartMeasurement
            if (characteristic == null) {
                mainHandler.postDelayed({ finish() }, 250L)
                return
            }

            try {
                gatt.setCharacteristicNotification(characteristic, true)
                val cccd =
                    characteristic.getDescriptor(
                        UUID.fromString(
                            "00002902-0000-1000-8000-00805f9b34fb"
                        )
                    )
                if (cccd != null) {
                    @Suppress("DEPRECATION")
                    cccd.value =
                        BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    @Suppress("DEPRECATION")
                    gatt.writeDescriptor(cccd)
                }
            } catch (_: Throwable) {
                finish(
                    "Heart Rate was present but could not be subscribed."
                )
                return
            }

            mainHandler.postDelayed({ finish() }, durationMs)
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
                    if (!gatt.discoverServices()) {
                        finish("Could not discover Bluetooth services.")
                    }
                    return
                }

                if (!completed.get() &&
                    newState == BluetoothProfile.STATE_DISCONNECTED
                ) {
                    finish()
                }
            }

            override fun onServicesDiscovered(
                gatt: BluetoothGatt,
                status: Int,
            ) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    finish("Bluetooth service discovery failed.")
                    return
                }

                heartMeasurement =
                    gatt.getService(
                        UUID.fromString(
                            "0000180d-0000-1000-8000-00805f9b34fb"
                        )
                    )?.getCharacteristic(
                        UUID.fromString(
                            "00002a37-0000-1000-8000-00805f9b34fb"
                        )
                    )

                val battery =
                    gatt.getService(
                        UUID.fromString(
                            "0000180f-0000-1000-8000-00805f9b34fb"
                        )
                    )?.getCharacteristic(
                        UUID.fromString(
                            "00002a19-0000-1000-8000-00805f9b34fb"
                        )
                    )

                if (battery != null &&
                    battery.properties and
                        BluetoothGattCharacteristic.PROPERTY_READ != 0
                ) {
                    @Suppress("DEPRECATION")
                    if (gatt.readCharacteristic(battery)) return
                }

                subscribeHeartRate(gatt)
            }

            @Deprecated("Deprecated in Java")
            override fun onCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                if (status == BluetoothGatt.GATT_SUCCESS &&
                    characteristic.uuid.toString().equals(
                        "00002a19-0000-1000-8000-00805f9b34fb",
                        ignoreCase = true,
                    )
                ) {
                    val bytes = characteristic.value ?: byteArrayOf()
                    if (bytes.isNotEmpty()) {
                        val value = bytes[0].toInt() and 0xff
                        if (value in 0..100) {
                            metrics["Battery"] = value.toDouble()
                        }
                    }
                }

                subscribeHeartRate(gatt)
            }

            @Deprecated("Deprecated in Java")
            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
            ) {
                if (characteristic.uuid.toString().equals(
                        "00002a37-0000-1000-8000-00805f9b34fb",
                        ignoreCase = true,
                    )
                ) {
                    handleHeartRate(characteristic.value ?: return)
                }
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray,
            ) {
                if (characteristic.uuid.toString().equals(
                        "00002a37-0000-1000-8000-00805f9b34fb",
                        ignoreCase = true,
                    )
                ) {
                    handleHeartRate(value)
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
            result.error(
                "BLE_GATT_CONNECT_FAILED",
                error.message ?: error.javaClass.simpleName,
                null,
            )
            return
        }

        mainHandler.postDelayed({
            if (!completed.get()) finish()
        }, durationMs + 5000L)
    }
}
