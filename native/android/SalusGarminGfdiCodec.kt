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

    fun gfdiMessage(type: Int, payload: ByteArray): ByteArray {
        val size = payload.size + 6
        require(size <= 65535)
        val b = ByteBuffer.allocate(size).order(ByteOrder.LITTLE_ENDIAN)
        b.putShort(size.toShort()); b.putShort(type.toShort()); b.put(payload)
        val bytes = b.array()
        val sum = crc(bytes.copyOfRange(0, size - 2))
        b.putShort(sum.toShort())
        return bytes
    }

    fun decodeGfdi(packet: ByteArray): Pair<Int, ByteArray>? {
        if (packet.size < 6) return null
        val b = ByteBuffer.wrap(packet).order(ByteOrder.LITTLE_ENDIAN)
        val length = b.short.toInt() and 65535
        val type = b.short.toInt() and 65535
        if (length != packet.size || crc(packet.copyOfRange(0, length - 2)) !=
            (b.getShort(length - 2).toInt() and 65535)) return null
        return type to packet.copyOfRange(4, length - 2)
    }

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

    fun notificationControlAck() = gfdiMessage(5000, byteArrayOf(
        0xAA.toByte(), 0x13, 0, 0, 0)) // response-to=5034 + ACK + chunk OK + no error

    fun notificationSubscriptionResponse(enabled: Boolean, unknown: Int) = gfdiMessage(
        5000, byteArrayOf(0xAC.toByte(), 0x13, 0, if (enabled) 0 else 1,
            if (enabled) 1 else 0, (unknown and 255).toByte())
    )

    fun notificationDataAck() = gfdiMessage(5000, byteArrayOf(0xAB.toByte(), 0x13, 0, 0))

    fun leShort(i: Int): ByteArray = byteArrayOf((i and 255).toByte(), ((i ushr 8) and 255).toByte())
    fun leInt(i: Int): ByteArray = byteArrayOf((i and 255).toByte(), ((i ushr 8) and 255).toByte(),
        ((i ushr 16) and 255).toByte(), ((i ushr 24) and 255).toByte())
    fun read16(x: ByteArray, o: Int): Int = (x[o].toInt() and 255) or ((x[o+1].toInt() and 255) shl 8)
    fun read32(x: ByteArray, o: Int): Int = ByteBuffer.wrap(x, o, 4).order(ByteOrder.LITTLE_ENDIAN).int
    fun timestamp(time: Long): String = SimpleDateFormat("yyyyMMdd'T'HHmmss", Locale.ROOT).format(Date(time))
}
