package com.rustnrum.healthyme.beta03

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper

/**
 * Android-managed, device-scoped BLE bonding. NEVER implements keys, PINs or crypto.
 * Call only after the user approves pairing this particular wearable.
 * Callback runs on the main looper. Each invocation is independent and bounded.
 */
class SalusSafeBondManager(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private var receiver: BroadcastReceiver? = null
    private var timeout: Runnable? = null

    @SuppressLint("MissingPermission")
    fun ensureBonded(device: BluetoothDevice, callback: (Boolean, String) -> Unit) {
        cancel()
        if (Build.VERSION.SDK_INT >= 31 &&
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
            callback(false, "Nearby devices permission missing")
            return
        }
        val address = try { device.address } catch (e: SecurityException) {
            callback(false, "Bluetooth permission denied")
            return
        }
        try {
            if (device.bondState == BluetoothDevice.BOND_BONDED) {
                callback(true, "Bond already exists")
                return
            }
        } catch (e: SecurityException) {
            callback(false, "Cannot read Bluetooth bond state")
            return
        }
        val listener = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, intent: Intent?) {
                if (intent?.action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return
                @Suppress("DEPRECATION")
                val changed = if (Build.VERSION.SDK_INT >= 33)
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                else intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                if (changed?.address != address) return // another device's bond transition
                val state = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
                val previous = intent.getIntExtra(BluetoothDevice.EXTRA_PREVIOUS_BOND_STATE, BluetoothDevice.ERROR)
                if (state == BluetoothDevice.BOND_BONDED) {
                    cancel()
                    callback(true, "Android confirmed BOND_BONDED")
                } else if (state == BluetoothDevice.BOND_NONE && previous == BluetoothDevice.BOND_BONDING) {
                    cancel()
                    callback(false, "Pairing declined or failed")
                }
            }
        }
        receiver = listener
        try {
            val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            if (Build.VERSION.SDK_INT >= 33) {
                // Bluetooth stack broadcasts may originate from a privileged non-system UID.
                context.registerReceiver(listener, filter, Context.RECEIVER_EXPORTED)
            } else context.registerReceiver(listener, filter)
            val expiry = Runnable {
                cancel()
                callback(false, "Timed out waiting for Bluetooth pairing")
            }
            timeout = expiry
            main.postDelayed(expiry, 60_000L)
            if (device.bondState == BluetoothDevice.BOND_NONE && !device.createBond()) {
                cancel()
                callback(false, "Android could not start pairing")
            }
            // BOND_BONDING already in progress: only listen for completion.
        } catch (e: SecurityException) {
            cancel()
            callback(false, "Bluetooth pairing permission denied")
        } catch (e: RuntimeException) {
            cancel()
            callback(false, "Could not register Bluetooth pairing listener: ${e.javaClass.simpleName}")
        }
    }

    fun cancel() {
        timeout?.let { main.removeCallbacks(it) }; timeout = null
        receiver?.let { try { context.unregisterReceiver(it) } catch (_: IllegalArgumentException) {} }
        receiver = null
    }
}
