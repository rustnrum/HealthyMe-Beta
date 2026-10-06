from pathlib import Path

MARKER = 'SALUS_DIRECT_STANDARD_METRICS_V026'

paths = list(Path('android/app/src/main/kotlin').rglob('MainActivity.kt'))
if not paths:
    raise SystemExit('direct metric native patch: MainActivity.kt not found')
path = paths[0]
text = path.read_text()

if MARKER in text:
    print('Salus build 26 standard direct metric reader already present.')
    raise SystemExit(0)

if 'import android.bluetooth.BluetoothGattDescriptor\n' not in text:
    anchor = 'import android.bluetooth.BluetoothGattCharacteristic\n'
    if anchor not in text:
        raise SystemExit('direct metric native patch: BluetoothGattCharacteristic import missing')
    text = text.replace(
        anchor,
        anchor + 'import android.bluetooth.BluetoothGattDescriptor\n',
        1,
    )

if 'import java.util.UUID\n' not in text:
    anchor = 'import java.util.concurrent.Executor\n'
    if anchor not in text:
        raise SystemExit('direct metric native patch: Executor import missing')
    text = text.replace(anchor, 'import java.util.UUID\n' + anchor, 1)

if 'import kotlin.math.sqrt\n' not in text:
    anchor = 'import java.util.concurrent.atomic.AtomicBoolean\n'
    if anchor not in text:
        raise SystemExit('direct metric native patch: AtomicBoolean import missing')
    text = text.replace(anchor, anchor + 'import kotlin.math.sqrt\n', 1)

handler_anchor = '                else -> result.notImplemented()\n'
handler = '''                "readStandardMetrics" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val durationMs =
                        (call.argument<Number>("durationMs")?.toLong()
                            ?: 8000L).coerceIn(3000L, 15000L)
                    if (deviceId.isNullOrBlank()) {
                        result.error(
                            "BLE_DEVICE_ID_MISSING",
                            "Bluetooth device id is required.",
                            null,
                        )
                    } else {
                        readStandardMetrics(deviceId, durationMs, result)
                    }
                }
'''
if handler_anchor not in text:
    raise SystemExit('direct metric native patch: handler fallback anchor missing')
text = text.replace(handler_anchor, handler + handler_anchor, 1)

