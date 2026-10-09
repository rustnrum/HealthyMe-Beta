package com.rustnrum.healthyme.beta03

/**
 * Garmin GFDI 5035 notification-data transfer state machine.
 * The watch must ACK each data chunk (5000 response to 5035).
 * An Android GATT write finishing is NOT a Garmin transfer ACK or proof of display.
 * Protocol reference: Gadgetbridge NotificationsHandler.Upload (AGPL-3.0).
 */
class SalusGarminNotificationTransfer(private val chunkSize: Int = 200) {
    init { require(chunkSize in 1..300) }

    data class Chunk(val bytes: ByteArray, val total: Int, val offset: Int, val crc: Int)

    sealed class Ack {
        data class Next(val chunk: Chunk) : Ack()
        object Complete : Ack()
        data class Rejected(val protocolStatus: Int, val transferStatus: Int) : Ack()
        object Unexpected : Ack()
    }

    private var bytes = byteArrayOf()
    private var offset = 0
    private var runningCrc = 0
    private var active = false
    var awaitingAck = false
        private set

    fun reset() {
        bytes = byteArrayOf()
        offset = 0
        runningCrc = 0
        awaitingAck = false
        active = false
    }

    /** Begin with a nonempty, fully serialized attributes payload. */
    fun begin(payload: ByteArray): Chunk {
        require(payload.isNotEmpty())
        reset()
        bytes = payload.clone()
        active = true
        return takeChunk()!!
    }

    /** ACK code 0 means accepted; Garmin transfer status 0 means OK. */
    fun acknowledge(status: Int, transferStatus: Int): Ack {
        if (!active || !awaitingAck) return Ack.Unexpected
        awaitingAck = false
        if (status != 0 || transferStatus != 0) {
            reset()
            return Ack.Rejected(status, transferStatus)
        }
        if (offset >= bytes.size) {
            reset()
            return Ack.Complete
        }
        return Ack.Next(takeChunk()!!)
    }

    private fun takeChunk(): Chunk? {
        if (!active || awaitingAck || offset >= bytes.size) return null
        val from = offset
        val to = minOf(offset + chunkSize, bytes.size)
        val piece = bytes.copyOfRange(from, to)
        runningCrc = SalusGarminGfdiCodec.crc(piece, runningCrc)
        offset = to
        awaitingAck = true
        return Chunk(piece, bytes.size, from, runningCrc)
    }
}
