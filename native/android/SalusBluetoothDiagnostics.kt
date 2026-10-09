package com.rustnrum.healthyme.beta03

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import java.util.concurrent.ConcurrentHashMap

/**
 * Vendor-independent Bluetooth link-security evidence for locally managed wearables.
 * Stores only device-scoped state and status codes. Never stores keys, passkeys,
 * personal notification text, or the Bluetooth address in the diagnostic report.
 */
object SalusBluetoothDiagnostics {
    private const val ENCRYPTION_CHANGE = "android.bluetooth.device.action.ENCRYPTION_CHANGE"
    private const val KEY_MISSING = "android.bluetooth.device.action.KEY_MISSING"
    private const val EXTRA_ENCRYPTION_ENABLED = "android.bluetooth.device.extra.ENCRYPTION_ENABLED"
    private const val EXTRA_ENCRYPTION_STATUS = "android.bluetooth.device.extra.ENCRYPTION_STATUS"
    private const val EXTRA_ENCRYPTION_ALGORITHM = "android.bluetooth.device.extra.EXTRA_ENCRYPTION_ALGORITHM"
    private const val EXTRA_KEY_SIZE = "android.bluetooth.device.extra.KEY_SIZE"
    private const val EXTRA_TRANSPORT = "android.bluetooth.device.extra.TRANSPORT"
    private const val LE = 2
    private val monitors = ConcurrentHashMap<String, BroadcastReceiver>()

    private fun permitted(context: Context): Boolean = Build.VERSION.SDK_INT < 31 ||
        context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun label(code: Int) = when (code) {
        0 -> "NONE"
        1 -> "E0"
        2 -> "AES"
        3 -> "UNKNOWN"
        else -> "algorithm=$code"
    }

    private fun observed(context: Context, deviceId: String, kind: String, value: String) {
        SalusWatchTransportStatus.metadata(context, deviceId, kind, value)
        SalusWatchTransportStatus.note(context, deviceId, "BLE $kind", value)
    }

