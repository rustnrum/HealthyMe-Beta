package com.rustnrum.healthyme.beta03

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.concurrent.Executors

/**
 * Opt-in local Android notification listener. Direct transport is dispatched
 * only for locally installed protocols. No vendor companion-app relay.
 * Capture and eligibility are not watch-delivery acknowledgments.
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
            target.protocolId == "ido-veryfit-family" &&
                SalusWatchNotificationStore.isAllowed(
                    this, target, item.packageName, account)
        }
        if (approved.isEmpty()) return
        SalusWatchNotificationStore.recordEligibleNotification(this, item.packageName)

        for (target in approved) {
            executor.execute { SalusWatchNotificationSender.send(this, target, item) }
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
