package com.rustnrum.healthyme.beta03

/**
 * Read-only COLMI/QRing command 57 (0x39) firmware HRV-index history.
 * This is a proprietary per-slot index; it is NOT verified RMSSD in ms.
 * Packet 0: page count + minutes per slot.
 * Packet 1: start-slot offset in byte 2 followed by 12 values (bytes 3..14).
 * Packets 2..N: 13 values (bytes 2..14), no start-slot byte.
 * CRC is the low eight bits of the sum of bytes 0..14.
 */
class SalusRingHrvLogDecoder {
    data class Bucket(val slot: Int, val value: Int, val timestampMs: Long)

    var pageCount: Int = 0
        private set
    var rangeMinutes: Int = 0
        private set
    var expectedPage: Int = 0
        private set
    var decoded: Int = 0
        private set
    var invalidPackets: Int = 0
        private set
    private var nextSlot: Int = 0

    val headerReceived: Boolean get() = pageCount > 0
    val completed: Boolean get() = headerReceived && expectedPage > pageCount

    fun parse(packet: ByteArray, localMidnightMs: Long, nowMs: Long): List<Bucket> {
        if (packet.size != 16 || (packet[0].toInt() and 0xff) != 57) {
            invalidPackets++
            return emptyList()
        }
        val checksum = (0 until 15).sumOf { packet[it].toInt() and 0xff } and 0xff
        if (checksum != (packet[15].toInt() and 0xff)) {
            invalidPackets++
            return emptyList()
        }
        val index = packet[1].toInt() and 0xff
        if (index == 0xff) {
            pageCount = 0
            rangeMinutes = 0
            expectedPage = 0
            decoded = 0
            nextSlot = 0
            return emptyList()
        }
        if (index == 0) {
            val pages = packet[2].toInt() and 0xff
            val minutes = packet[3].toInt() and 0xff
            if (pages !in 1..64 || minutes !in 1..120) {
                invalidPackets++
                pageCount = 0
                expectedPage = 0
                return emptyList()
            }
            pageCount = pages
            rangeMinutes = minutes
            expectedPage = 1
            nextSlot = 0
            decoded = 0
            return emptyList()
        }
        if (!headerReceived || completed || index != expectedPage || index > pageCount) {
            invalidPackets++
            return emptyList()
        }
        val first = index == 1
        val startSlot = if (first) (packet[2].toInt() and 0xff) else nextSlot
        val valueStart = if (first) 3 else 2
        val count = if (first) 12 else 13
        val samples = mutableListOf<Bucket>()
        for (offset in 0 until count) {
            val value = packet[valueStart + offset].toInt() and 0xff
            if (value == 0 || value == 255) continue
            val slot = startSlot + offset
            val minute = slot.toLong() * rangeMinutes
            val time = localMidnightMs + minute * 60_000L
            if (minute >= 1440 || time < localMidnightMs || time > nowMs) continue
            samples.add(Bucket(slot, value, time))
        }
        nextSlot = startSlot + count
        decoded += samples.size
        expectedPage++
        return samples
    }
}
