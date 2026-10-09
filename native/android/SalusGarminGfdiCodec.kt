package com.rustnrum.healthyme.beta03

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Garmin Multi-Link V2 / GFDI wire format. No transport / Android dependencies.
 * Protocol behavior researched from Freeyourgadget/Gadgetbridge (AGPL-3.0).
 * See docs/BUILD46_DIRECT_NOTIFICATIONS.md for attribution / license requirements.
 */
object SalusGarminGfdiCodec {
    private val crcConstants = intArrayOf(
        0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
        0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
    )

    fun crc(data: ByteArray, initial: Int = 0): Int {
        var c = initial
        for (b in data) {
            val i = b.toInt() and 255
            c = (((c ushr 4) and 4095) xor crcConstants[c and 15]) xor crcConstants[i and 15]
            c = (((c ushr 4) and 4095) xor crcConstants[c and 15]) xor crcConstants[(i ushr 4) and 15]
        }
        return c and 65535
    }

    /** Garmin encodes some GFDI messages in two bytes as [type-5000, 0x80|sequence].
     * The second byte's lower five bits carry a transaction sequence number.
     * Source: Gadgetbridge Garmin Protocol, GFDI request/response encoding.
     */
    data class Frame(val type: Int, val payload: ByteArray, val sequence: Int?)

    fun gfdiMessage(type: Int, payload: ByteArray, sequence: Int? = null): ByteArray {
        val size = payload.size + 6
        require(size <= 65535)
        val b = ByteBuffer.allocate(size).order(ByteOrder.LITTLE_ENDIAN)
        b.putShort(size.toShort())
        if (sequence == null) {
            b.putShort(type.toShort())
        } else {
            require(type in 5000..5255) { "Compact Garmin message type is outside byte range" }
            require(sequence in 0..31) { "Garmin sequence number must be 0..31" }
            b.put((type - 5000).toByte())
            b.put((0x80 or sequence).toByte())
        }
        b.put(payload)
        val bytes = b.array()
        val sum = crc(bytes.copyOfRange(0, size - 2))
        b.putShort(sum.toShort())
        return bytes
    }

    fun decodeFrame(packet: ByteArray): Frame? {
        if (packet.size < 6) return null
        val b = ByteBuffer.wrap(packet).order(ByteOrder.LITTLE_ENDIAN)
        val length = b.short.toInt() and 65535
        if (length != packet.size || crc(packet.copyOfRange(0, length - 2)) !=
            (b.getShort(length - 2).toInt() and 65535)) return null
        val high = packet[3].toInt() and 255
        val compact = high and 0x80 != 0
        val sequence = if (compact) high and 0x1f else null
        val type = if (compact) 5000 + (packet[2].toInt() and 255)
            else b.getShort(2).toInt() and 65535
        return Frame(type, packet.copyOfRange(4, length - 2), sequence)
    }

    fun decodeGfdi(packet: ByteArray): Pair<Int, ByteArray>? =
        decodeFrame(packet)?.let { it.type to it.payload }

    // Garmin adds an extra leading zero to regular COBS.
    fun cobsEncode(input: ByteArray): ByteArray {
        val output = ByteArrayOutputStream()
        output.write(0)
        var index = 0
        while (index < input.size) {
            val codePosition = output.size()
            output.write(0)
            var code = 1
            while (index < input.size && input[index].toInt() != 0 && code < 255) {
                output.write(input[index].toInt() and 255)
                index++
                code++
            }
            val data = output.toByteArray()
            data[codePosition] = code.toByte()
            output.reset(); output.write(data)
            if (index < input.size && input[index].toInt() == 0) index++
        }
        if (input.isEmpty() || input.last().toInt() == 0) output.write(1)
        output.write(0)
        return output.toByteArray()
    }

    fun cobsDecode(framed: ByteArray): ByteArray? {
        if (framed.size < 3 || framed.first().toInt() != 0 || framed.last().toInt() != 0) return null
        val output = ByteArrayOutputStream()
        var i = 1
        val end = framed.size - 1
        while (i < end) {
            val code = framed[i++].toInt() and 255
            if (code == 0 || i + code - 1 > end) return null
            repeat(code - 1) { output.write(framed[i++].toInt() and 255) }
            if (code != 255 && i < end) output.write(0)
        }
        return output.toByteArray()
    }

    fun closeAll(): ByteArray = ByteBuffer.allocate(13).order(ByteOrder.LITTLE_ENDIAN).apply {
        put(0); put(5); putLong(2L); putShort(0)
    }.array()

    fun registerGfdi(): ByteArray = ByteBuffer.allocate(13).order(ByteOrder.LITTLE_ENDIAN).apply {
        put(0); put(0); putLong(2L); putShort(1); put(0)
    }.array()

    /** GFDI status ACK for a received Garmin request. */
    fun genericAck(messageType: Int, sequence: Int? = null): ByteArray = gfdiMessage(5000,
        leShort(messageType) + byteArrayOf(0), sequence)

    private fun textField(value: String): ByteArray {
        val b = value.toByteArray(Charsets.UTF_8).take(60).toByteArray()
        return byteArrayOf(b.size.toByte()) + b
    }

    /** Garmin 5024 details, following DeviceInformationMessage negotiation. */
    fun deviceInformationResponse(incoming: ByteArray, sequence: Int? = null): ByteArray {
        val protocol = read16(incoming, 0)
        val fields = ByteBuffer.allocate(15).order(ByteOrder.LITTLE_ENDIAN).apply {
            putShort(5024) // response-to DEVICE_INFORMATION
            put(0) // ACK
            putShort(150) // host protocol version from published Garmin client implementation
            putShort((-1).toShort()) // host product identifier not provided
            putInt(-1) // host unit ID unknown
            putShort(7791) // host version, compatible with known client
            putShort((-1).toShort()) // unrestricted max packet
        }.array()
        return gfdiMessage(5000, fields + textField("Salus") + textField("Android") +
            textField("Phone") + byteArrayOf(if (protocol / 100 == 1) 1 else 0), sequence)
    }

