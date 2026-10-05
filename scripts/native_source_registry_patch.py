from pathlib import Path

MARKER = 'HEALTHY_ME_NATIVE_SOURCE_REGISTRY_V011'

path_candidates = list(Path('android/app/src/main/kotlin').rglob('MainActivity.kt'))
if not path_candidates:
    raise SystemExit('native source registry patch: MainActivity.kt not found')
path = path_candidates[0]
text = path.read_text()

if MARKER in text:
    print('Healthy Me v0.11 native source registry already present.')
    raise SystemExit(0)

# Android Context.HEALTHCONNECT_SERVICE is the literal "healthconnect".
# Older Healthy Me discovery code used "health_connect", which always returns
# no framework manager on Android 14+. Fix the generated MainActivity first.
text = text.replace(
    'private const val HEALTH_CONNECT_SERVICE_NAME = "health_connect"',
    'private const val HEALTH_CONNECT_SERVICE_NAME = "healthconnect"',
    1,
)
if 'private const val HEALTH_CONNECT_SERVICE_NAME = "healthconnect"' not in text:
    raise SystemExit('native source registry patch: Health Connect service name anchor missing')

handler_anchor = '''                "launchMatchmaking" -> launchMatchmaking(result)\n                "scanBle" -> {\n'''
handler_replacement = '''                "launchMatchmaking" -> launchMatchmaking(result)\n                "scanHealthOrigins" -> {\n                    val startMillis = call.argument<Number>("startMillis")?.toLong()\n                    val endMillis = call.argument<Number>("endMillis")?.toLong()\n                    if (startMillis == null || endMillis == null || endMillis <= startMillis) {\n                        result.error(\n                            "SOURCE_REGISTRY_RANGE_INVALID",\n                            "A valid Health Connect scan time range is required.",\n                            null,\n                        )\n                    } else {\n                        scanHealthOrigins(startMillis, endMillis, result)\n                    }\n                }\n                "scanBle" -> {\n'''
if handler_anchor not in text:
    raise SystemExit('native source registry patch: MethodChannel handler anchor not found')
text = text.replace(handler_anchor, handler_replacement, 1)

