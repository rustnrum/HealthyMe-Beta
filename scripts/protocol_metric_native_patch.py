from pathlib import Path

paths = list(Path('android/app/src/main/kotlin').rglob('MainActivity.kt'))
if not paths:
    raise SystemExit('protocol metric native patch: MainActivity.kt not found')
main = paths[0]
text = main.read_text()

if '"readProtocolMetrics" ->' not in text:
    anchor = '                else -> result.notImplemented()\n'
    block = '''                "readProtocolMetrics" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val deviceName = call.argument<String>("deviceName") ?: ""
                    val protocolId = call.argument<String>("protocolId") ?: ""
                    val durationMs =
                        (call.argument<Number>("durationMs")?.toLong()
                            ?: 16000L).coerceIn(5000L, 24000L)
                    if (deviceId.isNullOrBlank()) {
                        result.error(
                            "BLE_DEVICE_ID_MISSING",
                            "Bluetooth device id is required.",
                            null,
                        )
                    } else {
                        SalusProtocolReader(this, mainHandler)
                            .read(deviceId, deviceName, protocolId, durationMs, result)
                    }
                }
'''
    if anchor not in text:
        raise SystemExit('protocol metric native patch: MethodChannel fallback anchor missing')
    text = text.replace(anchor, block + anchor, 1)
    main.write_text(text)

source = Path('scripts/SalusProtocolReader.kt.template')
if not source.exists():
    raise SystemExit('protocol metric native patch: Kotlin template missing')
target = main.parent / 'SalusProtocolReader.kt'
target.write_text(source.read_text())
print('Salus build 33 protocol reader bridge applied.')