    /** Only advertise capabilities implemented by Salus; avoid promising cloud sync. */
    fun configurationResponse(): ByteArray {
        val bits = ByteArray(13)
        // GarminCapability ordinal bit positions: GNCS, SMS_NOTIFICATIONS,
        // CURRENT_TIME_REQUEST_SUPPORT, MULTI_LINK_SERVICE.
        for (bit in intArrayOf(6, 51, 71, 76)) bits[bit / 8] =
            (bits[bit / 8].toInt() or (1 shl (bit % 8))).toByte()
        return gfdiMessage(5050, byteArrayOf(bits.size.toByte()) + bits)
    }

    fun syncReady(): ByteArray = gfdiMessage(5030, byteArrayOf(8, 0))

    fun authNegotiationResponse(incoming: ByteArray, sequence: Int? = null): ByteArray = gfdiMessage(5000,
        leShort(5101) + byteArrayOf(0, 0, incoming[0]) + incoming.copyOfRange(1, 5), sequence)

    fun currentTimeResponse(referenceId: Int, sequence: Int? = null): ByteArray {
        val now = System.currentTimeMillis() / 1000L
        val garminSeconds = (now - 631065600L).toInt()
        val offset = java.util.TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 1000
        val p = ByteBuffer.allocate(23).order(ByteOrder.LITTLE_ENDIAN).apply {
            putShort(5052); put(0); putInt(referenceId); putInt(garminSeconds)
            putInt(offset); putInt(0); putInt(0)
        }.array()
        return gfdiMessage(5000, p, sequence)
    }

    fun notificationUpdate(id: Int, category: Int, count: Int = 1): ByteArray =
        gfdiMessage(5033, ByteBuffer.allocate(9).order(ByteOrder.LITTLE_ENDIAN).apply {
            put(0) // add
            put(0x12) // foreground + action decline, not an attachment
            put(category.coerceIn(0, 12).toByte())
            put(count.coerceIn(1, 255).toByte())
            putInt(id)
            put(0) // no custom actions / attachments
        }.array())

    fun notificationAttributes(id: Int, fields: List<Pair<Int, String>>): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(0) // get-attributes response command
        out.write(leInt(id))
        for ((attribute, text) in fields) {
            val value = text.toByteArray(Charsets.UTF_8).take(255).toByteArray()
            out.write(attribute)
            out.write(leShort(value.size))
            out.write(value)
        }
        return out.toByteArray()
    }

    fun notificationData(bytes: ByteArray, total: Int, offset: Int, runningCrc: Int) =
        gfdiMessage(5035, ByteBuffer.allocate(bytes.size + 6).order(ByteOrder.LITTLE_ENDIAN).apply {
            putShort(total.toShort()); putShort(runningCrc.toShort())
            putShort(offset.toShort()); put(bytes)
        }.array())

    fun notificationControlAck(sequence: Int? = null) = gfdiMessage(5000, byteArrayOf(
        0xAA.toByte(), 0x13, 0, 0, 0), sequence) // response-to=5034 + ACK + chunk OK + no error

    /** Reply to Garmin's 5036 request. Phone permission and the watch's
     * requested subscription state are separate values (Gadgetbridge's
     * NotificationSubscriptionStatusMessage behavior).
     * This response does NOT itself turn a watch-side disabled subscription on.
     */
    fun notificationSubscriptionResponse(
        requestedByWatch: Boolean,
        phoneNotificationsAllowed: Boolean,
        sequence: Int? = null,
    ) = gfdiMessage(5000, byteArrayOf(
        0xAC.toByte(), 0x13, // Response to GFDI 5036
        0, // ACK
        if (phoneNotificationsAllowed) 0 else 1, // Host permission: enabled / disabled
        if (requestedByWatch) 1 else 0, // Echo watch's requested subscription state
        0, // Reserved, as in Gadgetbridge's implementation
    ), sequence)

    /** Gadgetbridge ProtobufStatusMessage: acknowledge a received data chunk.
     * 5043 / 5044 protobuf framing remains feature-specific; no pretend decoded metrics.
     */
    fun protobufChunkAck(messageType: Int, requestId: Int, offset: Int, sequence: Int? = null): ByteArray =
        gfdiMessage(5000, leShort(messageType) + byteArrayOf(0) + leShort(requestId) +
            leInt(offset) + byteArrayOf(0, 0), sequence)

    fun notificationDataAck(sequence: Int? = null) = gfdiMessage(5000, byteArrayOf(0xAB.toByte(), 0x13, 0, 0), sequence)

    fun leShort(i: Int): ByteArray = byteArrayOf((i and 255).toByte(), ((i ushr 8) and 255).toByte())
    fun leInt(i: Int): ByteArray = byteArrayOf((i and 255).toByte(), ((i ushr 8) and 255).toByte(),
        ((i ushr 16) and 255).toByte(), ((i ushr 24) and 255).toByte())
    fun read16(x: ByteArray, o: Int): Int = (x[o].toInt() and 255) or ((x[o+1].toInt() and 255) shl 8)
    fun read32(x: ByteArray, o: Int): Int = ByteBuffer.wrap(x, o, 4).order(ByteOrder.LITTLE_ENDIAN).int
    fun timestamp(time: Long): String = SimpleDateFormat("yyyyMMdd'T'HHmmss", Locale.ROOT).format(Date(time))
}