    /** Called when the app owns the GATT session; listeners survive reconnects. */
    fun watch(context: Context, deviceId: String) {
        if (deviceId.isBlank() || !permitted(context)) return
        if (monitors.containsKey(deviceId)) return
        val app = context.applicationContext
        val receiver = object : BroadcastReceiver() {
            @SuppressLint("MissingPermission")
            override fun onReceive(c: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                @Suppress("DEPRECATION")
                val d = if (Build.VERSION.SDK_INT >= 33)
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                else intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                if (d == null || !runCatching { d.address.equals(deviceId, true) }.getOrDefault(false)) return
                when (action) {
                    BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                        val state = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
                        observed(app, deviceId, "bond", bondLabel(state))
                    }
                    KEY_MISSING -> observed(app, deviceId, "securityError", "Android reports missing BLE encryption key")
                    ENCRYPTION_CHANGE -> {
                        if (intent.getIntExtra(EXTRA_TRANSPORT, LE) != LE) return
                        val enabled = intent.getBooleanExtra(EXTRA_ENCRYPTION_ENABLED, false)
                        val status = intent.getIntExtra(EXTRA_ENCRYPTION_STATUS, -1)
                        val keySize = intent.getIntExtra(EXTRA_KEY_SIZE, 0)
                        val algorithm = intent.getIntExtra(EXTRA_ENCRYPTION_ALGORITHM, -1)
                        val description = "${if (enabled) "ON" else "OFF"}; ${label(algorithm)}; " +
                            "key=${if (keySize in 1..16) "$keySize bytes" else "not reported"}; controller=$status"
                        observed(app, deviceId, "encryptionEvent", description)
                        if (status != 0) observed(app, deviceId, "securityError", "BLE encryption change failed (controller=$status)")
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            if (Build.VERSION.SDK_INT >= 36) {
                addAction(ENCRYPTION_CHANGE)
                addAction(KEY_MISSING)
            }
        }
        try {
            if (Build.VERSION.SDK_INT >= 33) app.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            else app.registerReceiver(receiver, filter)
            val existing = monitors.putIfAbsent(deviceId, receiver)
            if (existing != null) app.unregisterReceiver(receiver)
        } catch (error: Exception) {
            SalusWatchTransportStatus.metadata(app, deviceId, "securityError", "Security observer unavailable: ${error.javaClass.simpleName}")
        }
    }

    fun unwatch(context: Context, deviceId: String) {
        val receiver = monitors.remove(deviceId) ?: return
        try { context.applicationContext.unregisterReceiver(receiver) } catch (_: IllegalArgumentException) {}
    }

    fun bondLabel(value: Int): String = when (value) {
        BluetoothDevice.BOND_BONDED -> "BONDED (keys saved; current encryption unverified)"
        BluetoothDevice.BOND_BONDING -> "BONDING"
        BluetoothDevice.BOND_NONE -> "NOT BONDED"
        else -> "UNKNOWN ($value)"
    }

    fun gattStatus(value: Int): String = when (value) {
        0 -> "OK (0)"
        5 -> "AUTHENTICATION REQUIRED (5)"
        8 -> "AUTHORIZATION REQUIRED (8)"
        15 -> "ENCRYPTION REQUIRED (15)"
        19 -> "PEER DISCONNECTED (19)"
        22 -> "LOCAL HOST DISCONNECTED (22)"
        133 -> "GATT ERROR (133)"
        else -> "GATT status=$value"
    }

    /** The live query requires 36.1+. Reflection keeps builds targeting earlier SDKs working. */
    @SuppressLint("MissingPermission")
    private fun queryEncryption(device: BluetoothDevice): String {
        if (Build.VERSION.SDK_INT < 36) return "Not queryable on this Android release"
        return try {
            val method = device.javaClass.getMethod("getEncryptionStatus", Int::class.javaPrimitiveType)
            val status = method.invoke(device, LE)
                ?: return "No active encrypted link reported (or disconnected)"
            val api = status.javaClass
            val algorithm = (api.getMethod("getAlgorithm").invoke(status) as Number).toInt()
            val key = (api.getMethod("getKeySize").invoke(status) as Number).toInt()
            "${label(algorithm)}; key=$key bytes (Android live query)"
        } catch (_: NoSuchMethodException) {
            "Live encryption query unavailable on this Android release"
        } catch (_: SecurityException) {
            "Encryption query denied by Android"
        } catch (e: Exception) {
            "Encryption query unavailable (${e.javaClass.simpleName})"
        }
    }

    @SuppressLint("MissingPermission")
    fun snapshot(context: Context, deviceId: String): Map<String, Any> {
        val p = context.getSharedPreferences("salus_watch_transport_v1", Context.MODE_PRIVATE)
        val key = deviceId.replace(":", "").replace("-", "").lowercase()
        val security = if (!permitted(context)) "Permission missing"
        else "Android Bluetooth security available"
        var bond = "Unverifiable"
        var active = "Not queried"
        if (permitted(context)) {
            try {
                val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter
                val device = adapter?.getRemoteDevice(deviceId)
                if (device != null) {
                    bond = bondLabel(device.bondState)
                    active = queryEncryption(device)
                }
            } catch (_: Exception) {
                active = "Device identity could not be queried"
            }
        }
        return mapOf(
            "securityBond" to bond,
            "securityEncryption" to active,
            "securityEncryptionEvent" to (p.getString("$key.meta_encryptionEvent", "Not observed in this session") ?: "Not observed"),
            "securityGatt" to (p.getString("$key.meta_gatt", "No GATT connection recorded") ?: "Unknown"),
            "securityLastError" to (p.getString("$key.meta_securityError", "None observed") ?: "Unknown"),
            "securityProtocol" to (p.getString("$key.meta_protocol", "Not confirmed") ?: "Not confirmed"),
            "securityNote" to security,
        )
    }
}
