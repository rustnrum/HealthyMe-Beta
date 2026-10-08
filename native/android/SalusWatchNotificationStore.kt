package com.rustnrum.healthyme.beta03

import android.content.Context
import android.content.pm.PackageManager

/** All watch notification forwarding is opt-in and local to the device. */
object SalusWatchNotificationStore {
    private const val PREFS = "salus_watch_notifications_v1"
    private const val TARGETS = "targets"
    private const val OBSERVED_APPS = "observed_apps"
    private const val GMAIL_ACCOUNTS = "gmail_accounts"
    private const val SEEN_AT = "listener_seen_at"
    private const val ELIGIBLE_AT = "listener_eligible_at"
    private const val ELIGIBLE_APP = "listener_eligible_app"

    const val GMAIL_PACKAGE = "com.google.android.gm"
    const val UNKNOWN_GMAIL_ACCOUNT = "Other / unknown account"

    data class Target(
        val key: String,
        val deviceId: String,
        val deviceName: String,
        val protocolId: String,
    )

    private data class KnownApp(
        val packageName: String,
        val fallbackLabel: String,
    )

    private val commonApps = listOf(
        KnownApp("com.google.android.dialer", "Phone calls"),
        KnownApp("com.samsung.android.dialer", "Phone calls"),
        KnownApp("com.google.android.apps.messaging", "Text messages"),
        KnownApp("com.samsung.android.messaging", "Text messages"),
        KnownApp(GMAIL_PACKAGE, "Gmail"),
        KnownApp("com.facebook.orca", "Messenger"),
        KnownApp("com.facebook.katana", "Facebook"),
        KnownApp("com.whatsapp", "WhatsApp"),
        KnownApp("com.instagram.android", "Instagram"),
        KnownApp("com.discord", "Discord"),
        KnownApp("com.snapchat.android", "Snapchat"),
        KnownApp("com.google.android.calendar", "Google Calendar"),
        KnownApp("com.samsung.android.calendar", "Samsung Calendar"),
        KnownApp("com.microsoft.office.outlook", "Outlook"),
        KnownApp("org.telegram.messenger", "Telegram"),
        KnownApp("org.thoughtcrime.securesms", "Signal"),
        KnownApp("com.linkedin.android", "LinkedIn"),
        KnownApp("com.twitter.android", "X"),
        KnownApp("com.microsoft.teams", "Microsoft Teams"),
        KnownApp("com.Slack", "Slack"),
    )

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun targetKey(deviceId: String): String =
        deviceId.replace(":", "").replace("-", "").lowercase()

    private fun safe(value: String): String =
        value.replace("|", "_").replace("\n", " ").trim()

    /** Enabling the master switch opts into currently installed or observed apps.
     * Previously chosen app toggles are NEVER overridden by another master toggle.
     * New apps discovered later are opt-in individually, not silently forwarded.
     */
    fun setMaster(
        context: Context,
        deviceId: String,
        deviceName: String,
        protocolId: String,
        enabled: Boolean,
    ) {
        val key = targetKey(deviceId)
        val p = prefs(context)
        val targets = p.getStringSet(TARGETS, emptySet())?.toMutableSet()
            ?: mutableSetOf()
        targets.add(key)
        val editor = p.edit()
            .putStringSet(TARGETS, targets)
            .putString("$key.deviceId", deviceId)
            .putString("$key.deviceName", deviceName)
            .putString("$key.protocolId", protocolId)
            .putBoolean("$key.master", enabled)

        if (enabled && !p.getBoolean("$key.initialAppsConfigured", false)) {
            // Master off by default: this is only reached after explicit opt-in.
            for (packageName in visibleApps(context, p).keys) {
                val pref = "$key.app.${safe(packageName)}"
                if (!p.contains(pref)) editor.putBoolean(pref, true)
            }
            editor.putBoolean("$key.initialAppsConfigured", true)
        }
        editor.apply()
    }

    fun setApp(
        context: Context,
        deviceId: String,
        packageName: String,
        enabled: Boolean,
    ) {
        prefs(context).edit()
            .putBoolean("${targetKey(deviceId)}.app.${safe(packageName)}", enabled)
            .apply()
    }

    fun setAllAccounts(
        context: Context,
        deviceId: String,
        packageName: String,
        enabled: Boolean,
    ) {
        prefs(context).edit()
            .putBoolean("${targetKey(deviceId)}.allAccounts.${safe(packageName)}", enabled)
            .apply()
    }

    fun setAccount(
        context: Context,
        deviceId: String,
        packageName: String,
        account: String,
        enabled: Boolean,
    ) {
        prefs(context).edit()
            .putBoolean(
                "${targetKey(deviceId)}.account.${safe(packageName)}.${safe(account.lowercase())}",
                enabled,
            )
            .apply()
    }

    fun recordObservedApp(context: Context, packageName: String, label: String) {
        if (packageName.isBlank() || packageName == context.packageName) return
        val p = prefs(context)
        val apps = p.getStringSet(OBSERVED_APPS, emptySet())?.toMutableSet()
            ?: mutableSetOf()
        apps.add(packageName)
        p.edit()
            .putStringSet(OBSERVED_APPS, apps)
            .putString("observed.label.${safe(packageName)}", label)
            .putLong(SEEN_AT, System.currentTimeMillis())
            .apply()
    }

