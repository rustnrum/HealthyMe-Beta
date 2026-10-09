"""Salus Build 54: guarded Build-53 -> Build-54 Garmin protocol migration.

Runs inside the existing GitHub Actions update workflow, before copying native
sources into Android. Every replacement must match exactly once; fail closed
if the repository has changed instead of silently patching the wrong build.
"""
from pathlib import Path

# This is an upgrade migrator, not a recurring source rewrite. GitHub Actions
# commits the patched sources; subsequent builds should not reapply old diffs.
if 'version: 0.21.15+53' not in Path('pubspec.yaml').read_text():
    print('Salus Build 54 migration not applicable; preserving current source')
    raise SystemExit(0)


def change(data: str, before: str, after: str, label: str) -> str:
    n = data.count(before)
    if n != 1:
        raise RuntimeError(f"Build 54 {label}: expected one exact Build 53 anchor, found {n}")
    return data.replace(before, after, 1)


codec = Path('native/android/SalusGarminGfdiCodec.kt')
s = codec.read_text()
s = change(s,
'''    fun registerGfdi(): ByteArray = ByteBuffer.allocate(13).order(ByteOrder.LITTLE_ENDIAN).apply {
        put(0); put(0); putLong(2L); putShort(1); put(0)
    }.array()''',
'''    /** Request MLR, but obey the reliability actually negotiated by the watch. */
    fun registerGfdi(reliable: Boolean = true): ByteArray =
        ByteBuffer.allocate(13).order(ByteOrder.LITTLE_ENDIAN).apply {
            put(0); put(0); putLong(2L); putShort(1)
            put((if (reliable) 2 else 0).toByte())
        }.array()''', 'MLR service registration')
s = change(s,
'''    fun syncReady(): ByteArray = gfdiMessage(5030, byteArrayOf(8, 0))''',
'''    fun syncReady(): ByteArray = gfdiMessage(5030, byteArrayOf(8, 0))

    /** Garmin SystemEventMessage: enum event ordinal then one zero value byte. */
    fun systemEvent(event: Int): ByteArray {
        require(event in 0..16)
        return gfdiMessage(5030, byteArrayOf(event.toByte(), 0))
    }

    /** Garmin 5034 command=1: application identifier + zero + requested app attrs. */
    fun notificationAppAttributes(appId: String, appLabel: String, ids: ByteArray): ByteArray? {
        if (ids.any { (it.toInt() and 255) != 0 }) return null
        val out = ByteArrayOutputStream()
        out.write(1)
        out.write(appId.toByteArray(Charsets.UTF_8))
        out.write(0)
        for (id in ids) {
            val label = appLabel.toByteArray(Charsets.UTF_8)
            out.write(id.toInt() and 255)
            out.write(leShort(label.size))
            out.write(label)
        }
        return out.toByteArray()
    }''', 'system lifecycle and app attributes')
codec.write_text(s)

sender = Path('native/android/SalusGarminNotificationSender.kt')
s = sender.read_text()
s = change(s,
'''        private var dataAckToken = 0''',
'''        private var dataAckToken = 0
        private var mlrRequested = true
        private var mlr: SalusGarminMlrTransport? = null
        private var applicationInitialized = false
        private var setupEventsAwaitingAck = 0
        private var deferredAppAttributes: Pair<String, ByteArray>? = null
        private var appAttributeTransferActive = false
        private val recentAlerts = LinkedHashMap<Int, Alert>()''',
        'new Garmin session fields')
s = change(s,
'''        fun offer(alert: Alert) {
            if (!enabled) return
            if (pending.size >= MAX_PENDING) pending.removeFirst()''',
'''        fun offer(alert: Alert) {
            if (!enabled) return
            recentAlerts[alert.id] = alert
            while (recentAlerts.size > 10) recentAlerts.remove(recentAlerts.keys.first())
            if (pending.size >= MAX_PENDING) pending.removeFirst()''', 'recent notification cache')
s = change(s,
'''            outgoing.clear(); pending.clear(); current = null
            notificationTransfer.reset(); ++dataAckToken''',
'''            outgoing.clear(); pending.clear(); current = null
            recentAlerts.clear(); deferredAppAttributes = null; appAttributeTransferActive = false
            notificationTransfer.reset(); ++dataAckToken''', 'session teardown')
