/*
 * Garmin MLR transport behavior adapted from Gadgetbridge's MlrCommunicator.
 * Based on code published by the Gadgetbridge contributors and licensed under
 * the GNU Affero General Public License v3 or later (AGPL-3.0-or-later).
 * https://codeberg.org/Freeyourgadget/Gadgetbridge
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
package com.rustnrum.healthyme.beta03

/**
 * Garmin Multi-Link Reliable transport (MLR), independent of Android BLE.
 * Framing, cumulative ACKs, sequence numbers and retransmission behavior follow
 * Gadgetbridge's MlrCommunicator (AGPL-3.0-or-later), adapted for Salus.
 * The BLE session must ONLY use this transport after Garmin negotiates reliable!=0.
 * GFDI/COBS framing remains above this transport.
 */
class SalusGarminMlrTransport(
    private val handle: Int,
    maxWriteSize: Int,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    data class Result(val receivedData: ByteArray?, val outgoing: List<ByteArray>, val error: String? = null)
    private data class Fragment(val bytes: ByteArray, val requestedAck: Int)
    private val waiting = java.util.ArrayDeque<ByteArray>()
    private val outstanding = arrayOfNulls<Fragment>(64)
    private var writeSize = maxWriteSize.coerceAtLeast(3)
    private var nextSend = 0
    private var nextReceive = 0
    private var lastPeerAck = 0
    private var lastAckSent = 0
    private var unackedWindow = 32
    private var retransmitDelay = 1000L
    private var retransmitAt = Long.MAX_VALUE
    private var ackAt = Long.MAX_VALUE
    private var closed = false

    init { require(handle in 1..255) }

    fun setMaxWriteSize(value: Int) { writeSize = value.coerceAtLeast(3) }

    /** Input includes Salus/Garmin COBS bytes, not a GFDI or BLE header. */
    fun send(cobs: ByteArray): List<ByteArray> {
        if (closed || cobs.isEmpty()) return emptyList()
        var at = 0
        val maxPayload = writeSize - 2
        while (at < cobs.size) {
            val end = minOf(cobs.size, at + maxPayload)
            waiting.addLast(cobs.copyOfRange(at, end))
            at = end
        }
        return pump()
    }

    fun receive(packet: ByteArray): Result {
        if (closed) return Result(null, emptyList(), "closed")
        if (packet.size < 2 || packet[0].toInt() and 0x80 == 0)
            return Result(null, emptyList(), "invalid MLR header")
        val a = packet[0].toInt() and 255
        val b = packet[1].toInt() and 255
        val receivedHandle = (a and 0x70) ushr 4
        if (receivedHandle != (handle and 7))
            return Result(null, emptyList(), "wrong MLR handle")
        val request = ((a and 0x0f) shl 2) or ((b ushr 6) and 3)
        val sequence = b and 63
        val emitted = mutableListOf<ByteArray>()
        val distance = (request - lastPeerAck + 64) % 64
        val inFlight = (nextSend - lastPeerAck + 64) % 64
        if (distance in 1..inFlight) {
            var index = lastPeerAck
            while (index != request) {
                outstanding[index] = null
                index = (index + 1) % 64
            }
            lastPeerAck = request
            retransmitAt = if (request == nextSend) Long.MAX_VALUE else clock() + retransmitDelay
        } else if (distance != 0) {
            return Result(null, emptyList(), "invalid cumulative ACK")
        }
        var data: ByteArray? = null
        if (packet.size > 2) {
            if (sequence == nextReceive) {
                data = packet.copyOfRange(2, packet.size)
                nextReceive = (nextReceive + 1) % 64
                val sinceAck = (nextReceive - lastAckSent + 64) % 64
                if (sinceAck >= 5) {
                    emitted.add(sendAck())
                } else {
                    ackAt = clock() + 250L
                }
            } else {
                // Out-of-order and duplicate fragments must not enter the COBS decoder.
                emitted.add(sendAck())
            }
        }
        emitted.addAll(pump())
        return Result(data, emitted)
    }

    /** Called by the session's existing main-thread scheduler. */
    fun poll(): List<ByteArray> {
        if (closed) return emptyList()
        val emitted = mutableListOf<ByteArray>()
        val now = clock()
        if (now >= ackAt) emitted.add(sendAck())
        if (now >= retransmitAt && lastPeerAck != nextSend) {
            retransmitDelay = minOf(retransmitDelay * 2, 20_000L)
            unackedWindow = maxOf(1, unackedWindow / 2)
            var i = lastPeerAck
            while (i != nextSend) {
                val previous = outstanding[i]
                if (previous != null) emitted.add(frame(previous.requestedAck, i, previous.bytes))
                i = (i + 1) % 64
            }
            retransmitAt = clock() + retransmitDelay
        }
        emitted.addAll(pump())
        return emitted
    }

    fun close() {
        closed = true
        waiting.clear()
        outstanding.fill(null)
        ackAt = Long.MAX_VALUE
        retransmitAt = Long.MAX_VALUE
    }

    private fun pump(): List<ByteArray> {
        val emitted = mutableListOf<ByteArray>()
        while (waiting.isNotEmpty() && ((nextSend - lastPeerAck + 64) % 64) < unackedWindow) {
            val fragment = waiting.removeFirst()
            outstanding[nextSend] = Fragment(fragment, nextReceive)
            emitted.add(frame(nextReceive, nextSend, fragment))
            nextSend = (nextSend + 1) % 64
            if (retransmitAt == Long.MAX_VALUE) retransmitAt = clock() + retransmitDelay
        }
        return emitted
    }

    private fun sendAck(): ByteArray {
        lastAckSent = nextReceive
        ackAt = Long.MAX_VALUE
        return frame(nextReceive, 0, byteArrayOf())
    }

    private fun frame(request: Int, sequence: Int, payload: ByteArray): ByteArray =
        byteArrayOf(
            (0x80 or ((handle and 7) shl 4) or ((request ushr 2) and 15)).toByte(),
            (((request and 3) shl 6) or (sequence and 63)).toByte(),
        ) + payload
}
