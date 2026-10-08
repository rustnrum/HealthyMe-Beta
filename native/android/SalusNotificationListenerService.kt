package com.rustnrum.healthyme.beta03

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.concurrent.Executors

/**
 * One Android listener, two explicitly different routes:
 *   1. Installed direct protocol sender for IDO/VeryFit.
 *   2. Normal Android notification posted by Salus for companion-managed watches.
 *
 * The latter is NOT a Garmin BLE sender: Garmin Connect or another companion
 * must independently be allowed to mirror the Salus app's Android notifications.
 * Posting a notification is never interpreted as watch delivery confirmation.
 */
class SalusNotificationListenerService : NotificationListenerService() {
    private val executor = Executors.newSingleThreadExecutor()

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val item = sbn ?: return
        if (item.packageName == packageName) return // prevent relay loops
        if (item.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (item.notification.flags and Notification.FLAG_ONGOING_EVENT != 0 &&
            item.notification.category != Notification.CATEGORY_CALL) return

        val label = try {
            @Suppress("DEPRECATION")
            val info = packageManager.getApplicationInfo(item.packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Throwable) { item.packageName }

        SalusWatchNotificationStore.recordObservedApp(this, item.packageName, label)
        val account = if (item.packageName == SalusWatchNotificationStore.GMAIL_PACKAGE) {
            extractGmailAccount(item).also {
                SalusWatchNotificationStore.recordGmailAccount(
                    this, it ?: SalusWatchNotificationStore.UNKNOWN_GMAIL_ACCOUNT)
            }
        } else null

        val approved = SalusWatchNotificationStore.targets(this).filter { target ->
            SalusWatchNotificationStore.isAllowed(this, target, item.packageName, account)
        }
        if (approved.isEmpty()) return
        SalusWatchNotificationStore.recordEligibleNotification(this, item.packageName)

        // Only one companion relay per source alert even with multiple watches.
        // This avoids duplicate phone notifications and duplicate watch alerts.
        if (approved.any { it.protocolId != "ido-veryfit-family" }) {
            postCompanionAlert(item, label)
        }
        for (target in approved.filter { it.protocolId == "ido-veryfit-family" }) {
            executor.execute { SalusWatchNotificationSender.send(this, target, item) }
        }
    }

    private fun postCompanionAlert(sbn: StatusBarNotification, label: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return

        val source = sbn.notification
        val extras = source.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()?.trim().orEmpty()
        val isCall = source.category == Notification.CATEGORY_CALL
        if (title.isBlank() && text.isBlank() && !isCall) return
        val channelId = "salus_companion_alerts_v1"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(
                channelId,
                "Watch companion relay",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = "Opt-in Salus alerts for watch companion apps" })
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("$label: ${title.ifEmpty { if (isCall) "Incoming call" else "Notification" }}".take(100))
            .setContentText(text.ifEmpty { if (isCall) "Phone call" else "" }.take(180))
            .setStyle(Notification.BigTextStyle().bigText(text.take(500)))
            .setCategory(if (source.category == Notification.CATEGORY_CALL)
                Notification.CATEGORY_CALL else Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setTimeoutAfter(30_000L)
            .setOnlyAlertOnce(true)
            .build()
        // Stable ID per original notification: updates replace, not accumulate.
        val id = (sbn.packageName + ":" + sbn.id + ":" + (sbn.tag ?: "")).hashCode()
        try {
            manager.notify(id, notification)
        } catch (_: SecurityException) {
            // Permission can be revoked between checking and posting.
        } catch (_: RuntimeException) {
            // Notification service must remain alive for subsequent alerts.
        }
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun extractGmailAccount(item: StatusBarNotification): String? {
        val e = item.notification.extras
        val values = listOfNotNull(
            e.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString(),
            e.getCharSequence(Notification.EXTRA_TITLE)?.toString(),
            e.getCharSequence(Notification.EXTRA_TEXT)?.toString(),
            e.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString(),
        )
        val pattern = Regex("[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", RegexOption.IGNORE_CASE)
        return values.firstNotNullOfOrNull { pattern.find(it)?.value?.lowercase() }
    }
}
