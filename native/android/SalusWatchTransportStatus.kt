package com.rustnrum.healthyme.beta03

import android.content.Context

/** Transport evidence is per device, never a claim that an alert appeared on-screen. */
object SalusWatchTransportStatus {
    private const val FILE = "salus_watch_transport_v1"
    private fun key(id: String) = id.replace(":", "").replace("-", "").lowercase()

    fun metadata(context: Context, deviceId: String, field: String, value: String) {
        if (deviceId.isBlank() || !field.matches(Regex("[A-Za-z0-9]+"))) return
        val k = key(deviceId)
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
            .putString("$k.meta_$field", value.take(180)).apply()
    }

    /** Append evidence without overwriting the current transport outcome. */
    fun note(context: Context, deviceId: String, kind: String, value: String) {
        if (deviceId.isBlank()) return
        val k = key(deviceId)
        val p = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val history = (p.getString("$k.history", "") ?: "").lines()
            .filter { it.isNotBlank() }.takeLast(23)
            .plus("${System.currentTimeMillis()} | $kind | ${value.take(180)}").joinToString("\n")
        p.edit().putString("$k.history", history).apply()
    }

    fun mark(context: Context, deviceId: String, stage: String, details: String = "") {
        if (deviceId.isBlank()) return
        val k = key(deviceId)
        val p = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val timestamp = System.currentTimeMillis()
        val safeDetails = details.take(250)
        val history = (p.getString("$k.history", "") ?: "")
            .lines().filter { it.isNotBlank() }.takeLast(23)
            .plus("$timestamp | $stage | $safeDetails")
            .joinToString("\n")
        p.edit().putString("$k.stage", stage)
            .putString("$k.details", safeDetails)
            .putLong("$k.updated", timestamp)
            .putString("$k.history", history)
            .apply()
    }

    fun state(context: Context, deviceId: String): Map<String, Any> {
        val k = key(deviceId)
        val p = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        return mapOf(
            "transportStage" to (p.getString("$k.stage", "Not attempted") ?: "Not attempted"),
            "transportDetails" to (p.getString("$k.details", "") ?: ""),
            "transportUpdatedAt" to p.getLong("$k.updated", 0L),
            "transportHistory" to (p.getString("$k.history", "") ?: ""),
        ) + SalusBluetoothDiagnostics.snapshot(context, deviceId)
    }
}
