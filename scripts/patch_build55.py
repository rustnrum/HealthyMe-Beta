"""Patch Build 54's two diagnosed Garmin parser/transport defects.

Idempotent because the workflow runs prepare_android.sh on every build.
Fails closed on an unknown source layout. Never deletes stored user data.
"""
from pathlib import Path


def once_or_present(path: str, old: str, new: str) -> None:
    p = Path(path)
    content = p.read_text(encoding='utf-8')
    if new in content:
        return
    assert content.count(old) == 1, f'Unexpected patch anchor in {path}: {old[:80]!r}'
    p.write_text(content.replace(old, new, 1), encoding='utf-8')


attribute_path = 'native/android/SalusGarminNotificationAttributes.kt'
mlr_path = 'native/android/SalusGarminMlrTransport.kt'
sender_path = 'native/android/SalusGarminNotificationSender.kt'

# Gadgetbridge NotificationAttribute.NEGATIVE_ACTION_LABEL(7) has no length parameter.
# Build 54 assumed it had one and therefore rejected an otherwise valid 5034 request.
once_or_present(attribute_path,
                'if (kind in listOf(1, 2, 3, 7)) {',
                'if (kind in listOf(1, 2, 3)) {')

# The sender's ACK window validation is stricter than upstream Gadgetbridge.
# It must not discard application data from a received in-sequence fragment when
# its piggybacked cumulative ACK cannot be applied to the local transmit window.
once_or_present(mlr_path,
                '        val emitted = mutableListOf<ByteArray>()\n        val distance =',
                '        val emitted = mutableListOf<ByteArray>()\n        var ignoredAck: String? = null\n        val distance =')
once_or_present(mlr_path,
                '        } else if (distance != 0) {\n            return Result(null, emptyList(), "invalid cumulative ACK")\n        }',
                '''        } else if (distance != 0) {
            // The peer's acknowledgment is outside our current send window.
            // It must not advance outgoing state, but incoming in-sequence GFDI
            // data still needs processing and an MLR acknowledgment.
            ignoredAck = "req=$request peerAck=$lastPeerAck sent=$nextSend seq=$sequence"
        }''')
once_or_present(mlr_path,
                '        return Result(data, emitted)\n    }',
                '        return Result(data, emitted, ignoredAck)\n    }')

# Log only the first few anomalous MLR ack values to avoid flooding diagnostics.
once_or_present(sender_path,
                '        private var mlr: SalusGarminMlrTransport? = null',
                '        private var mlr: SalusGarminMlrTransport? = null\n        private var ignoredMlrAckCount = 0')
once_or_present(sender_path,
                '            mlr?.close(); mlr = null; mlrRequested = true',
                '            mlr?.close(); mlr = null; mlrRequested = true\n            ignoredMlrAckCount = 0')
once_or_present(sender_path,
                '                    received.error?.let { stage("Garmin MLR packet rejected", it) }',
                '''                    received.error?.let { reason ->
                        if (reason.startsWith("req=")) {
                            if (++ignoredMlrAckCount <= 3) {
                                stage("Garmin MLR out-of-window ACK", "$reason; incoming payload processed separately")
                            }
                        } else stage("Garmin MLR packet rejected", reason)
                    }''')

# The 5034 request attribute selectors are protocol metadata, not user messages.
# Record them if the watch asks for an unknown attribute so its actual ID is
# available for one controlled watch test, without logging any notification body.
once_or_present(sender_path,
                '                stage("Garmin attribute request unsupported", "Watch requested a malformed or unknown attribute; do not fabricate payload")',
                '''                val selectorHex = request.take(40).joinToString(" ") {
                    "%02X".format(it.toInt() and 255)
                }
                stage("Garmin attribute request unsupported",
                    "Malformed/unknown 5034 attribute selectors (hex)=$selectorHex; size=${request.size}")''')

# Advance the installed app build. Build 54 source tests include fixed version
# literals and must be advanced rather than disabled.
once_or_present('pubspec.yaml', 'version: 0.21.16+54', 'version: 0.21.17+55')
for test in ('test/build52_garmin_attribute_payload_contract_test.dart',
             'test/build54_garmin_protocol_contract_test.dart'):
    once_or_present(test, '0.21.16+54', '0.21.17+55')

print('Build 55 repairs applied: Garmin attribute 7, nonfatal unexpected MLR ACK, safe diagnostics, version.')
