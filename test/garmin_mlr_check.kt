import com.rustnrum.healthyme.beta03.SalusGarminMlrTransport

fun main() {
    var now = 0L
    val sender = SalusGarminMlrTransport(0x82, 8) { now }
    val receiver = SalusGarminMlrTransport(0x82, 8) { now }
    val parts = sender.send(byteArrayOf(1,2,3,4,5,6,7,8,9,10))
    check(parts.size == 2)
    check(parts[0][0] == 0xA0.toByte() && parts[0][1] == 0.toByte())
    check(parts[1][0] == 0xA0.toByte() && parts[1][1] == 1.toByte())
    check(receiver.receive(parts[0]).receivedData!!.contentEquals(byteArrayOf(1,2,3,4,5,6)))
    check(receiver.receive(parts[0]).receivedData == null) // reject duplicate
    check(receiver.receive(parts[1]).receivedData!!.contentEquals(byteArrayOf(7,8,9,10)))
    now = 300
    val ack = receiver.poll()
    check(ack.size == 1 && ack[0].size == 2)
    check(sender.receive(ack[0]).error == null)
    now = 1300
    check(sender.poll().isEmpty()) // all data acknowledged
    val retry = sender.send(byteArrayOf(55))[0]
    now = 2401
    val retransmit = sender.poll()
    check(retransmit.size == 1 && retransmit[0].contentEquals(retry))
    check(sender.receive(byteArrayOf(0,0)).error != null)
    sender.close()
    check(sender.send(byteArrayOf(99)).isEmpty())
    println("PASS Garmin MLR framing, fragments, duplicate suppression, ACK, retries, close")
}
