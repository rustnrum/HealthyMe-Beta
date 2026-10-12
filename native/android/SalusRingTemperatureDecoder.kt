package com.rustnrum.healthyme.beta03

import java.util.Calendar

/** COLMI R02 0xBC/0x25 history. Read only; never enables sensor settings.
 * Format and raw temperature equation cross-checked against PulseLoop.
 * The firmware has to return real, valid data; missing samples stay missing.
 */
object SalusRingTemperatureDecoder {
    data class Sample(val celsius: Double, val timestampMs: Long)

    fun decode(payload: ByteArray, nowMs: Long = System.currentTimeMillis()): List<Sample> {
        if (payload.size < 50 || payload.size > 4096) return emptyList()
        val start = Calendar.getInstance().apply {
            timeInMillis = nowMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val seen = HashSet<Long>()
        val out = mutableListOf<Sample>()
        var index = 0
        var records = 0
        while (index + 50 <= payload.size && records++ < 14) {
            val daysAgo = payload[index++].toInt() and 0xff
            index++ // unknown observed byte; not a temperature measurement.
            if (daysAgo > 14) break
            val day = (start.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -daysAgo) }
            for (hour in 0 until 24) {
                if (index + 1 >= payload.size) return out.sortedBy { it.timestampMs }
                for (slot in 0..1) {
                    val raw = payload[index++].toInt() and 0xff
                    if (raw == 0 || raw == 0xff) continue
                    val celsius = 20.0 + raw / 10.0
                    // Physiological plausibility check; never equate this with core fever.
                    if (celsius !in 20.0..42.0) continue
                    val stamp = day.timeInMillis + hour * 3_600_000L + slot * 1_800_000L
                    if (stamp <= nowMs && seen.add(stamp)) out.add(Sample(celsius, stamp))
                }
            }
            if (daysAgo == 0) break
        }
        return out.sortedBy { it.timestampMs }
    }
}
