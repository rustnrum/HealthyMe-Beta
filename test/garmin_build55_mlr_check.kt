import com.rustnrum.healthyme.beta03.SalusGarminMlrTransport

fun main() {
    var now = 0L
    val host = SalusGarminMlrTransport(0x82, 20) { now }
    // The incoming Garmin packet acknowledges packet #1 before we have sent
    // anything. Build 54 dropped this entire packet. The GFDI fragment must
    // still be processed if its receive sequence is valid.
    val initial = host.receive(byteArrayOf(0xA0.toByte(), 0x40, 11, 22))
    check(initial.error?.contains("req=1") == true)
    check(initial.receivedData!!.contentEquals(byteArrayOf(11, 22)))
    check(initial.outgoing.isEmpty())
    now = 300L
    val ack = host.poll()
    check(ack.size == 1 && ack[0].size == 2)
    check(ack[0][0] == 0xA0.toByte())
    check(ack[0][1] == 0x40.toByte()) // cumulative receive ACK=1
    // A later valid fragment with the same unusual cumulative ACK is received,
    // not dropped or duplicated; sender ACK window is not falsely advanced.
    val following = host.receive(byteArrayOf(0xA0.toByte(), 0x41, 33))
    check(following.receivedData!!.contentEquals(byteArrayOf(33)))
    check(host.receive(byteArrayOf(0xA0.toByte(), 0x41, 33)).receivedData == null)
    // A separate locally initiated message still starts from nextSend=0.
    val outgoing = host.send(byteArrayOf(55))
    check(outgoing.size == 1 && (outgoing[0][1].toInt() and 63) == 0)
    // Proper ACK from Garmin clears in-flight send.
    val proper = host.receive(byteArrayOf(0xA0.toByte(), 0x40))
    check(proper.error == null)
    now = 5000
    check(host.poll().none { it.size > 2 })
    println("PASS Build55: unexpected inbound MLR ACK does not discard in-sequence Garmin data")
}
