package com.rustnrum.healthyme.beta03

/**
 * Parses Garmin's 5034 GET_NOTIFICATION_ATTRIBUTES request and constructs the
 * 5035 notification body using the attribute ordering and no-action sentinel
 * used by Gadgetbridge's Garmin NotificationsHandler (AGPL-3.0).
 *
 * No Android dependencies; can be exercised with recorded watch attribute lists.
 * Do not log actual notification text or account identifiers.
 */
object SalusGarminNotificationAttributes {
    data class Encoded(val bytes: ByteArray, val requestedIds: List<Int>)

    fun build(
        id: Int,
        sourcePackage: String,
        title: String,
        subtitle: String,
        message: String,
        date: String,
        request: ByteArray,
    ): Encoded? {
        val attributes = mutableListOf<Pair<Int, ByteArray>>()
        var messageSize: Pair<Int, ByteArray>? = null
        val requested = mutableListOf<Int>()
        var index = 0
        while (index < request.size) {
            val kind = request[index++].toInt() and 0xff
            var maxLength = 0 // Gadgetbridge interprets a length of zero as unlimited
            if (kind in listOf(1, 2, 3)) {
                if (index + 2 > request.size) return null
                maxLength = SalusGarminGfdiCodec.read16(request, index)
                index += 2
            } else if (kind == 127) {
                // The ACTIONS attribute includes an additional 3-byte request parameter.
                if (index + 3 > request.size) return null
                index += 3
            }
            val value: ByteArray = when (kind) {
                0 -> sourcePackage.toByteArray(Charsets.UTF_8)
                1 -> title.toByteArray(Charsets.UTF_8)
                2 -> subtitle.toByteArray(Charsets.UTF_8)
                3 -> message.toByteArray(Charsets.UTF_8)
                4 -> message.length.toString().toByteArray(Charsets.UTF_8)
                5 -> date.toByteArray(Charsets.UTF_8)
                7 -> byteArrayOf()
                127 -> byteArrayOf(0, 0, 0, 0) // Empty Garmin action list, NOT empty string
                128 -> "0".toByteArray(Charsets.UTF_8) // No attachments on Salus text alerts
                else -> return null // An unknown attribute should not be silently malformed
            }
            val limited = if (maxLength > 0) value.copyOf(minOf(value.size, maxLength)) else value
            val item = kind to limited
            requested.add(kind)
            // Gadgetbridge deliberately writes MESSAGE_SIZE last, irrespective of request order.
            if (kind == 4) messageSize = item else attributes.add(item)
        }
        if (messageSize != null) attributes.add(messageSize)
        return Encoded(SalusGarminGfdiCodec.notificationAttributesRaw(id, attributes), requested)
    }
}