    fun recordEligibleNotification(context: Context, packageName: String) {
        prefs(context).edit()
            .putLong(ELIGIBLE_AT, System.currentTimeMillis())
            .putString(ELIGIBLE_APP, packageName)
            .apply()
    }

    fun recordGmailAccount(context: Context, account: String) {
        if (account.isBlank()) return
        val p = prefs(context)
        val values = p.getStringSet(GMAIL_ACCOUNTS, emptySet())?.toMutableSet()
            ?: mutableSetOf()
        values.add(account)
        p.edit().putStringSet(GMAIL_ACCOUNTS, values).apply()
    }

    fun targets(context: Context): List<Target> {
        val p = prefs(context)
        return (p.getStringSet(TARGETS, emptySet()) ?: emptySet())
            .mapNotNull { key ->
                if (!p.getBoolean("$key.master", false)) return@mapNotNull null
                val id = p.getString("$key.deviceId", null) ?: return@mapNotNull null
                Target(
                    key = key,
                    deviceId = id,
                    deviceName = p.getString("$key.deviceName", "Watch") ?: "Watch",
                    protocolId = p.getString("$key.protocolId", "") ?: "",
                )
            }
    }

    fun isAllowed(
        context: Context,
        target: Target,
        packageName: String,
        gmailAccount: String?,
    ): Boolean {
        val p = prefs(context)
        if (!p.getBoolean("${target.key}.master", false)) return false
        if (!p.getBoolean("${target.key}.app.${safe(packageName)}", false)) {
            return false
        }
        if (packageName != GMAIL_PACKAGE) return true
        if (p.getBoolean("${target.key}.allAccounts.${safe(packageName)}", true)) {
            return true
        }
        val account = gmailAccount ?: UNKNOWN_GMAIL_ACCOUNT
        return p.getBoolean(
            "${target.key}.account.${safe(packageName)}.${safe(account.lowercase())}",
            false,
        )
    }

    fun state(
        context: Context,
        deviceId: String,
        deviceName: String,
        protocolId: String,
        accessEnabled: Boolean,
    ): Map<String, Any> {
        val key = targetKey(deviceId)
        val p = prefs(context)
        val targets = p.getStringSet(TARGETS, emptySet())?.toMutableSet()
            ?: mutableSetOf()
        targets.add(key)
        p.edit()
            .putStringSet(TARGETS, targets)
            .putString("$key.deviceId", deviceId)
            .putString("$key.deviceName", deviceName)
            .putString("$key.protocolId", protocolId)
            .apply()

        val apps = visibleApps(context, p)
        val maps = apps.entries.sortedBy { it.value.lowercase() }.map { entry ->
            val packageName = entry.key
            val accounts = if (packageName == GMAIL_PACKAGE) {
                val values = p.getStringSet(GMAIL_ACCOUNTS, emptySet()) ?: emptySet()
                values.sorted().map { account ->
                    mapOf(
                        "name" to account,
                        "enabled" to p.getBoolean(
                            "$key.account.${safe(packageName)}.${safe(account.lowercase())}",
                            false,
                        ),
                    )
                }
            } else emptyList()

            mapOf(
                "packageName" to packageName,
                "label" to friendlyLabel(packageName, entry.value),
                "enabled" to p.getBoolean("$key.app.${safe(packageName)}", false),
                "allAccounts" to p.getBoolean("$key.allAccounts.${safe(packageName)}", true),
                "accounts" to accounts,
            )
        }
        return mapOf(
            "accessEnabled" to accessEnabled,
            "masterEnabled" to p.getBoolean("$key.master", false),
            // Only this known family has an implemented sender. Do not imply
            // Garmin, generic BLE or unsupported families can receive alerts.
            "deliverySupported" to (protocolId == "ido-veryfit-family"),
            "apps" to maps,
            "lastObservedAt" to p.getLong(SEEN_AT, 0L),
            "lastEligibleAt" to p.getLong(ELIGIBLE_AT, 0L),
            "lastEligibleApp" to (p.getString(ELIGIBLE_APP, "") ?: ""),
        )
    }

    private fun visibleApps(
        context: Context,
        p: android.content.SharedPreferences,
    ): Map<String, String> {
        val apps = linkedMapOf<String, String>()
        for (known in commonApps) {
            if (isInstalled(context, known.packageName)) {
                apps[known.packageName] =
                    installedLabel(context, known.packageName) ?: known.fallbackLabel
            }
        }
        for (packageName in p.getStringSet(OBSERVED_APPS, emptySet()) ?: emptySet()) {
            if (packageName == context.packageName) continue
            apps.putIfAbsent(
                packageName,
                p.getString("observed.label.${safe(packageName)}", packageName)
                    ?: packageName,
            )
        }
        return apps
    }

    private fun friendlyLabel(packageName: String, installed: String): String =
        when (packageName) {
            "com.google.android.dialer", "com.samsung.android.dialer" -> "Phone calls"
            "com.google.android.apps.messaging", "com.samsung.android.messaging" -> "Text messages"
            else -> installed
        }

    @Suppress("DEPRECATION")
    private fun isInstalled(context: Context, packageName: String): Boolean =
        try {
            context.packageManager.getApplicationInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        } catch (_: Throwable) {
            false
        }

    @Suppress("DEPRECATION")
    private fun installedLabel(context: Context, packageName: String): String? =
        try {
            val info = context.packageManager.getApplicationInfo(packageName, 0)
            context.packageManager.getApplicationLabel(info).toString()
        } catch (_: Throwable) {
            null
        }
}
