import com.rustnrum.healthyme.beta03.SalusGarminGfdiCodec as C

fun main() {
    // Exact compact type bytes observed by Build 48 (0x8624 -> Garmin 5036).
    val cases = listOf(0x8624 to 5036, 0x852B to 5043, 0x832B to 5043, 0x842B to 5043)
    for ((wireType, decodedType) in cases) {
        val high = wireType ushr 8
        val seq = high and 31
        val body = if (decodedType == 5036) byteArrayOf(1, 0) else ByteArray(14)
        val frame = C.gfdiMessage(decodedType, body, seq)
        check((frame[2].toInt() and 255) == (wireType and 255))
        check((frame[3].toInt() and 255) == high)
        val parsed = C.decodeFrame(frame) ?: error("Failed to parse sequenced Garmin frame")
        check(parsed.type == decodedType) { "got ${parsed.type}, expected $decodedType" }
        check(parsed.sequence == seq)
        check(parsed.payload.contentEquals(body))
        val cobs = C.cobsEncode(frame)
        val decoded = C.cobsDecode(cobs) ?: error("Garmin COBS failed")
        check(decoded.contentEquals(frame))
        println("PASS: compact raw type $wireType decodes as $decodedType, sequence $seq")
    }
    // Host permission is independent of the Garmin-requested watch subscription.
    val offRequest = C.notificationSubscriptionResponse(false, true, sequence = 6)
    val subscriptionAck = C.decodeFrame(offRequest) ?: error("Invalid subscription ACK")
    check(subscriptionAck.type == 5000 && subscriptionAck.sequence == 6)
    check(C.read16(subscriptionAck.payload, 0) == 5036)
    check(subscriptionAck.payload.contentEquals(byteArrayOf(0xAC.toByte(), 0x13, 0, 0, 0, 0)))
    println("PASS: Garmin off request receives ACK with phone notifications allowed")
    val onRequest = C.notificationSubscriptionResponse(true, true, sequence = 7)
    val onAck = C.decodeFrame(onRequest) ?: error("Invalid on-subscription ACK")
    check(onAck.sequence == 7 && onAck.payload.contentEquals(byteArrayOf(0xAC.toByte(), 0x13, 0, 0, 1, 0)))
    println("PASS: Garmin on request receives enabled host status, echoes watch subscription")
    val denied = C.notificationSubscriptionResponse(true, false, sequence = 8)
    val deniedAck = C.decodeFrame(denied) ?: error("Invalid host denial ACK")
    check(deniedAck.sequence == 8 && deniedAck.payload.contentEquals(byteArrayOf(0xAC.toByte(), 0x13, 0, 1, 1, 0)))
    println("PASS: Host opt-out is correctly distinguished from watch subscription")
    val protobufAck = C.protobufChunkAck(5043, 42, 200, 5)
    val parsedProtoAck = C.decodeFrame(protobufAck) ?: error("Invalid protobuf chunk ACK")
    check(parsedProtoAck.type == 5000 && parsedProtoAck.sequence == 5)
    check(C.read16(parsedProtoAck.payload, 0) == 5043)
    check(C.read16(parsedProtoAck.payload, 3) == 42)
    check(C.read32(parsedProtoAck.payload, 5) == 200)
    println("PASS: Garmin 5043 chunk acknowledgement matches request sequence 5")
    val normal = C.gfdiMessage(5050, byteArrayOf(1, 0))
    val parsedNormal = C.decodeFrame(normal) ?: error("Failed to parse unsequenced Garmin frame")
    check(parsedNormal.type == 5050 && parsedNormal.sequence == null)
    println("PASS: normal Garmin GFDI message remains compatible")
    val bad = normal.clone().apply { this[6] = (this[6].toInt() xor 7).toByte() }
    check(C.decodeFrame(bad) == null)
    println("PASS: corrupt Garmin checksum rejected")
}
