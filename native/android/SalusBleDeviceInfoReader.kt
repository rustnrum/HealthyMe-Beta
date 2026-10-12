package com.rustnrum.healthyme.beta03

import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Device Information Service (0x180A) READ-only diagnostic probe.
 * No pairing, proprietary command, characteristic write, descriptor write,
 * persistent BLE connection, DFU, or serial-number request.
 * The requesting user controls when this one-off probe is performed.
 */
internal object SalusBleDeviceInfoReader {
    private val DIS = UUID.fromString("0000180a-0000-1000-8000-00805f9b34fb")
    private val fields = linkedMapOf(
        "manufacturer" to "00002a29-0000-1000-8000-00805f9b34fb",
        "model" to "00002a24-0000-1000-8000-00805f9b34fb",
        "hardware" to "00002a27-0000-1000-8000-00805f9b34fb",
        "firmware" to "00002a26-0000-1000-8000-00805f9b34fb",
        "software" to "00002a28-0000-1000-8000-00805f9b34fb",
    ).mapValues { UUID.fromString(it.value) }

    @SuppressLint("MissingPermission")
    fun read(activity: Activity, address: String, result: MethodChannel.Result) {
        val adapter = activity.getSystemService(BluetoothManager::class.java)?.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLE_UNAVAILABLE", "Turn Bluetooth on before reading device information.", null)
            return
        }
        val device = try {
            adapter.getRemoteDevice(address)
        } catch (_: IllegalArgumentException) {
            result.error("BLE_DEVICE_INVALID", "This device has no valid Bluetooth address.", null)
            return
        }
        val handler = Handler(Looper.getMainLooper())
        val finished = AtomicBoolean(false)
        val queue = ArrayDeque<Pair<String, BluetoothGattCharacteristic>>()
        val revisions = linkedMapOf<String, String>()
        val problems = mutableListOf<String>()
        var services = listOf<String>()
        var gattRef: BluetoothGatt? = null
        var deviceInfoService = false

        fun close() {
            try { gattRef?.disconnect() } catch (_: Exception) { }
            try { gattRef?.close() } catch (_: Exception) { }
        }
        fun complete(status: String) {
            if (!finished.compareAndSet(false, true)) return
            close()
            handler.post {
                result.success(mapOf(
                    "status" to status,
                    "disAvailable" to deviceInfoService,
                    "values" to revisions.toMap(),
                    "serviceUuids" to services,
                    "notes" to problems.toList(),
                ))
            }
        }
        fun fail(message: String) {
            problems.add(message)
            complete("unavailable")
        }
        fun next(gatt: BluetoothGatt) {
            if (finished.get()) return
            while (!queue.isEmpty()) {
                val (name, characteristic) = queue.removeFirst()
                try {
                    if (gatt.readCharacteristic(characteristic)) return
                    problems.add("$name: characteristic read could not start")
                } catch (_: Exception) {
                    problems.add("$name: characteristic read unavailable")
                }
            }
            complete(if (deviceInfoService) "complete" else "service-not-exposed")
        }
        fun handleRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            bytes: ByteArray,
            status: Int,
        ) {
            if (finished.get()) return
            val key = fields.entries.firstOrNull { it.value == characteristic.uuid }?.key
            if (key != null && status == BluetoothGatt.GATT_SUCCESS) {
                val cleaned = bytes.toString(Charsets.UTF_8)
                    .filter { it.code >= 32 && it.code != 127 }
                    .trim().take(100)
                if (cleaned.isNotBlank()) revisions[key] = cleaned
            } else if (key != null) {
                problems.add("$key: not readable (GATT status $status)")
            }
            next(gatt)
        }

        val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(
                gatt: BluetoothGatt, status: Int, newState: Int,
            ) {
                gattRef = gatt
                if (status == BluetoothGatt.GATT_SUCCESS &&
                    newState == BluetoothProfile.STATE_CONNECTED
                ) {
                    if (!gatt.discoverServices()) fail("Bluetooth service discovery could not start")
                } else if (!finished.get()) {
                    fail("Bluetooth disconnected or refused diagnostic connection (status $status)")
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (finished.get()) return
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    fail("Bluetooth service discovery failed ($status)")
                    return
                }
                services = gatt.services.map { it.uuid.toString() }.distinct().take(100)
                val dis = gatt.getService(DIS)
                deviceInfoService = dis != null
                if (dis != null) {
                    for ((name, uuid) in fields) {
                        val characteristic = dis.getCharacteristic(uuid)
                        if (characteristic != null &&
                            characteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ != 0
                        ) {
                            queue.addLast(name to characteristic)
                        }
                    }
                }
                next(gatt)
            }

            @Suppress("DEPRECATION")
            override fun onCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                if (Build.VERSION.SDK_INT < 33) {
                    handleRead(gatt, characteristic, characteristic.value ?: byteArrayOf(), status)
                }
            }

            override fun onCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray,
                status: Int,
            ) {
                handleRead(gatt, characteristic, value, status)
            }
        }

        try {
            gattRef = device.connectGatt(activity, false, callback, BluetoothDevice.TRANSPORT_LE)
        } catch (_: Exception) {
            fail("Could not establish a read-only Bluetooth diagnostic connection")
        }
        handler.postDelayed({
            if (!finished.get()) {
                problems.add("Bluetooth device-info request timed out; partial data retained")
                complete("timeout")
            }
        }, 15000L)
    }
}
