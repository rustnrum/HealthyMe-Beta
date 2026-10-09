import com.rustnrum.healthyme.beta03.SalusGarminGfdiCodec as C
import com.rustnrum.healthyme.beta03.SalusGarminNotificationTransfer as T

fun main() {
    val transfer = T(chunkSize = 8)
    val body = "Test notification data from Salus".toByteArray()
    val first = transfer.begin(body)
    check(first.offset == 0 && first.total == body.size && first.bytes.size == 8)
    check(transfer.awaitingAck)
    check(transfer.acknowledge(1, 0) is T.Ack.Rejected)
    check(!transfer.awaitingAck)
    check(transfer.acknowledge(0, 0) is T.Ack.Unexpected)
    println("PASS: rejection clears transfer; unsolicited ACK is ignored")

    var chunk = transfer.begin(body)
    var confirmations = 0
    val received = ArrayList<Byte>()
    while (true) {
        check(transfer.awaitingAck)
        val frame = C.notificationData(chunk.bytes, chunk.total, chunk.offset, chunk.crc)
        val packet = C.decodeFrame(frame) ?: error("corrupt 5035")
        check(packet.type == 5035)
        check(C.read16(packet.payload, 0) == body.size)
        check(C.read16(packet.payload, 2) == chunk.crc)
        check(C.read16(packet.payload, 4) == chunk.offset)
        check(packet.payload.copyOfRange(6, packet.payload.size).contentEquals(chunk.bytes))
        for (byte in chunk.bytes) received.add(byte)
        val response = transfer.acknowledge(0, 0)
        confirmations++
        when(response) {
            is T.Ack.Next -> chunk = response.chunk
            T.Ack.Complete -> break
            else -> error("Unexpected result: $response")
        }
    }
    check(confirmations > 1)
    check(received.toByteArray().contentEquals(body))
    check(!transfer.awaitingAck)
    println("PASS: $confirmations Garmin 5035 chunks each waited for ACK; complete only after final ACK")

    val c = transfer.begin(byteArrayOf(0, 1, 2))
    check(c.total == 3)
    transfer.reset()
    check(transfer.acknowledge(0, 0) is T.Ack.Unexpected)
    println("PASS: disconnect/timeout reset invalidates late ACK")

    val finalAck = C.notificationDataAck(sequence = 4)
    val ackFrame = C.decodeFrame(finalAck) ?: error("final status frame invalid")
    check(ackFrame.type == 5000 && ackFrame.sequence == 4)
    check(C.read16(ackFrame.payload, 0) == 5035)
    check(ackFrame.payload.contentEquals(byteArrayOf(0xAB.toByte(), 0x13, 0, 0)))
    println("PASS: final Garmin data ACK has correct 5035 status and sequence")
}