method_anchor = '''    @SuppressLint("MissingPermission")
    private fun inspectBle(deviceId: String, result: MethodChannel.Result) {
'''
method = r'''    // SALUS_DIRECT_STANDARD_METRICS_V026
    @SuppressLint("MissingPermission")
    private fun readStandardMetrics(
        deviceId: String,
        durationMs: Long,
        result: MethodChannel.Result,
    ) {
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

        val completed = AtomicBoolean(false)
        val rrIntervalsMs = mutableListOf<Double>()
        var latestHeartRate: Int? = null
        var gattRef: BluetoothGatt? = null

        fun closeGatt() {
            try {
                gattRef?.disconnect()
            } catch (_: Throwable) {
            }
            try {
                gattRef?.close()
            } catch (_: Throwable) {
            }
        }

        fun finish(messageOverride: String? = null) {
            if (!completed.compareAndSet(false, true)) return

            val metrics = mutableMapOf<String, Double>()
            latestHeartRate?.let { metrics["Heart rate"] = it.toDouble() }

            if (rrIntervalsMs.size >= 3) {
                var sumSquares = 0.0
                var count = 0
                for (index in 1 until rrIntervalsMs.size) {
                    val delta = rrIntervalsMs[index] - rrIntervalsMs[index - 1]
                    sumSquares += delta * delta
                    count += 1
                }
                if (count > 0) {
                    metrics["HRV"] = sqrt(sumSquares / count)
                }
            }

            val message =
                messageOverride
                    ?: if (metrics.isEmpty()) {
                        "Paired, but no standard Heart Rate measurement arrived. On Garmin, enable Broadcast Heart Rate and try Read data again. Sleep, steps and history use Garmin's proprietary sync protocol and are not being faked."
                    } else {
                        "Read direct Bluetooth data from the device."
                    }

            closeGatt()
            mainHandler.post {
                result.success(
                    mapOf(
                        "metrics" to metrics,
                        "rrCount" to rrIntervalsMs.size,
                        "message" to message,
                    )
                )
            }
        }

        fun handleHeartRate(bytes: ByteArray) {
            if (bytes.size < 2) return
            val flags = bytes[0].toInt() and 0xff
            val heartRate16Bit = flags and 0x01 != 0
            var offset = 1

            latestHeartRate =
                if (heartRate16Bit) {
                    if (bytes.size < 3) return
                    val value =
                        (bytes[1].toInt() and 0xff) or
                            ((bytes[2].toInt() and 0xff) shl 8)
                    offset = 3
                    value
                } else {
                    bytes[1].toInt() and 0xff
                }

            val energyPresent = flags and 0x08 != 0
            if (energyPresent) offset += 2

            val rrPresent = flags and 0x10 != 0
            if (!rrPresent) return

            while (offset + 1 < bytes.size) {
                val raw =
                    (bytes[offset].toInt() and 0xff) or
                        ((bytes[offset + 1].toInt() and 0xff) shl 8)
                if (raw > 0) {
                    rrIntervalsMs.add(raw * 1000.0 / 1024.0)
                }
                offset += 2
            }
        }

        val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(
                gatt: BluetoothGatt,
                status: Int,
                newState: Int,
            ) {
                gattRef = gatt
                if (status == BluetoothGatt.GATT_SUCCESS &&
                    newState == BluetoothProfile.STATE_CONNECTED
                ) {
                    val started = try {
                        gatt.discoverServices()
                    } catch (_: Throwable) {
                        false
                    }
                    if (!started) {
                        finish("Connected, but Salus could not start Bluetooth service discovery.")
                    }
                    return
                }

                if (newState == BluetoothProfile.STATE_DISCONNECTED &&
                    !completed.get()
                ) {
                    finish(
                        if (latestHeartRate == null) {
                            "The device disconnected before a standard health measurement arrived."
                        } else {
                            null
                        }
                    )
                } else if (status != BluetoothGatt.GATT_SUCCESS &&
                    !completed.get()
                ) {
                    finish("Bluetooth connection failed with status $status.")
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    finish("Bluetooth service discovery failed with status $status.")
                    return
                }

                val heartService =
                    gatt.getService(
                        UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
                    )
                val heartMeasurement =
                    heartService?.getCharacteristic(
                        UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
                    )

                if (heartMeasurement == null) {
                    finish(
                        "This device is paired, but it is not exposing the standard live Heart Rate characteristic right now. Salus will keep it paired while a device-specific reader is added."
                    )
                    return
                }

                try {
                    gatt.setCharacteristicNotification(heartMeasurement, true)
                    val descriptor =
                        heartMeasurement.getDescriptor(
                            UUID.fromString(
                                "00002902-0000-1000-8000-00805f9b34fb"
                            )
                        )
                    if (descriptor != null) {
                        val indicate =
                            heartMeasurement.properties and
                                BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
                        @Suppress("DEPRECATION")
                        descriptor.value =
                            if (indicate) {
                                BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                            } else {
                                BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                            }
                        @Suppress("DEPRECATION")
                        gatt.writeDescriptor(descriptor)
                    }
                } catch (_: Throwable) {
                    finish("Salus found Heart Rate, but could not subscribe to its measurements.")
                    return
                }

                mainHandler.postDelayed({ finish() }, durationMs)
            }

            @Deprecated("Deprecated in Java")
            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
            ) {
                val value = characteristic.value ?: return
                if (characteristic.uuid.toString().equals(
                        "00002a37-0000-1000-8000-00805f9b34fb",
                        ignoreCase = true,
                    )
                ) {
                    handleHeartRate(value)
                }
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray,
            ) {
                if (characteristic.uuid.toString().equals(
                        "00002a37-0000-1000-8000-00805f9b34fb",
                        ignoreCase = true,
                    )
                ) {
                    handleHeartRate(value)
                }
            }
        }

        try {
            gattRef =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    device.connectGatt(
                        this,
                        false,
                        callback,
                        BluetoothDevice.TRANSPORT_LE,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    device.connectGatt(this, false, callback)
                }
        } catch (error: Throwable) {
            result.error(
                "BLE_GATT_CONNECT_FAILED",
                error.message ?: error.javaClass.simpleName,
                null,
            )
            return
        }

        mainHandler.postDelayed({
            if (!completed.get()) finish()
        }, durationMs + 4000L)
    }

'''
if method_anchor not in text:
    raise SystemExit('direct metric native patch: inspectBle anchor missing')
text = text.replace(method_anchor, method + method_anchor, 1)

path.write_text(text)
print('Salus build 26 standard direct metric native reader applied.')
