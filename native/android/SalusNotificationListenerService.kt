package com.rustnrum.healthyme.beta03

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.concurrent.Executors

class SalusNotificationListenerService : NotificationListenerService() {
    private val senderExecutor = Executors.newSingleThreadExecutor()

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val item = sbn ?: return
        if (item.packageName == packageName) return
        if (item.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val label = try {
            @Suppress("DEPRECATION")
            val info = packageManager.getApplicationInfo(item.packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Throwable) {
            item.packageName
        }
        SalusWatchNotificationStore.recordObservedApp(this, item.packageName, label)

        val gmailAccount =
            if (item.packageName == SalusWatchNotificationStore.GMAIL_PACKAGE) {
                extractGmailAccount(item).also {
                    SalusWatchNotificationStore.recordGmailAccount(
                        this,
                        it ?: SalusWatchNotificationStore.UNKNOWN_GMAIL_ACCOUNT,
                    )
                }
            } else null

        for (target in SalusWatchNotificationStore.targets(this)) {
            if (!SalusWatchNotificationStore.isAllowed(
                    this,
                    target,
                    item.packageName,
                    gmailAccount,
                )) continue
            if (target.protocolId != "ido-veryfit-family") continue
            // 'Eligible' means this alert passed listener and app filters;
            // it does NOT claim that the watch received the BLE packets.
            SalusWatchNotificationStore.recordEligibleNotification(
                this, item.packageName,
            )
            senderExecutor.execute {
                SalusWatchNotificationSender.send(this, target, item)
            }
        }
    }

    override fun onDestroy() {
        senderExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun extractGmailAccount(sbn: StatusBarNotification): String? {
        val extras = sbn.notification.extras
        val candidates = listOfNotNull(
            extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString(),
            extras.getCharSequence(Notification.EXTRA_TITLE)?.toString(),
            extras.getCharSequence(Notification.EXTRA_TEXT)?.toString(),
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString(),
        )
        val pattern = Regex(
            "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}",
            RegexOption.IGNORE_CASE,
        )
        for (value in candidates) {
            val match = pattern.find(value)?.value
            if (!match.isNullOrBlank()) return match.lowercase()
        }
        return null
    }
}
