package com.rustnrum.healthyme.beta03

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.notification.StatusBarNotification
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.ArrayDeque
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/** Direct, best-effort Garmin Multi-Link v2 sender. No Garmin Connect or external app.
 * Salus recognizes connection, GFDI registration, and attribute requests separately.
 * BLE writes do NOT constitute confirmation that an alert was displayed on a watch.
 * Wire format based on publicly documented Garmin protocol and Gadgetbridge sources.
 */
object SalusGarminNotificationSender {
    private val serviceUuid = UUID.fromString("6a4e2800-667b-11e3-949a-0800200c9a66")
    private const val SUFFIX = "-667b-11e3-949a-0800200c9a66"
    private const val TIMEOUT_MS = 27000L

    @SuppressLint("MissingPermission")
    fun send(context: Context, target: SalusWatchNotificationStore.Target, sbn: StatusBarNotification) {
        if (target.protocolId != "garmin-family") return
        if (Build.VERSION.SDK_INT >= 31 &&
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) return
        val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter ?: return
        if (!adapter.isEnabled) return
        val device = try { adapter.getRemoteDevice(target.deviceId) } catch (_: Throwable) { return }
        Session(context.applicationContext, sbn).start(device)
    }

    private class Session(private val app: Context, private val sbn: StatusBarNotification) {
        private val handler = Handler(Looper.getMainLooper())
        private val finished = AtomicBoolean(false)
        private val outgoing = ArrayDeque<ByteArray>()
        private val incoming = ByteArrayOutputStream()
        private var gatt: BluetoothGatt? = null
        private var tx: BluetoothGattCharacteristic? = null
        private var rx: BluetoothGattCharacteristic? = null
        private var writing = false
        private var handle = 0
        private var updateSent = false
        private var subscribed = false
        private var gfdiRegistered = false
        private var mtuPayload = 19
        private val notificationId = sbn.key.hashCode()
        private val title = sbn.notification.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        private val text = (sbn.notification.extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: sbn.notification.extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()

        @SuppressLint("MissingPermission")
        fun start(device: BluetoothDevice) {
            handler.postDelayed({ close() }, TIMEOUT_MS)
            handler.post {
                if (finished.get()) return@post
                try {
                    gatt = if (Build.VERSION.SDK_INT >= 23)
                        device.connectGatt(app, false, callback, BluetoothDevice.TRANSPORT_LE)
                    else device.connectGatt(app, false, callback)
                } catch (_: Throwable) { close() }
            }
        }

        @SuppressLint("MissingPermission")
        private fun close() {
            if (!finished.compareAndSet(false, true)) return
            val active = gatt
            try { active?.disconnect() } catch (_: Throwable) {}
            try { active?.close() } catch (_: Throwable) {}
            outgoing.clear()
            incoming.reset()
        }

        private val callback = object : BluetoothGattCallback() {
            @SuppressLint("MissingPermission")
            override fun onConnectionStateChange(g: BluetoothGatt, status: Int, state: Int) {
                handler.post {
                    if (finished.get()) return@post
                    gatt = g
                    if (status == BluetoothGatt.GATT_SUCCESS && state == BluetoothProfile.STATE_CONNECTED) {
                        if (!g.discoverServices()) close()
                    } else if (state == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) close()
                }
            }

            @SuppressLint("MissingPermission")
            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                handler.post { if (!finished.get()) {
                    if (status != BluetoothGatt.GATT_SUCCESS || !setupGatt(g)) close()
                }}
            }

            override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) mtuPayload = (mtu - 4).coerceIn(19, 244)
            }

            @SuppressLint("MissingPermission")
            override fun onDescriptorWrite(g: BluetoothGatt, d: BluetoothGattDescriptor, status: Int) {
                handler.post { if (!finished.get()) {
                    if (status != BluetoothGatt.GATT_SUCCESS) close()
                    else beginHandshake()
                }}
            }

