package com.rustnrum.healthyme.beta03

fun main() {
    val base = 1760227200000L // test anchor, UTC midnight
    fun packet(index: Int, b2: Int, b3: Int = 0) = ByteArray(16).also {
        it[0] = 57; it[1] = index.toByte(); it[2] = b2.toByte(); it[3] = b3.toByte()
    }
    val decoder = SalusRingHrvLogDecoder()
    decoder.parse(packet(0, 2, 30), base, base + 24 * 3600_000L)
    check(decoder.pageCount == 2 && decoder.rangeMinutes == 30)
    val first = packet(1, 4)
    first[3] = 42
    first[4] = 0
    first[5] = -1
    first[6] = 51
    val x = decoder.parse(first, base, base + 24 * 3600_000L)
    check(x.size == 2 && x[0].slot == 4 && x[0].value == 42)
    check(x[0].timestampMs == base + 120 * 60_000L)
    check(x[1].slot == 7 && x[1].value == 51)
    val second = packet(2, 16)
    second[3] = 99
    val y = decoder.parse(second, base, base + 24 * 3600_000L)
    check(y.size == 1 && y[0].slot == 16 && y[0].value == 99)
    check(decoder.completed && decoder.decoded == 3)
    check(decoder.parse(second, base, base + 24 * 3600_000L).isEmpty())
    check(decoder.invalidPackets == 1)
    val future = SalusRingHrvLogDecoder()
    future.parse(packet(0, 1, 30), base, base + 30 * 60_000L)
    val midnightFuture = packet(1, 47)
    midnightFuture[3] = 80
    check(future.parse(midnightFuture, base, base + 30 * 60_000L).isEmpty())
    println("Ring proxy packet layout and timestamp fixtures passed")
}
