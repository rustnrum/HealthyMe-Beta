from pathlib import Path

MARKER = 'SALUS_DIRECT_DEVICE_PAIRING_V023'

paths = list(Path('android/app/src/main/kotlin').rglob('MainActivity.kt'))
if not paths:
    raise SystemExit('direct device native patch: MainActivity.kt not found')
path = paths[0]
text = path.read_text()

if MARKER in text:
    print('Salus direct-device native pairing already present.')
    raise SystemExit(0)

# Add pairBle MethodChannel method before the fallback handler.
handler_anchor = '                else -> result.notImplemented()\n'
handler_block = '''                "pairBle" -> {
                    val deviceId = call.argument<String>("deviceId")
                    if (deviceId.isNullOrBlank()) {
                        result.error(
                            "BLE_DEVICE_ID_MISSING",
                            "Bluetooth device id is required.",
                            null,
                        )
                    } else {
                        pairBle(deviceId, result)
                    }
                }
'''
if handler_anchor not in text:
    raise SystemExit('direct device native patch: MethodChannel fallback anchor missing')
text = text.replace(handler_anchor, handler_block + handler_anchor, 1)

# Preserve current scan output and add Android bond state for diagnostics.
scan_anchor = '''                    "manufacturerDataHex" to manufacturerDataHex(scanResult),
                )
'''
scan_replacement = '''                    "manufacturerDataHex" to manufacturerDataHex(scanResult),
                    "bondState" to bondStateLabel(device.bondState),
                )
'''
if scan_anchor not in text:
    raise SystemExit('direct device native patch: scan result map anchor missing')
text = text.replace(scan_anchor, scan_replacement, 1)

method_anchor = '''    @SuppressLint("MissingPermission")
    private fun inspectBle(deviceId: String, result: MethodChannel.Result) {
'''
methods = r'''    // SALUS_DIRECT_DEVICE_PAIRING_V023
    private fun bondStateLabel(state: Int): String =
        when (state) {
            BluetoothDevice.BOND_BONDED -> "bonded"
            BluetoothDevice.BOND_BONDING -> "bonding"
            BluetoothDevice.BOND_NONE -> "not-bonded"
            else -> "unknown"
        }

    @SuppressLint("MissingPermission")
    private fun pairBle(deviceId: String, result: MethodChannel.Result) {
        if (!hasBluetoothPermission()) {
            result.error(
                "BLE_PERMISSION_DENIED",
                "Bluetooth scan/connect permission is required.",
                null,
            )
            return
        }

        val adapter = bluetoothManager()?.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error(
                "BLE_UNAVAILABLE",
                "Bluetooth is unavailable or turned off.",
                null,
            )
            return
        }

        val device = try {
            adapter.getRemoteDevice(deviceId)
        } catch (error: Throwable) {
            result.error(
                "BLE_DEVICE_INVALID",
                error.message ?: "Bluetooth device address is invalid.",
                null,
            )
            return
        }

        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            result.success(
                mapOf(
                    "usable" to true,
                    "bonded" to true,
                    "state" to "bonded",
                    "message" to "Android pairing is already established. Salus saved this as a direct device.",
                )
            )
            return
        }

        val started = try {
            device.createBond()
        } catch (_: Throwable) {
            false
        }

        if (!started) {
            // A large number of BLE health peripherals deliberately do not use
            // Android bonding. They remain usable through direct GATT, so a
            // failed createBond() is not treated as a failed Salus connection.
            result.success(
                mapOf(
                    "usable" to true,
                    "bonded" to false,
                    "state" to bondStateLabel(device.bondState),
                    "message" to "This device did not start Android bonding. Salus can still save it for direct GATT communication.",
                )
            )
            return
        }

        var checks = 0
        fun pollBond() {
            val state = try {
                device.bondState
            } catch (_: Throwable) {
                BluetoothDevice.BOND_NONE
            }

            if (state == BluetoothDevice.BOND_BONDED) {
                result.success(
                    mapOf(
                        "usable" to true,
                        "bonded" to true,
                        "state" to "bonded",
                        "message" to "Paired directly with Android and saved for Salus.",
                    )
                )
                return
            }

            checks += 1
            if (checks >= 60) {
                result.success(
                    mapOf(
                        "usable" to true,
                        "bonded" to false,
                        "state" to bondStateLabel(state),
                        "message" to "Pairing did not finish within 30 seconds. The device is still saved for direct Salus inspection and can be retried.",
                    )
                )
                return
            }

            mainHandler.postDelayed({ pollBond() }, 500L)
        }

        pollBond()
    }

'''
if method_anchor not in text:
    raise SystemExit('direct device native patch: inspectBle method anchor missing')
text = text.replace(method_anchor, methods + method_anchor, 1)

path.write_text(text)
print('Salus build 23 native direct-device pairing bridge applied.')