            @Deprecated("Deprecated in Java")
            override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
                onChanged(c.uuid, c.value?.clone() ?: return)
            }

            override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) {
                onChanged(c.uuid, value.clone())
            }

            @SuppressLint("MissingPermission")
            override fun onCharacteristicWrite(g: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int) {
                handler.post {
                    if (finished.get()) return@post
                    if (status != BluetoothGatt.GATT_SUCCESS) close()
                    else { writing = false; drain() }
                }
            }
        }

        @SuppressLint("MissingPermission")
        private fun setupGatt(g: BluetoothGatt): Boolean {
            val service: BluetoothGattService = g.getService(serviceUuid) ?: return false
            for (i in 0x2810..0x2814) {
                val receive = service.getCharacteristic(UUID.fromString("6a4e${i.toString(16)}$SUFFIX"))
                val send = service.getCharacteristic(UUID.fromString("6a4e${(i + 0x10).toString(16)}$SUFFIX"))
                if (receive != null && send != null &&
                    receive.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0 &&
                    send.properties and (BluetoothGattCharacteristic.PROPERTY_WRITE or
                        BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0) {
                    rx = receive; tx = send
                    if (!g.setCharacteristicNotification(receive, true)) return false
                    val descriptor = receive.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
                    if (descriptor != null) {
                        @Suppress("DEPRECATION")
                        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        @Suppress("DEPRECATION")
                        if (!g.writeDescriptor(descriptor)) return false
                    } else beginHandshake()
                    return true
                }
            }
            return false
        }

        private fun beginHandshake() {
            enqueue(SalusGarminGfdiCodec.closeAll())
            // Firmware can omit the CLOSE_ALL response. Attempt GFDI registration
            // once regardless; unsolicited registration replies are still parsed.
            handler.postDelayed({ if (!finished.get() && !gfdiRegistered) registerGfdi() }, 700L)
        }

        private var registrationSent = false
        private fun registerGfdi() {
            if (registrationSent || finished.get()) return
            registrationSent = true
            enqueue(SalusGarminGfdiCodec.registerGfdi())
        }

        private fun enqueue(bytes: ByteArray) {
            if (finished.get()) return
            outgoing.addLast(bytes)
            drain()
        }

        @SuppressLint("MissingPermission")
        private fun drain() {
            if (finished.get() || writing || outgoing.isEmpty()) return
            val active = gatt ?: return
            val characteristic = tx ?: return
            val bytes = outgoing.removeFirst()
            val response = characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0
            characteristic.writeType = if (response) BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                else BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            @Suppress("DEPRECATION")
            characteristic.value = bytes
            writing = true
            @Suppress("DEPRECATION")
            val began = try { active.writeCharacteristic(characteristic) } catch (_: Throwable) { false }
            if (!began) { close(); return }
            if (!response) handler.postDelayed({ writing = false; drain() }, 90L)
        }

        private fun sendGfdi(bytes: ByteArray) {
            if (handle <= 0 || finished.get()) return
            val framed = SalusGarminGfdiCodec.cobsEncode(bytes)
            var pos = 0
            while (pos < framed.size) {
                val amount = minOf(mtuPayload, framed.size - pos)
                enqueue(byteArrayOf(handle.toByte()) + framed.copyOfRange(pos, pos + amount))
                pos += amount
            }
        }

        private fun onChanged(characteristic: UUID, bytes: ByteArray) {
            handler.post {
                if (finished.get() || characteristic != rx?.uuid || bytes.size < 2) return@post
                val h = bytes[0].toInt() and 255
                if (h == 0) {
                    // REGISTER_ML_RESP: service at 10/11, status at 12, handle at 13.
                    val type = bytes[1].toInt() and 255
                    if (type == 6) registerGfdi()
                    if (type == 1 && bytes.size >= 14 && SalusGarminGfdiCodec.read16(bytes, 10) == 1) {
                        if (bytes[12].toInt() == 0) {
                            handle = bytes[13].toInt() and 255
                            gfdiRegistered = handle > 0
                            if (gfdiRegistered) handler.postDelayed({ sendUpdate() }, 250L)
                        }
                    }
                    return@post
                }
                if (h != handle || handle == 0) return@post
                val fragment = bytes.copyOfRange(1, bytes.size)
                // COBS starts with 0 and ends with 0; fragments are not packets.
                if (incoming.size() + fragment.size > 16384) incoming.reset()
                incoming.write(fragment)
                val data = incoming.toByteArray()
                if (data.size >= 3 && data.last().toInt() == 0) {
                    incoming.reset()
                    val unwrapped = SalusGarminGfdiCodec.cobsDecode(data) ?: return@post
                    val decoded = SalusGarminGfdiCodec.decodeGfdi(unwrapped) ?: return@post
                    processGfdi(decoded.first, decoded.second)
                }
            }
        }

        private fun sendUpdate() {
            if (!gfdiRegistered || updateSent || finished.get()) return
            updateSent = true
            val category = when (sbn.notification.category) {
                Notification.CATEGORY_CALL -> 1
                Notification.CATEGORY_EMAIL -> 6
                Notification.CATEGORY_MESSAGE -> 12
                else -> 0
            }
            sendGfdi(SalusGarminGfdiCodec.notificationUpdate(notificationId, category))
        }

        private fun processGfdi(type: Int, payload: ByteArray) {
            when (type) {
                5036 -> { // Subscription request from watch
                    if (payload.size >= 2) {
                        subscribed = payload[0].toInt() == 1
                        sendGfdi(SalusGarminGfdiCodec.notificationSubscriptionResponse(subscribed, payload[1].toInt() and 255))
                        if (subscribed) sendUpdate()
                    }
                }
                5034 -> { // GET_NOTIFICATION_ATTRIBUTES from watch
                    if (payload.size >= 5 && payload[0].toInt() == 0) {
                        val id = SalusGarminGfdiCodec.read32(payload, 1)
                        sendGfdi(SalusGarminGfdiCodec.notificationControlAck())
                        if (id == notificationId) sendAttributes(id, payload.copyOfRange(5, payload.size))
                    }
                }
                5000 -> { // Notification data transfer progress
                    if (payload.size >= 4 && SalusGarminGfdiCodec.read16(payload, 0) == 5035) {
                        if (payload[2].toInt() == 0 && payload[3].toInt() == 0) sendNextAttributeChunk()
                    }
                }
            }
        }

        private var attributeBytes = byteArrayOf()
        private var attributeOffset = 0
        private var runningCrc = 0

        private fun sendAttributes(id: Int, request: ByteArray) {
            val titleOrApp = title.ifBlank { sbn.packageName.substringAfterLast('.') }
            val options = linkedMapOf(
                0 to sbn.packageName,
                1 to titleOrApp,
                2 to "",
                3 to text,
                4 to text.length.toString(),
                5 to SalusGarminGfdiCodec.timestamp(sbn.postTime),
            )
            val requested = mutableListOf<Pair<Int, String>>()
            var i = 0
            while (i < request.size) {
                val kind = request[i++].toInt() and 255
                var maxLen = 255
                if (kind in 1..3 || kind == 7) {
                    if (i + 2 > request.size) break
                    maxLen = SalusGarminGfdiCodec.read16(request, i).coerceIn(0, 255)
                    i += 2
                } else if (kind == 127) {
                    if (i + 3 > request.size) break
                    i += 3
                }
                val value = options[kind] ?: ""
                requested.add(kind to value.take(maxLen))
            }
            attributeBytes = SalusGarminGfdiCodec.notificationAttributes(id, requested)
            attributeOffset = 0
            runningCrc = 0
            sendNextAttributeChunk()
        }

        private fun sendNextAttributeChunk() {
            if (attributeOffset >= attributeBytes.size || finished.get()) return
            val end = minOf(attributeOffset + 200, attributeBytes.size)
            val piece = attributeBytes.copyOfRange(attributeOffset, end)
            runningCrc = SalusGarminGfdiCodec.crc(piece, runningCrc)
            sendGfdi(SalusGarminGfdiCodec.notificationData(piece, attributeBytes.size, attributeOffset, runningCrc))
            attributeOffset = end
        }
    }
}
