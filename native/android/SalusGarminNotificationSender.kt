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
import java.util.ArrayDeque
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Locally managed Garmin GFDI notification session. No Garmin Connect relay.
 * Keeps one GATT session per watch, queues alerts, reconnects with backoff,
 * and records transport stages. Protocol-acknowledged data is NOT proof of
 * a watch displaying the alert.
 */
object SalusGarminNotificationSender {
    private const val MAX_PENDING = 8
    private const val ATTEMPT_TIMEOUT_MS = 25_000L
    private val serviceUuid = UUID.fromString("6a4e2800-667b-11e3-949a-0800200c9a66")
    private const val SUFFIX = "-667b-11e3-949a-0800200c9a66"
    private val main = Handler(Looper.getMainLooper())
    private val sessions = ConcurrentHashMap<String, Session>()

    private data class Alert(
        val id: Int, val sourcePackage: String, val title: String,
        val text: String, val category: Int, val time: Long,
    )

    private fun permitted(context: Context): Boolean =
        Build.VERSION.SDK_INT < 31 ||
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun session(context: Context, deviceId: String): Session {
        return sessions.computeIfAbsent(deviceId) { Session(context.applicationContext, it) }
    }

    fun watch(context: Context, deviceId: String) = watch(context, deviceId, false)

    fun watch(context: Context, deviceId: String, promptBond: Boolean) {
        if (deviceId.isBlank()) return
        val s = session(context, deviceId)
        main.post { if (promptBond) s.allowBondRetry(); s.start(promptBond) }
    }

    fun unwatch(deviceId: String) {
        val s = sessions.remove(deviceId) ?: return
        main.post { s.stop() }
    }

    fun stopAll() {
        val list = sessions.values.toList()
        sessions.clear()
        main.post { list.forEach { it.stop() } }
    }

