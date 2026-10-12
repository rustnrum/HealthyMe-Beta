package com.rustnrum.healthyme.beta03

/**
 * Read-only decoder for COLMI/QRing command 0x39 (57), split-array HRV PROXY.
 * These firmware buckets are not RR intervals, clinical RMSSD, or AFib evidence.
 * The array header supplies the number of data pages and minutes per slot.
 * Each data page uses byte 2 as a SLOT OFFSET, NOT a health measurement.
 * No Bluetooth I/O or writes take place in this class.
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

    val headerReceived: Boolean get() = pageCount > 0
    val completed: Boolean get() = headerReceived && expectedPage > pageCount

    fun parse(packet: ByteArray, localMidnightMs: Long, nowMs: Long): List<Bucket> {
        if (packet.size != 16 || (packet[0].toInt() and 0xff) != 57) {
            invalidPackets++
            return emptyList()
        }
        val index = packet[1].toInt() and 0xff
        if (index == 0xff) { // Firmware explicitly says no data.
            pageCount = 0
            expectedPage = 0
            rangeMinutes = 0
            return emptyList()
        }
        if (index == 0) {
            val count = packet[2].toInt() and 0xff
            val range = packet[3].toInt() and 0xff
            // Do not infer interval or records from damaged / unknown headers.
            if (count !in 1..32 || range !in 1..120) {
                invalidPackets++
                pageCount = 0
                expectedPage = 0
                return emptyList()
            }
            pageCount = count
            rangeMinutes = range
            expectedPage = 1
            decoded = 0
            return emptyList()
        }
        if (pageCount == 0 || index != expectedPage) {
            invalidPackets++
            return emptyList()
        }
        // Page 1 and all subsequent pages: byte 2 = slot index offset;
        // bytes 3..14 are up to 12 firmware proxy values. 0/255 = empty.
        val startSlot = packet[2].toInt() and 0xff
        val samples = mutableListOf<Bucket>()
        for (offset in 0 until 12) {
            val raw = packet[3 + offset].toInt() and 0xff
            if (raw == 0 || raw == 255) continue
            val slot = startSlot + offset
            val timestamp = localMidnightMs + slot.toLong() * rangeMinutes * 60_000L
            // No reading may be stamped in the future or outside the day.
            if (slot.toLong() * rangeMinutes >= 1440 ||
                timestamp < localMidnightMs || timestamp > nowMs + 300_000L) continue
            samples.add(Bucket(slot, raw, timestamp))
        }
        decoded += samples.size
        expectedPage++
        return samples
    }
}