s = change(s,
'''            handle = 0; registered = false; subscribed = false; subscriptionSeen = false
            registrationSent = false; updateSent = false''',
'''            handle = 0; registered = false; subscribed = false; subscriptionSeen = false
            mlr?.close(); mlr = null; mlrRequested = true
            applicationInitialized = false; setupEventsAwaitingAck = 0
            deferredAppAttributes = null; appAttributeTransferActive = false
            registrationSent = false; updateSent = false''', 'transport teardown')
s = change(s,
'''                        mtuPayload = (mtu - 4).coerceIn(19, 244)
                        SalusWatchTransportStatus.note''',
'''                        mtuPayload = (mtu - 4).coerceIn(19, 244)
                        mlr?.setMaxWriteSize(mtu - 3)
                        SalusWatchTransportStatus.note''', 'live negotiated MTU')
s = change(s,
'''            enqueue(SalusGarminGfdiCodec.registerGfdi())''',
'''            enqueue(SalusGarminGfdiCodec.registerGfdi(mlrRequested))''',
        'request MLR with fallback')
s = change(s,
'''        private fun sendGfdi(data: ByteArray) {
            if (handle <= 0 || !enabled) return
            val framed = SalusGarminGfdiCodec.cobsEncode(data)
            var offset = 0''',
'''        private fun sendGfdi(data: ByteArray) {
            if (handle <= 0 || !enabled) return
            val framed = SalusGarminGfdiCodec.cobsEncode(data)
            val reliable = mlr
            if (reliable != null) {
                reliable.send(framed).forEach { enqueue(it) }
                return
            }
            var offset = 0''', 'MLR GFDI sender')
s = change(s,
'''                            handle = bytes[13].toInt() and 255
                            registered = handle > 0
                            if (registered) {''',
'''                            handle = bytes[13].toInt() and 255
                            val reliable = if (bytes.size > 14) bytes[14].toInt() and 255 else 0
                            registered = handle > 0
                            if (registered) {
                                if (reliable != 0) {
                                    mlr = SalusGarminMlrTransport(handle, mtuPayload + 1)
                                    scheduleMlrPoll(attemptId)
                                }
                                SalusWatchTransportStatus.note(app, deviceId, "Garmin reliability",
                                    "Requested=${if (mlrRequested) 2 else 0}; negotiated=$reliable; handle=$handle")''',
        'registration response negotiated MLR')
s = change(s,
'''                        } else stage("GFDI registration rejected", "Garmin returned status=$status")''',
'''                        } else if (mlrRequested) {
                            stage("MLR registration unavailable", "Garmin status=$status; retrying established normal Multi-Link")
                            mlrRequested = false; registrationSent = false
                            registerGfdi()
                        } else stage("GFDI registration rejected", "Garmin returned status=$status")''',
        'fallback on MLR rejection')
s = change(s,
'''                if (h != handle || handle == 0) return@post
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
        }''',
'''                val activeMlr = mlr
                if (activeMlr != null && h and 0x80 != 0) {
                    val received = activeMlr.receive(bytes)
                    received.error?.let { stage("Garmin MLR packet rejected", it) }
                    received.outgoing.forEach { enqueue(it) }
                    received.receivedData?.let { consumeGfdiFragment(it) }
                    return@post
                }
                if (h != handle || handle == 0 || activeMlr != null) return@post
                consumeGfdiFragment(bytes.copyOfRange(1, bytes.size))
            }
        }

        private fun consumeGfdiFragment(part: ByteArray) {
            if (incoming.size() + part.size > 16_384) incoming.reset()
            incoming.write(part)
            val framed = incoming.toByteArray()
            if (framed.size >= 3 && framed.last() == 0.toByte()) {
                incoming.reset()
                val decoded = SalusGarminGfdiCodec.cobsDecode(framed) ?: run {
                    stage("GFDI decode error", "Invalid framed packet from Garmin")
                    return
                }
                val message = SalusGarminGfdiCodec.decodeFrame(decoded) ?: run {
                    stage("GFDI checksum error", "Received invalid Garmin packet")
                    return
                }
                processGfdi(message.type, message.payload, message.sequence)
            }
        }

        private fun scheduleMlrPoll(connection: Int) {
            main.postDelayed({
                if (enabled && connection == attemptId && mlr != null && gatt != null) {
                    mlr?.poll()?.forEach { enqueue(it) }
                    scheduleMlrPoll(connection)
                }
            }, 100L)
        }

        private fun maybeCompleteApplicationSetup() {
            if (!informationExchanged || !configurationExchanged || applicationInitialized) return
            applicationInitialized = true
            val preferences = app.getSharedPreferences("salus_garmin_setup", Context.MODE_PRIVATE)
            if (preferences.getBoolean("complete_$deviceId", false)) {
                stage("Garmin application initialized", "Previously completed first-connection lifecycle")
                return
            }
            // Gadgetbridge GarminSupport.completeInitialization(): only first-time setup.
            // The ordinary 5030/SYNC_READY was already sent at configuration exchange.
            setupEventsAwaitingAck = 3
            sendGfdi(SalusGarminGfdiCodec.systemEvent(4))  // PAIR_COMPLETE
            sendGfdi(SalusGarminGfdiCodec.systemEvent(0))  // SYNC_COMPLETE
            sendGfdi(SalusGarminGfdiCodec.systemEvent(14)) // SETUP_WIZARD_COMPLETE
            stage("Garmin first-connection setup", "Pair/sync/setup completion sent; awaiting Garmin system-event ACKs")
        }''',
        'MLR receive + COBS + lifecycle')
