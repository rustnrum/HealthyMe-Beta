import com.rustnrum.healthyme.beta03.SalusGarminRegistrationPolicy
import com.rustnrum.healthyme.beta03.SalusGarminRegistrationPolicy.Decision as D

fun main() {
    val p = SalusGarminRegistrationPolicy
    check(p.evaluate(false, 0, false, 135, true) == D.INITIAL)
    check(p.evaluate(true, 135, true, 135, true) == D.DUPLICATE)
    check(p.evaluate(true, 135, true, 135, false) == D.REPLACEMENT)
    check(p.evaluate(true, 135, true, 136, true) == D.REPLACEMENT)
    check(p.evaluate(true, 135, false, 135, false) == D.DUPLICATE)
    check(p.evaluate(false, 0, false, 130, false) == D.INITIAL)
    try {
        p.evaluate(false, 0, false, 0, true)
        error("Expected zero-handle rejection")
    } catch (_: IllegalArgumentException) {}
    println("PASS Build56 Garmin registration guard: initial, duplicates, replacement")
}
