/*
 * Salus-owned session state decision, separate from Android GATT for testing.
 * Do not replace a live reliable Garmin connection on a duplicate register ACK.
 */
package com.rustnrum.healthyme.beta03

object SalusGarminRegistrationPolicy {
    enum class Decision { INITIAL, DUPLICATE, REPLACEMENT }

    fun evaluate(
        registered: Boolean,
        activeHandle: Int,
        activeReliable: Boolean,
        newHandle: Int,
        newReliable: Boolean,
    ): Decision {
        require(newHandle in 1..255)
        if (!registered || activeHandle <= 0) return Decision.INITIAL
        return if (activeHandle == newHandle && activeReliable == newReliable)
            Decision.DUPLICATE else Decision.REPLACEMENT
    }
}
