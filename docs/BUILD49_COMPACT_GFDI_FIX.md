# Build 49: Garmin compact GFDI messages (verified root cause from Build 48 log)

Salus Build 48 recorded GFDI type integers `34340`, `34091`, `33579`, `33835`
while saying it had **not received** notification subscription 5036.
The root cause was the native `decodeGfdi` implementation treating the two-byte
GFDI header as a plain 16-bit message ID. Garmin additionally uses a documented
compact sequenced header: a low byte `type - 5000` and high byte `0x80 | sequence`.

Thus:
- `34340 = 0x8624` is **5036, notification subscription, sequence 6**.
- `34091 = 0x852B` is 5043, protobuf request, sequence 5.
- `33579 = 0x832B` is 5043, sequence 3.
- `33835 = 0x842B` is 5043, sequence 4.

Reference: https://gadgetbridge.org/internals/specifics/garmin-protocol/
(section GFDI; ACKs preserve the request sequence).

Implemented a central typed frame decoder, sequence-matched GFDI replies,
complete and chunked protobuf transport ACKs per Gadgetbridge message layout,
and readable HH:mm:ss transport history. All Bluetooth capability, pairing,
app selection, and signing behavior is otherwise preserved.

Run Kotlin byte fixture tests using:

```sh
kotlinc native/android/SalusGarminGfdiCodec.kt test/garmin_sequenced_gfdi_check.kt -include-runtime -d /tmp/salus-garmin-gfdi-check.jar
java -jar /tmp/salus-garmin-gfdi-check.jar
```

IMPORTANT: these tests show wire correctness, not that a physical Garmin watch
accepted the outgoing frames, requested notification attributes, or displayed
an alert. Build and real watch test are still required.
