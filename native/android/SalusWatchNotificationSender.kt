package com.rustnrum.healthyme.beta03

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.notification.StatusBarNotification
import java.util.ArrayDeque
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

object SalusWatchNotificationSender {
    private val IDO_SERVICE =
        UUID.fromString("00000af0-0000-1000-8000-00805f9b34fb")
    private val IDO_WRITE =
        UUID.fromString("00000af6-0000-1000-8000-00805f9b34fb")
    private const val CHUNK_SIZE = 16
    private const val CHUNK_DELAY_MS = 150L

    @SuppressLint("MissingPermission")
    fun send(
        context: Context,
        target: SalusWatchNotificationStore.Target,
        sbn: StatusBarNotification,
    ) {
        if (target.protocolId != "ido-veryfit-family") return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val manager =
            context.getSystemService(BluetoothManager::class.java) ?: return
        val adapter = manager.adapter ?: return
        if (!adapter.isEnabled) return

        val device = try {
            adapter.getRemoteDevice(target.deviceId)
        } catch (_: Throwable) {
            return
        }

        val packets = buildPackets(sbn)
        if (packets.isEmpty()) return

        val handler = Handler(Looper.getMainLooper())
        val completed = AtomicBoolean(false)
        var gattRef: BluetoothGatt? = null
        var writeCharacteristic: BluetoothGattCharacteristic? = null
        val queue = ArrayDeque<ByteArray>(packets)

        fun finish() {
            if (!completed.compareAndSet(false, true)) return
            try {
                gattRef?.disconnect()
            } catch (_: Throwable) {
            }
            try {
                gattRef?.close()
            } catch (_: Throwable) {
            }
        }

        fun writeNext() {
            if (completed.get()) return
            val gatt = gattRef ?: return
            val characteristic = writeCharacteristic ?: return
            val packet = queue.pollFirst() ?: run {
                finish()
                return
            }

            val canWriteWithResponse =
                characteristic.properties and
                    BluetoothGattCharacteristic.PROPERTY_WRITE != 0
            val noResponse =
                !canWriteWithResponse &&
                    characteristic.properties and
                    BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0

            if (!canWriteWithResponse && !noResponse) {
                finish()
                return
            }

            @Suppress("DEPRECATION")
            characteristic.value = packet
            characteristic.writeType =
                if (noResponse) {
                    BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                } else {
                    BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                }

            @Suppress("DEPRECATION")
            val started = try {
                gatt.writeCharacteristic(characteristic)
            } catch (_: Throwable) {
                false
            }
            if (!started) {
                finish()
                return
            }

            if (noResponse) {
                handler.postDelayed({ writeNext() }, CHUNK_DELAY_MS)
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
                    if (!gatt.discoverServices()) finish()
                } else if (
                    newState == BluetoothProfile.STATE_DISCONNECTED ||
                    status != BluetoothGatt.GATT_SUCCESS
                ) {
                    finish()
                }
            }

            override fun onServicesDiscovered(
                gatt: BluetoothGatt,
                status: Int,
            ) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    finish()
                    return
                }
                val service: BluetoothGattService =
                    gatt.getService(IDO_SERVICE) ?: run {
                        finish()
                        return
                    }
                writeCharacteristic =
                    service.getCharacteristic(IDO_WRITE) ?: run {
                        finish()
                        return
                    }
                writeNext()
            }

            @Deprecated("Deprecated in Java")
            override fun onCharacteristicWrite(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    finish()
                    return
                }
                handler.postDelayed({ writeNext() }, CHUNK_DELAY_MS)
            }
        }

        try {
            gattRef =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    device.connectGatt(
                        context,
                        false,
                        callback,
                        BluetoothDevice.TRANSPORT_LE,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    device.connectGatt(context, false, callback)
                }
        } catch (_: Throwable) {
            finish()
            return
        }

        handler.postDelayed({ finish() }, 15000L)
    }

    private fun buildPackets(sbn: StatusBarNotification): List<ByteArray> {
        val notification = sbn.notification
        val extras = notification.extras
        val title =
            extras.getCharSequence(Notification.EXTRA_TITLE)
                ?.toString()
                ?.trim()
                .orEmpty()
        val bigText =
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?.toString()
                ?.trim()
                .orEmpty()
        val normalText =
            extras.getCharSequence(Notification.EXTRA_TEXT)
                ?.toString()
                ?.trim()
                .orEmpty()
        val text = if (bigText.isNotEmpty()) bigText else normalText

        if (notification.category == Notification.CATEGORY_CALL) {
            return callPackets(title.ifEmpty { "Incoming call" })
        }

        if (title.isEmpty() && text.isEmpty()) return emptyList()
        return messagePackets(
            type = typeForPackage(sbn.packageName),
            sender = title.ifEmpty { appFallbackName(sbn.packageName) },
            message = text.ifEmpty { title },
        )
    }

    private fun callPackets(sender: String): List<ByteArray> {
        val senderBytes = utf8(sender, 20)
        val payload = mutableListOf<Byte>()
        payload.add(0)
        payload.add(senderBytes.size.toByte())
        payload.addAll(senderBytes.toList())
        return chunk(0x05, 0x01, payload.toByteArray())
    }

    private fun messagePackets(
        type: Int,
        sender: String,
        message: String,
    ): List<ByteArray> {
        val senderBytes = utf8(sender, 20)
        val textBytes = utf8(message, 60)
        val payload = mutableListOf<Byte>()
        payload.add(type.toByte())
        payload.add(textBytes.size.toByte())
        payload.add(0)
        payload.add(senderBytes.size.toByte())
        payload.addAll(senderBytes.toList())
        payload.addAll(textBytes.toList())
        return chunk(0x05, 0x03, payload.toByteArray())
    }

    private fun chunk(
        command: Int,
        key: Int,
        raw: ByteArray,
    ): List<ByteArray> {
        val total = ((raw.size + CHUNK_SIZE - 1) / CHUNK_SIZE)
            .coerceAtLeast(1)
        val result = mutableListOf<ByteArray>()
        for (index in 0 until total) {
            val packet = ByteArray(4 + CHUNK_SIZE)
            packet[0] = command.toByte()
            packet[1] = key.toByte()
            packet[2] = total.toByte()
            packet[3] = (index + 1).toByte()

            val start = index * CHUNK_SIZE
            val end = minOf(start + CHUNK_SIZE, raw.size)
            if (start < end) {
                raw.copyInto(packet, 4, start, end)
            }
            result.add(packet)
        }
        return result
    }

    private fun utf8(value: String, maxBytes: Int): ByteArray {
        val bytes = value.toByteArray(Charsets.UTF_8)
        if (bytes.size <= maxBytes) return bytes

        var end = maxBytes
        while (end > 0 &&
            (bytes[end].toInt() and 0xC0) == 0x80
        ) {
            end -= 1
        }
        return bytes.copyOfRange(0, end.coerceAtLeast(1))
    }

    private fun typeForPackage(packageName: String): Int =
        when (packageName) {
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging" -> 1
            "com.google.android.gm",
            "com.microsoft.office.outlook" -> 2
            "com.snapchat.android" -> 4
            "com.facebook.katana" -> 6
            "com.twitter.android" -> 7
            "com.whatsapp" -> 8
            "com.facebook.orca" -> 9
            "com.instagram.android" -> 10
            "com.linkedin.android" -> 11
            "com.google.android.calendar",
            "com.samsung.android.calendar" -> 12
            "com.skype.raider" -> 13
            else -> 2
        }

    private fun appFallbackName(packageName: String): String =
        packageName.substringAfterLast('.').replaceFirstChar {
            if (it.isLowerCase()) it.titlecase() else it.toString()
        }
}
