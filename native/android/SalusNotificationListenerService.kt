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

    override fun onCreate() {
        super.onCreate()
        // Restore independently enabled Garmin sessions when Android binds the listener.
        SalusWatchNotificationStore.targets(this)
            .filter { it.protocolId == "garmin-family" }
            .forEach { SalusGarminNotificationSender.watch(this, it.deviceId) }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val item = sbn ?: return
        if (item.packageName == packageName) return // prevent relay loops
        val isGmail = item.packageName == SalusWatchNotificationStore.GMAIL_PACKAGE
        val garminTargets = if (isGmail) SalusWatchNotificationStore.targets(this)
            .filter { it.protocolId == "garmin-family" } else emptyList()
        if (item.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) {
            if (isGmail) garminTargets.forEach {
                SalusWatchTransportStatus.note(this, it.deviceId,
                    "Gmail listener", "Grouped summary ignored; waiting for individual email alert")
            }
            return
        }
        if (item.notification.flags and Notification.FLAG_ONGOING_EVENT != 0 &&
            item.notification.category != Notification.CATEGORY_CALL) {
            if (isGmail) garminTargets.forEach {
                SalusWatchTransportStatus.note(this, it.deviceId,
                    "Gmail listener", "Persistent Gmail notification ignored")
            }
            return
        }
        if (isGmail) garminTargets.forEach {
            SalusWatchTransportStatus.note(this, it.deviceId,
                "Gmail listener", "Android Gmail alert received; checking selected apps/accounts")
        }

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
            (target.protocolId == "ido-veryfit-family" || target.protocolId == "garmin-family") &&
                SalusWatchNotificationStore.isAllowed(
                    this, target, item.packageName, account)
        }
        if (approved.isEmpty()) {
            if (isGmail) garminTargets.forEach {
                SalusWatchTransportStatus.note(this, it.deviceId,
                    "Gmail filtered", "Gmail app or account is not approved for this watch")
            }
            return
        }
        SalusWatchNotificationStore.recordEligibleNotification(this, item.packageName)

        for (target in approved) {
            if (target.protocolId == "garmin-family") {
                SalusWatchTransportStatus.note(this, target.deviceId,
                    "Android notification eligible", "App=${item.packageName}; forwarding to Garmin")
            }
            executor.execute {
                when (target.protocolId) {
                    "ido-veryfit-family" -> SalusWatchNotificationSender.send(this, target, item)
                    "garmin-family" -> SalusGarminNotificationSender.send(this, target, item)
                }
            }
        }
    }

    override fun onDestroy() {
        executor.shutdownNow()
        SalusGarminNotificationSender.stopAll()
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