method_anchor = '''    private fun bluetoothManager(): BluetoothManager? =\n        getSystemService(BluetoothManager::class.java)\n'''
methods = r'''    // HEALTHY_ME_NATIVE_SOURCE_REGISTRY_V011
    // Reads Health Connect Record.metadata.dataOrigin.packageName directly.
    // Provider identity comes from Android record metadata, never a brand table.
    private fun scanHealthOrigins(
        startMillis: Long,
        endMillis: Long,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            result.success(
                mapOf(
                    "supported" to false,
                    "metrics" to emptyMap<String, Any>(),
                    "message" to "Native DataOrigin scan requires Android 14 or newer.",
                )
            )
            return
        }

        val manager = try {
            Class.forName("android.health.connect.HealthConnectManager")
            getSystemService(HEALTH_CONNECT_SERVICE_NAME)
        } catch (_: Throwable) {
            null
        }

        if (manager == null) {
            result.success(
                mapOf(
                    "supported" to false,
                    "metrics" to emptyMap<String, Any>(),
                    "message" to "Android Health Connect manager is unavailable.",
                )
            )
            return
        }

        val specs = listOf(
            "Steps" to "android.health.connect.datatypes.StepsRecord",
            "Sleep" to "android.health.connect.datatypes.SleepSessionRecord",
            "Heart rate" to "android.health.connect.datatypes.HeartRateRecord",
            "Resting heart rate" to "android.health.connect.datatypes.RestingHeartRateRecord",
            "HRV" to "android.health.connect.datatypes.HeartRateVariabilityRmssdRecord",
            "SpO2" to "android.health.connect.datatypes.OxygenSaturationRecord",
            "Respiratory rate" to "android.health.connect.datatypes.RespiratoryRateRecord",
            "Weight" to "android.health.connect.datatypes.WeightRecord",
            "Body fat" to "android.health.connect.datatypes.BodyFatRecord",
            "Body water" to "android.health.connect.datatypes.BodyWaterMassRecord",
            "Lean body mass" to "android.health.connect.datatypes.LeanBodyMassRecord",
            "Workouts" to "android.health.connect.datatypes.ExerciseSessionRecord",
        )

        val output = linkedMapOf<String, List<Map<String, Any?>>>()

        fun scanMetric(index: Int) {
            if (index >= specs.size) {
                result.success(
                    mapOf(
                        "supported" to true,
                        "metrics" to output,
                        "message" to "Android DataOrigin scan completed.",
                    )
                )
                return
            }

            val (metric, recordClassName) = specs[index]
            readOriginStatsForType(
                manager = manager,
                recordClassName = recordClassName,
                startMillis = startMillis,
                endMillis = endMillis,
            ) { stats, error ->
                if (error != null) {
                    // One unsupported/unreadable type must not hide all other
                    // providers. Record an empty metric and continue.
                    output[metric] = emptyList()
                } else {
                    output[metric] = stats
                }
                scanMetric(index + 1)
            }
        }

        scanMetric(0)
    }

    private fun readOriginStatsForType(
        manager: Any,
        recordClassName: String,
        startMillis: Long,
        endMillis: Long,
        done: (List<Map<String, Any?>>, Throwable?) -> Unit,
    ) {
        val recordClass = try {
            Class.forName(recordClassName)
        } catch (error: Throwable) {
            done(emptyList(), error)
            return
        }

        val counts = linkedMapOf<String, Int>()
        val lastSeen = linkedMapOf<String, Long>()
        var pagesRead = 0

        fun finish(error: Throwable? = null) {
            val rows = counts.entries
                .sortedBy { appLabelForPackage(it.key).lowercase() }
                .map { (packageName, count) ->
                    mapOf<String, Any?>(
                        "packageName" to packageName,
                        "label" to appLabelForPackage(packageName),
                        "recordCount" to count,
                        "lastSeenMillis" to (lastSeen[packageName] ?: 0L),
                    )
                }
            done(rows, error)
        }

        fun readPage(pageToken: Long?) {
            if (pagesRead >= 20) {
                finish()
                return
            }
            pagesRead += 1

            val request = try {
                buildReadRecordsRequest(
                    recordClass = recordClass,
                    startMillis = startMillis,
                    endMillis = endMillis,
                    pageToken = pageToken,
                )
            } catch (error: Throwable) {
                finish(error)
                return
            }

            val method = manager.javaClass.methods.firstOrNull {
                it.name == "readRecords" && it.parameterTypes.size == 3
            }
            if (method == null) {
                finish(NoSuchMethodException("HealthConnectManager.readRecords"))
                return
            }

            val receiver = object : OutcomeReceiver<Any, Throwable> {
                override fun onResult(response: Any) {
                    try {
                        val records = response.javaClass
                            .getMethod("getRecords")
                            .invoke(response) as? List<*> ?: emptyList<Any>()

                        for (record in records) {
                            if (record == null) continue
                            val packageName = recordOriginPackage(record)
                            if (packageName.isNullOrBlank()) continue

                            counts[packageName] = (counts[packageName] ?: 0) + 1
                            val time = recordTimeMillis(record)
                            val previous = lastSeen[packageName] ?: 0L
                            if (time > previous) lastSeen[packageName] = time
                        }

                        val nextToken = (response.javaClass
                            .getMethod("getNextPageToken")
                            .invoke(response) as? Number)?.toLong() ?: -1L

                        if (nextToken >= 0L) {
                            readPage(nextToken)
                        } else {
                            finish()
                        }
                    } catch (error: Throwable) {
                        finish(error)
                    }
                }

                override fun onError(error: Throwable) {
                    finish(error)
                }
            }

            try {
                method.invoke(manager, request, mainExecutor, receiver)
            } catch (error: InvocationTargetException) {
                finish(error.targetException ?: error)
            } catch (error: Throwable) {
                finish(error)
            }
        }

        readPage(null)
    }

    private fun buildReadRecordsRequest(
        recordClass: Class<*>,
        startMillis: Long,
        endMillis: Long,
        pageToken: Long?,
    ): Any {
        val timeBuilderClass =
            Class.forName("android.health.connect.TimeInstantRangeFilter\$Builder")
        val timeBuilder = timeBuilderClass.getConstructor().newInstance()
        timeBuilderClass.getMethod("setStartTime", java.time.Instant::class.java)
            .invoke(timeBuilder, java.time.Instant.ofEpochMilli(startMillis))
        timeBuilderClass.getMethod("setEndTime", java.time.Instant::class.java)
            .invoke(timeBuilder, java.time.Instant.ofEpochMilli(endMillis))
        val timeRange = timeBuilderClass.getMethod("build").invoke(timeBuilder)

        val builderClass =
            Class.forName("android.health.connect.ReadRecordsRequestUsingFilters\$Builder")
        val builder = builderClass.getConstructor(Class::class.java)
            .newInstance(recordClass)

        val timeRangeInterface = Class.forName("android.health.connect.TimeRangeFilter")
        builderClass.getMethod("setTimeRangeFilter", timeRangeInterface)
            .invoke(builder, timeRange)
        builderClass.getMethod("setPageSize", Int::class.javaPrimitiveType)
            .invoke(builder, 5000)

        if (pageToken == null) {
            builderClass.getMethod("setAscending", Boolean::class.javaPrimitiveType)
                .invoke(builder, false)
        } else {
            builderClass.getMethod("setPageToken", Long::class.javaPrimitiveType)
                .invoke(builder, pageToken)
        }

        return builderClass.getMethod("build").invoke(builder)
    }

    private fun recordOriginPackage(record: Any): String? {
        return try {
            val metadata = record.javaClass.getMethod("getMetadata").invoke(record)
                ?: return null
            val dataOrigin = metadata.javaClass.getMethod("getDataOrigin")
                .invoke(metadata) ?: return null
            dataOrigin.javaClass.getMethod("getPackageName")
                .invoke(dataOrigin)?.toString()
        } catch (_: Throwable) {
            null
        }
    }

    private fun recordTimeMillis(record: Any): Long {
        val methods = listOf("getEndTime", "getTime", "getStartTime")
        for (name in methods) {
            try {
                val method = record.javaClass.methods.firstOrNull {
                    it.name == name && it.parameterTypes.isEmpty()
                } ?: continue
                val value = method.invoke(record)
                if (value is java.time.Instant) return value.toEpochMilli()
            } catch (_: Throwable) {
            }
        }

        return try {
            val metadata = record.javaClass.getMethod("getMetadata").invoke(record)
                ?: return 0L
            val value = metadata.javaClass.getMethod("getLastModifiedTime")
                .invoke(metadata)
            if (value is java.time.Instant) value.toEpochMilli() else 0L
        } catch (_: Throwable) {
            0L
        }
    }

    private fun appLabelForPackage(packageName: String): String {
        return try {
            @Suppress("DEPRECATION")
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Throwable) {
            packageName
        }
    }

'''
if method_anchor not in text:
    raise SystemExit('native source registry patch: bluetoothManager anchor not found')
text = text.replace(method_anchor, methods + method_anchor, 1)
path.write_text(text)
print('Healthy Me v0.11 native Android DataOrigin source registry applied.')