s = change(s,
'''            if (!enabled || !registered || !subscribed || updateSent) return''',
'''            if (!enabled || !registered || !subscribed || updateSent || notificationTransfer.awaitingAck) return''',
        'never overlap Garmin transfers')
s = change(s,
'''                    sendGfdi(SalusGarminGfdiCodec.deviceInformationResponse(payload, sequence))''',
'''                    sendGfdi(SalusGarminGfdiCodec.deviceInformationResponse(payload, sequence))
                    maybeCompleteApplicationSetup()''',
        'device info completes init')
s = change(s,
'''                    stage("Garmin startup answered", "Device-information/configuration status: ${informationExchanged}/${configurationExchanged}")''',
'''                    stage("Garmin startup answered", "Device-information/configuration status: ${informationExchanged}/${configurationExchanged}")
                    maybeCompleteApplicationSetup()''',
        'configuration completes init')
s = change(s,
'''                5034 -> if (payload.size >= 5 && payload[0].toInt() == 0) {
                    val requested = SalusGarminGfdiCodec.read32(payload, 1)
                    sendGfdi(SalusGarminGfdiCodec.notificationControlAck(sequence))
                    val alert = current
                    if (alert != null && requested == alert.id) {
                        SalusWatchTransportStatus.metadata(app, deviceId, "protocol", "Garmin GFDI confirmed; 5034 attribute request received")
                        stage("Watch requested content", "Garmin requested notification attributes")
                        sendAttributes(alert, payload.copyOfRange(5, payload.size))
                    }
                }''',
'''                5034 -> if (payload.isNotEmpty()) {
                    when (payload[0].toInt() and 255) {
                        0 -> if (payload.size >= 5) {
                            val requested = SalusGarminGfdiCodec.read32(payload, 1)
                            sendGfdi(SalusGarminGfdiCodec.notificationControlAck(sequence))
                            val alert = recentAlerts[requested] ?: current?.takeIf { it.id == requested }
                            if (alert != null) {
                                SalusWatchTransportStatus.metadata(app, deviceId, "protocol", "Garmin GFDI confirmed; 5034 attribute request received")
                                stage("Watch requested content", "Garmin requested notification attributes")
                                if (!notificationTransfer.awaitingAck) {
                                    sendAttributes(alert, payload.copyOfRange(5, payload.size))
                                } else stage("Garmin transfer busy", "Additional notification attribute request received during active transfer")
                            } else stage("Unknown Garmin notification", "5034 requested an ID no longer in cache")
                        }
                        1 -> handleAppAttributes(payload.copyOfRange(1, payload.size), sequence)
                        else -> stage("Garmin notification control", "Unsupported 5034 command=${payload[0].toInt() and 255}")
                    }
                }''',
        'both 5034 attribute commands and cached IDs')
s = change(s,
'''                            stage("Garmin accepted notification data",
                                "Watch acknowledged all 5035 data chunks; on-screen display still unverified")
                            current = null; updateSent = false
                            main.postDelayed({ maybeSend() }, 250L)''',
'''                            stage("Garmin accepted notification data",
                                "Watch acknowledged all 5035 data chunks; on-screen display still unverified")
                            if (appAttributeTransferActive) {
                                appAttributeTransferActive = false
                            } else {
                                current = null; updateSent = false
                            }
                            val nextApp = deferredAppAttributes
                            deferredAppAttributes = null
                            main.postDelayed({
                                if (nextApp != null) startAppAttributes(nextApp.first, nextApp.second)
                                else maybeSend()
                            }, 250L)''',
        'process queued app metadata after successful transfer')
