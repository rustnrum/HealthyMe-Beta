import com.rustnrum.healthyme.beta03.SalusGarminNotificationAttributes
import com.rustnrum.healthyme.beta03.SalusGarminGfdiCodec

fun main() {
    val req = byteArrayOf(4, 1, 10, 0, 3, 40, 0, 127.toByte(), 0, 0, 0, 0, 5)
    val result = SalusGarminNotificationAttributes.build(12345, "com.rustnrum.healthyme.beta03", "Salus test", "",
        "Direct Bluetooth notification test", "20261009T112638", req) ?: error("payload absent")
    val raw = result.bytes
    check(raw[0].toInt() == 0)
    check(SalusGarminGfdiCodec.read32(raw,1) == 12345)
    val ids = mutableListOf<Int>()
    var offset = 5
    while (offset < raw.size) {
        val id = raw[offset++].toInt() and 255
        val count = SalusGarminGfdiCodec.read16(raw,offset); offset += 2
        val bytes = raw.copyOfRange(offset,offset+count);offset+=count
        ids.add(id)
        when (id) {
            1 -> check(String(bytes) == "Salus test")
            3 -> check(String(bytes) == "Direct Bluetooth notification test")
            127 -> check(bytes.contentEquals(byteArrayOf(0,0,0,0)))
            4 -> check(String(bytes) == "34")
        }
    }
    check(ids == listOf(1,3,127,0,5,4)) { "Gadgetbridge order mismatch: $ids" }
    check(result.requestedIds == listOf(4,1,3,127,0,5))
    check(SalusGarminNotificationAttributes.build(1,"a","t","","msg","date",byteArrayOf(99)) == null)
    check(SalusGarminNotificationAttributes.build(1,"a","t","","msg","date",byteArrayOf(1,20)) == null)
    val nonAscii = SalusGarminNotificationAttributes.build(1,"a","t","","éé","date",byteArrayOf(3,3,0))!!
    // UTF-8 bytes must obey the requested field length, regardless of character count.
    val valueLen = SalusGarminGfdiCodec.read16(nonAscii.bytes,6)
    check(valueLen == 3)
    println("PASS Garmin request attribute order, 4-NUL action sentinel, unknown/malformed, UTF8 length")
}