    fun send(context: Context, target: SalusWatchNotificationStore.Target, sbn: StatusBarNotification) {
        if (target.protocolId != "garmin-family") return
        val extras = sbn.notification.extras
        val alert = Alert(
            sbn.key.hashCode(), sbn.packageName,
            extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty(),
            (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty(),
            category(sbn.notification.category), sbn.postTime,
        )
        val s = session(context, target.deviceId)
        main.post { s.offer(alert) }
    }

    /** Explicit local protocol test. Does not post a synthetic Android notification. */
    fun test(context: Context, deviceId: String) {
        val now = System.currentTimeMillis()
        val alert = Alert(now.toInt(), context.packageName, "Salus test",
            "Direct Bluetooth notification test from Salus", 0, now)
        val s = session(context, deviceId)
        main.post { s.allowBondRetry(); s.start(true); s.offer(alert) }
    }

    private fun category(value: String?): Int = when (value) {
        Notification.CATEGORY_CALL -> 1
        Notification.CATEGORY_EMAIL -> 6
        Notification.CATEGORY_MESSAGE -> 12
        else -> 0
    }

    private class Session(private val app: Context, private val deviceId: String) {
        private val outgoing = ArrayDeque<ByteArray>()
        private val pending = ArrayDeque<Alert>()
        private val incoming = ByteArrayOutputStream()
        private var current: Alert? = null
        private var gatt: BluetoothGatt? = null
        private var rx: BluetoothGattCharacteristic? = null
        private var tx: BluetoothGattCharacteristic? = null
        private var writing = false
        private var handle = 0
        private var registered = false
        private val bondManager = SalusSafeBondManager(app)
        private var bonding = false
        private var bondDenied = false
        private var configurationExchanged = false
        private var informationExchanged = false
        private var subscribed = false
        private var subscriptionSeen = false
        private var enabled = true
        private var connecting = false
        private var attemptId = 0
        private var retryCount = 0
        private var mtuPayload = 19
        private var updateSent = false
        private var registrationSent = false
        private val notificationTransfer = SalusGarminNotificationTransfer()
        private var dataAckToken = 0

        private fun stage(code: String, detail: String = "") =
            SalusWatchTransportStatus.mark(app, deviceId, code, detail)

        fun allowBondRetry() { bondDenied = false }

        fun start(promptBond: Boolean = false) {
            if (!enabled) return
            if (gatt != null || connecting) return
            if (!permitted(app)) {
                stage("Bluetooth permission missing", "Grant Nearby devices / Bluetooth access")
                return
            }
            val adapter = app.getSystemService(BluetoothManager::class.java)?.adapter
            if (adapter == null || !adapter.isEnabled) {
                stage("Bluetooth unavailable", "Enable Bluetooth on the phone")
                return
            }
            val device = try { adapter.getRemoteDevice(deviceId) } catch (_: Throwable) {
                stage("Invalid device address", "Rescan and reconnect this watch")
                return
            }
            // The user's opt-in to watch notifications permits OS-managed pairing.
            // Never invent keys or attempt application crypto as a bonding substitute.
            val bonded = try { device.bondState == BluetoothDevice.BOND_BONDED }
                catch (_: SecurityException) { false }
            if (!bonded) {
                if (bondDenied || !promptBond) {
                    stage("Pairing required", "Open Watch Settings and enable notifications or send a test to confirm Android pairing")
                    return
                }
                if (bonding) return
                bonding = true
                stage("Pairing", "Waiting for Android to confirm a secure watch bond")
                bondManager.ensureBonded(device) { ok, detail ->
                    bonding = false
                    if (!enabled) return@ensureBonded
                    if (ok) {
                        stage("Bonded", detail)
                        start(false)
                    } else {
                        bondDenied = true
                        stage("Pairing failed", detail)
                    }
                }
                return
            }
            connecting = true
            val id = ++attemptId
            stage("Connecting", "Opening direct Garmin Bluetooth connection")
            try {
                @SuppressLint("MissingPermission")
                val opened = if (Build.VERSION.SDK_INT >= 23)
                    device.connectGatt(app, false, callback, BluetoothDevice.TRANSPORT_LE)
                else device.connectGatt(app, false, callback)
                gatt = opened
                if (opened == null) fail("Connection failed", "Android returned no GATT session")
            } catch (error: Throwable) {
                fail("Connection failed", error.javaClass.simpleName)
            }
            main.postDelayed({
                if (enabled && id == attemptId && !registered) {
                    fail("Connection timeout", "Garmin session did not register GFDI within 25 seconds")
                }
            }, ATTEMPT_TIMEOUT_MS)
        }

        fun offer(alert: Alert) {
            if (!enabled) return
            if (pending.size >= MAX_PENDING) pending.removeFirst()
            pending.addLast(alert)
            if (subscriptionSeen && !subscribed) {
                stage("Watch notifications off", "${pending.size} alert(s) waiting. On Garmin: Settings > Connectivity > Phone > Notifications > Status > On")
            } else {
                stage("Queued", "${pending.size} alert(s) waiting for Garmin protocol")
            }
            if (gatt == null) start()
            maybeSend()
        }

        fun stop() {
            enabled = false
            ++attemptId
            bondManager.cancel(); bonding = false
            disconnect()
            outgoing.clear(); pending.clear(); current = null
            notificationTransfer.reset(); ++dataAckToken
            stage("Off", "Notification forwarding disabled")
        }

        @SuppressLint("MissingPermission")
        private fun disconnect() {
            val old = gatt
            gatt = null; rx = null; tx = null
            connecting = false; writing = false
            handle = 0; registered = false; subscribed = false; subscriptionSeen = false
            registrationSent = false; updateSent = false
            configurationExchanged = false; informationExchanged = false
            outgoing.clear(); incoming.reset()
            notificationTransfer.reset(); ++dataAckToken
            try { old?.disconnect() } catch (_: Throwable) {}
            try { old?.close() } catch (_: Throwable) {}
        }

        private fun fail(code: String, detail: String) {
            if (!enabled) return
            stage(code, detail)
            ++attemptId
            disconnect()
            // Keep the in-flight alert, but don't queue unlimited duplicates.
            current?.let { if (pending.size < MAX_PENDING) pending.addFirst(it) }
            current = null
            retryCount++
            val delayMs = minOf(60_000L, 2_000L * (1L shl minOf(retryCount, 5)))
            main.postDelayed({ if (enabled && gatt == null) start() }, delayMs)
        }

        private val callback = object : BluetoothGattCallback() {
            @SuppressLint("MissingPermission")
            override fun onConnectionStateChange(g: BluetoothGatt, status: Int, state: Int) {
                main.post {
                    if (!enabled || gatt !== g) return@post
                    if (status == BluetoothGatt.GATT_SUCCESS && state == BluetoothProfile.STATE_CONNECTED) {
                        connecting = false
                        stage("Bluetooth connected", "Discovering Garmin GFDI services")
                        if (!g.discoverServices()) fail("Service discovery failed", "Android refused discoverServices")
                    } else if (state == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) {
                        fail("Bluetooth disconnected", "GATT status=$status; state=$state")
                    }
                }
            }

            @SuppressLint("MissingPermission")
            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                main.post {
                    if (!enabled || gatt !== g) return@post
                    if (status != BluetoothGatt.GATT_SUCCESS || !setupGatt(g)) {
                        fail("Garmin transport unavailable", "GFDI notify/write characteristics could not be opened")
                    }
                }
            }

            override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) {
                main.post { if (status == BluetoothGatt.GATT_SUCCESS) mtuPayload = (mtu - 4).coerceIn(19, 244) }
            }

            override fun onDescriptorWrite(g: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
                main.post {
                    if (!enabled || gatt !== g) return@post
                    if (status == BluetoothGatt.GATT_SUCCESS) beginHandshake()
                    else fail("Subscribe failed", "Descriptor write status=$status")
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
                onChanged(g, c.uuid, c.value?.clone() ?: return)
            }

            override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) {
                onChanged(g, c.uuid, value.clone())
            }

            override fun onCharacteristicWrite(g: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int) {
                main.post {
                    if (!enabled || gatt !== g) return@post
                    if (status != BluetoothGatt.GATT_SUCCESS) fail("Bluetooth write failed", "GATT status=$status")
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
                    stage("GFDI discovered", "Found Garmin Multi-Link receive/send characteristics")
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
            if (registrationSent) return
            stage("GFDI initializing", "Closing previous Garmin handles and registering GFDI")
            enqueue(SalusGarminGfdiCodec.closeAll())
            main.postDelayed({ if (enabled && !registered) registerGfdi() }, 700L)
        }

        private fun registerGfdi() {
            if (registrationSent || !enabled) return
            registrationSent = true
            enqueue(SalusGarminGfdiCodec.registerGfdi())
        }

        private fun enqueue(bytes: ByteArray) {
            if (!enabled) return
            outgoing.addLast(bytes)
            drain()
        }

        @SuppressLint("MissingPermission")
        private fun drain() {
            if (!enabled || writing || outgoing.isEmpty()) return
            val active = gatt ?: return
            val characteristic = tx ?: return
            val packet = outgoing.removeFirst()
            val requiresResponse = characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0
            characteristic.writeType = if (requiresResponse) BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                else BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            @Suppress("DEPRECATION")
            characteristic.value = packet
            writing = true
            @Suppress("DEPRECATION")
            val started = try { active.writeCharacteristic(characteristic) } catch (_: Throwable) { false }
            if (!started) { fail("Bluetooth write rejected", "Android rejected GATT write"); return }
            if (!requiresResponse) main.postDelayed({
                if (enabled && gatt === active && writing) { writing = false; drain() }
            }, 90L)
        }

        private fun sendGfdi(data: ByteArray) {
            if (handle <= 0 || !enabled) return
            val framed = SalusGarminGfdiCodec.cobsEncode(data)
            var offset = 0
            while (offset < framed.size) {
                val amount = minOf(mtuPayload, framed.size - offset)
                enqueue(byteArrayOf(handle.toByte()) + framed.copyOfRange(offset, offset + amount))
                offset += amount
            }
        }

        private fun onChanged(g: BluetoothGatt, characteristic: UUID, bytes: ByteArray) {
            main.post {
                if (!enabled || gatt !== g || characteristic != rx?.uuid || bytes.size < 2) return@post
                val h = bytes[0].toInt() and 255
                if (h == 0) {
                    val type = bytes[1].toInt() and 255
                    if (type == 6) registerGfdi()
                    if (type == 1 && bytes.size >= 14 && SalusGarminGfdiCodec.read16(bytes, 10) == 1) {
                        val status = bytes[12].toInt() and 255
                        if (status == 0) {
                            handle = bytes[13].toInt() and 255
                            registered = handle > 0
                            if (registered) {
                                retryCount = 0
                                stage("GFDI registered", "Waiting for Garmin device-info/configuration exchange")
                                val currentAttempt = attemptId
                                main.postDelayed({
                                    if (enabled && currentAttempt == attemptId && registered && !subscriptionSeen) {
                                        stage("Subscription not received",
                                            "No Garmin 5036 received; device info=${informationExchanged}; config=${configurationExchanged}")
                                    }
                                }, 22_000L)
                                maybeSend()
                            }
                        } else stage("GFDI registration rejected", "Garmin returned status=$status")
                    }
                    return@post
                }
                if (h != handle || handle == 0) return@post
                val part = bytes.copyOfRange(1, bytes.size)
                if (incoming.size() + part.size > 16_384) incoming.reset()
                incoming.write(part)
                val framed = incoming.toByteArray()
                if (framed.size >= 3 && framed.last() == 0.toByte()) {
                    incoming.reset()
                    val decoded = SalusGarminGfdiCodec.cobsDecode(framed) ?: run {
                        stage("GFDI decode error", "Invalid framed packet from Garmin")
                        return@post
                    }
                    val message = SalusGarminGfdiCodec.decodeFrame(decoded) ?: run {
                        stage("GFDI checksum error", "Received invalid Garmin packet")
                        return@post
                    }
                    processGfdi(message.type, message.payload, message.sequence)
                }
            }
        }

        private fun maybeSend() {
            if (!enabled || !registered || !subscribed || updateSent) return
            if (current == null && pending.isNotEmpty()) current = pending.removeFirst()
            val alert = current ?: return
            updateSent = true
            stage("Sending notification", "Watch subscribed; posting Garmin GFDI notification update")
            sendGfdi(SalusGarminGfdiCodec.notificationUpdate(alert.id, alert.category))
            val thisId = alert.id
            main.postDelayed({
                if (enabled && current?.id == thisId && updateSent) {
                    stage("No watch attribute request", "Garmin did not request this notification's text")
                    current = null; updateSent = false
                    maybeSend()
                }
            }, 9000L)
        }

        private fun processGfdi(type: Int, payload: ByteArray, sequence: Int?) {
            when (type) {
                5024 -> {
                    // Gadgetbridge DeviceInformationMessage: ACK followed by detailed response.
                    if (payload.size < 12) {
                        stage("Device-info parse error", "Received truncated Garmin 5024 request")
                        return
                    }
                    informationExchanged = true
                    stage("Garmin device information", "Responding to GFDI device-info request")
                    sendGfdi(SalusGarminGfdiCodec.genericAck(5024, sequence))
                    sendGfdi(SalusGarminGfdiCodec.deviceInformationResponse(payload, sequence))
                }
                5050 -> {
                    // Garmin configuration request gates subscription initialization.
                    if (payload.isEmpty() || (payload[0].toInt() and 255) > payload.size - 1) {
                        stage("Configuration parse error", "Garmin 5050 capabilities are incomplete")
                        return
                    }
                    configurationExchanged = true
                    stage("Garmin configuration", "Sending our supported device capabilities")
                    sendGfdi(SalusGarminGfdiCodec.genericAck(5050, sequence))
                    sendGfdi(SalusGarminGfdiCodec.configurationResponse())
                    sendGfdi(SalusGarminGfdiCodec.syncReady())
                    stage("Garmin startup answered", "Device-information/configuration status: ${informationExchanged}/${configurationExchanged}")
                }
                5052 -> if (payload.size >= 4) {
                    stage("Garmin time request", "Answering watch time request")
                    sendGfdi(SalusGarminGfdiCodec.currentTimeResponse(SalusGarminGfdiCodec.read32(payload, 0), sequence))
                }
                5101 -> if (payload.size >= 5) {
                    stage("Garmin auth negotiation", "Responding to Garmin application auth negotiation")
                    sendGfdi(SalusGarminGfdiCodec.authNegotiationResponse(payload, sequence))
                }
                5043 -> {
                    // Protobuf requests arrive in Garmin's compact sequenced GFDI header.
                    // Match the transaction sequence while acknowledging their transport.
                    // Feature-specific protobuf responses still require a registered handler.
                    if (payload.size >= 14) {
                        val requestId = SalusGarminGfdiCodec.read16(payload, 0)
                        val offset = SalusGarminGfdiCodec.read32(payload, 2)
                        val total = SalusGarminGfdiCodec.read32(payload, 6)
                        val fragmentSize = SalusGarminGfdiCodec.read32(payload, 10)
                        val withinBounds = total >= 0 && offset >= 0 && fragmentSize >= 0 &&
                            fragmentSize <= payload.size - 14 && offset.toLong() + fragmentSize <= total
                        if (withinBounds && offset == 0 && total == fragmentSize) {
                            sendGfdi(SalusGarminGfdiCodec.genericAck(5043, sequence))
                        } else if (withinBounds) {
                            sendGfdi(SalusGarminGfdiCodec.protobufChunkAck(5043, requestId, offset, sequence))
                            if (!subscribed) stage("Garmin protobuf chunk", "Request=$requestId, offset=$offset, bytes=$fragmentSize/$total")
                        } else {
                            stage("Garmin protobuf parse error", "Invalid request=$requestId, offset=$offset, size=$fragmentSize/$total")
                        }
                    } else stage("Garmin protobuf parse error", "GFDI 5043 payload too short")
                }
                5036 -> if (payload.size >= 2) {
                    // The watch has sent 5036: an off request is NOT a missing request.
                    // The phone's approval flag must not mirror the watch's off state.
                    subscriptionSeen = true
                    val enabledOnWatch = (payload[0].toInt() and 255) == 1
                    val hostAllowed = SalusWatchNotificationStore.targets(app).any {
                        it.deviceId.equals(deviceId, ignoreCase = true) && it.protocolId == "garmin-family"
                    }
                    subscribed = enabledOnWatch && hostAllowed
                    sendGfdi(SalusGarminGfdiCodec.notificationSubscriptionResponse(
                        enabledOnWatch, hostAllowed, sequence))
                    if (enabledOnWatch) {
                        stage(if (hostAllowed) "Watch subscribed" else "Salus notifications off",
                            "Garmin requested subscription on; phone permission=${if (hostAllowed) "on" else "off"}")
                    } else {
                        stage("Watch notifications off",
                            "Garmin sent subscription off; phone permission=${if (hostAllowed) "on" else "off"}. On watch: Settings > Connectivity > Phone > Notifications > Status > On")
                    }
                    if (subscribed) maybeSend()
                }
                5034 -> if (payload.size >= 5 && payload[0].toInt() == 0) {
                    val requested = SalusGarminGfdiCodec.read32(payload, 1)
                    sendGfdi(SalusGarminGfdiCodec.notificationControlAck(sequence))
                    val alert = current
                    if (alert != null && requested == alert.id) {
                        stage("Watch requested content", "Garmin requested notification attributes")
                        sendAttributes(alert, payload.copyOfRange(5, payload.size))
                    }
                }
                5000 -> if (payload.size >= 4 && SalusGarminGfdiCodec.read16(payload, 0) == 5035) {
                    val status = payload[2].toInt() and 255
                    val transferStatus = payload[3].toInt() and 255
                    when (val ack = notificationTransfer.acknowledge(status, transferStatus)) {
                        is SalusGarminNotificationTransfer.Ack.Next -> {
                            ++dataAckToken // invalidates the timeout for the previous chunk
                            stage("Garmin acknowledged data chunk", "Sending the next requested notification-data chunk")
                            sendNextAttributeChunk(ack.chunk)
                        }
                        SalusGarminNotificationTransfer.Ack.Complete -> {
                            ++dataAckToken
                            // Gadgetbridge sends a final 5035 ACK after Garmin accepts the last chunk.
                            sendGfdi(SalusGarminGfdiCodec.notificationDataAck(sequence))
                            stage("Garmin accepted notification data",
                                "Watch acknowledged all 5035 data chunks; on-screen display still unverified")
                            current = null; updateSent = false
                            main.postDelayed({ maybeSend() }, 250L)
                        }
                        is SalusGarminNotificationTransfer.Ack.Rejected -> {
                            ++dataAckToken
                            stage("Garmin rejected notification data",
                                "GFDI status=${ack.protocolStatus}, transfer=${ack.transferStatus}; no display confirmed")
                            current = null; updateSent = false
                            main.postDelayed({ maybeSend() }, 250L)
                        }
                        SalusGarminNotificationTransfer.Ack.Unexpected -> {
                            stage("Unmatched Garmin data ACK", "GFDI 5035 response received without an active transfer")
                        }
                    }
                }
                else -> {
                    // No silent unsupported Garmin protocol messages during initialization.
                    if (!subscribed) stage("Garmin protocol message", "Received GFDI type $type; no handler installed")
                }
            }
        }

        private fun sendAttributes(alert: Alert, request: ByteArray) {
            val encoded = SalusGarminNotificationAttributes.build(
                alert.id,
                alert.sourcePackage,
                alert.title.ifBlank { alert.sourcePackage.substringAfterLast('.') },
                "",
                alert.text,
                SalusGarminGfdiCodec.timestamp(alert.time),
                request,
            )
            if (encoded == null) {
                stage("Garmin attribute request unsupported", "Watch requested a malformed or unknown attribute; do not fabricate payload")
                notificationTransfer.reset()
                current = null; updateSent = false
                main.postDelayed({ maybeSend() }, 250L)
                return
            }
            stage("Garmin attributes encoded",
                "Requested attribute IDs=${encoded.requestedIds.joinToString(",")}; " +
                    "serialized bytes=${encoded.bytes.size}; Gadgetbridge ordering applied")
            notificationTransfer.begin(encoded.bytes).let { sendNextAttributeChunk(it) }
        }

        private fun sendNextAttributeChunk(chunk: SalusGarminNotificationTransfer.Chunk) {
            if (!enabled || current == null) return
            sendGfdi(SalusGarminGfdiCodec.notificationData(chunk.bytes, chunk.total,
                chunk.offset, chunk.crc))
            stage("Notification data awaiting Garmin ACK",
                "GFDI 5035 chunk ${chunk.offset + chunk.bytes.size}/${chunk.total} queued; waiting for Garmin 5000/5035 response")
            val token = ++dataAckToken
            val expectedNotificationId = current?.id
            val expectedAttempt = attemptId
            main.postDelayed({
                if (enabled && token == dataAckToken && expectedAttempt == attemptId &&
                    current?.id == expectedNotificationId && notificationTransfer.awaitingAck) {
                    notificationTransfer.reset()
                    ++dataAckToken
                    stage("Garmin notification ACK timeout",
                        "Watch did not acknowledge GFDI 5035 data within 10 seconds; display unverified")
                    current = null; updateSent = false
                    main.postDelayed({ maybeSend() }, 250L)
                }
            }, 10_000L)
        }
    }
}