s = change(s,
'''                }
                else -> {
                    // No silent unsupported Garmin protocol messages during initialization.''',
'''                } else if (payload.size >= 3) {
                    val originalType = SalusGarminGfdiCodec.read16(payload, 0)
                    val resultCode = payload[2].toInt() and 255
                    if (originalType == 5033) {
                        SalusWatchTransportStatus.note(app, deviceId, "Garmin 5033 update status", "Status=$resultCode")
                        stage(if (resultCode == 0) "Garmin accepted notification update" else "Garmin rejected notification update",
                            "5033 response=$resultCode; display still unverified")
                    } else if (originalType == 5030 && setupEventsAwaitingAck > 0) {
                        if (resultCode == 0) {
                            --setupEventsAwaitingAck
                            if (setupEventsAwaitingAck == 0) {
                                app.getSharedPreferences("salus_garmin_setup", Context.MODE_PRIVATE)
                                    .edit().putBoolean("complete_$deviceId", true).apply()
                                stage("Garmin setup acknowledged", "System-event ACKs received; watch-display status unverified")
                            }
                        } else stage("Garmin setup event rejected", "System-event response=$resultCode")
                    } else if (resultCode != 0) {
                        stage("Garmin protocol response", "Garmin response to GFDI $originalType status=$resultCode")
                    }
                }
                else -> {
                    // No silent unsupported Garmin protocol messages during initialization.''',
        'Garmin 5000 update + init response status logging')
s = change(s,
'''        private fun sendAttributes(alert: Alert, request: ByteArray) {''',
'''        private fun handleAppAttributes(request: ByteArray, sequence: Int?) {
            val terminator = request.indexOf(0.toByte())
            if (terminator <= 0) {
                stage("Garmin app attributes malformed", "5034 application identifier is not null-terminated")
                return
            }
            val appId = String(request.copyOfRange(0, terminator), Charsets.UTF_8)
            val ids = request.copyOfRange(terminator + 1, request.size)
            if (ids.any { (it.toInt() and 255) != 0 }) {
                stage("Garmin app attribute unsupported", "5034 requested app-attribute ID other than APP_NAME")
                return
            }
            sendGfdi(SalusGarminGfdiCodec.notificationControlAck(sequence))
            if (notificationTransfer.awaitingAck) {
                deferredAppAttributes = appId to ids
                stage("Garmin application metadata queued", "Waiting until notification text transfer completes")
            } else startAppAttributes(appId, ids)
        }

        private fun startAppAttributes(appId: String, ids: ByteArray) {
            if (!enabled || !registered) return
            val label = appId.substringAfterLast('.').ifBlank { "App" }
            val response = SalusGarminGfdiCodec.notificationAppAttributes(appId, label, ids) ?: return
            appAttributeTransferActive = true
            stage("Garmin application metadata", "Replying to Garmin's 5034 app-name request")
            notificationTransfer.begin(response).let { sendNextAttributeChunk(it) }
        }

        private fun sendAttributes(alert: Alert, request: ByteArray) {''',
        '5034 app attributes handler')
s = change(s,
'''            if (!enabled || current == null) return
            sendGfdi(SalusGarminGfdiCodec.notificationData(chunk.bytes, chunk.total,''',
'''            if (!enabled || !notificationTransfer.awaitingAck) return
            sendGfdi(SalusGarminGfdiCodec.notificationData(chunk.bytes, chunk.total,''',
        'app attribute data allowed with no active alert')
# Update the timeout comparison: application metadata responses have no current ID.
sender.write_text(s)

pubspec = Path('pubspec.yaml')
pubspec.write_text(change(pubspec.read_text(), 'version: 0.21.15+53',
                          'version: 0.21.16+54', 'app version'))
old_test = Path('test/build52_garmin_attribute_payload_contract_test.dart')
old_test.write_text(change(old_test.read_text(), 'version: 0.21.15+53',
                           'version: 0.21.16+54', 'Build 52 version assertion'))
print('PASS: guarded Salus Build 54 Garmin source + version migration')
