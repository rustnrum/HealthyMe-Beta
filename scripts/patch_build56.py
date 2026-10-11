"""Apply Build 56 Garmin lifecycle and real-notification diagnostics.

Runs after the existing Build 55 patch in scripts/prepare_android.sh.
Strict idempotent source anchors: fail the build on unexpected source instead
of silently producing a partly patched APK. No settings or databases touched.
"""
from pathlib import Path


def replace_one(path, old, new):
    p = Path(path)
    content = p.read_text(encoding='utf-8')
    if new in content:
        return
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected exactly one anchor, got {count}: {old[:100]!r}')
    p.write_text(content.replace(old, new, 1), encoding='utf-8')


sender='native/android/SalusGarminNotificationSender.kt'
listener='native/android/SalusNotificationListenerService.kt'

# The registration response can repeat on the same live GATT session.
# Never replace the active MLR object on a duplicate: that resets its sequence
# and ACK windows and the watch then replies with seq=21 to nextReceive=0.
replace_one(sender,
'''        private var ignoredMlrAckCount = 0
''',
'''        private var ignoredMlrAckCount = 0
        private var notificationRecoveryId: Int? = null
        private var lastAttributeRequestId: Int? = null
        private var notificationSendToken = 0
''')

replace_one(sender,
'''            recentAlerts.clear(); deferredAppAttributes = null; appAttributeTransferActive = false
            notificationTransfer.reset(); ++dataAckToken
            stage("Off", "Notification forwarding disabled")''',
'''            recentAlerts.clear(); deferredAppAttributes = null; appAttributeTransferActive = false
            notificationRecoveryId = null; lastAttributeRequestId = null
            notificationTransfer.reset(); ++dataAckToken
            stage("Off", "Notification forwarding disabled")''')

replace_one(sender,
'            handle = 0; registered = false; subscribed = false; subscriptionSeen = false\n            mlr?.close(); mlr = null; mlrRequested = true',
'            handle = 0; registered = false; subscribed = false; subscriptionSeen = false\n            notificationSendToken++ // Cancel old GATT-session notification deadlines.\n            mlr?.close(); mlr = null; mlrRequested = true')

replace_one(sender,
'''                            handle = bytes[13].toInt() and 255
                            val reliable = if (bytes.size > 14) bytes[14].toInt() and 255 else 0
                            registered = handle > 0
                            if (registered) {''',
'''                            val newHandle = bytes[13].toInt() and 255
                            val reliable = if (bytes.size > 14) bytes[14].toInt() and 255 else 0
                            if (newHandle == 0) {
                                stage("Invalid Garmin registration", "Garmin returned handle zero")
                                return@post
                            }
                            when (SalusGarminRegistrationPolicy.evaluate(
                                registered, handle, mlr != null, newHandle, reliable != 0)) {
                                SalusGarminRegistrationPolicy.Decision.DUPLICATE -> {
                                    // Preserve all MLR send/receive/ACK counters and watch subscription.
                                    SalusWatchTransportStatus.note(app, deviceId,
                                        "Garmin duplicate registration", "Handle=$handle; preserving live MLR counters")
                                    return@post
                                }
                                SalusGarminRegistrationPolicy.Decision.REPLACEMENT -> {
                                    // Remote handle changed: old notification transport is no longer usable.
                                    // Keep the active alert, but never send on stale subscription state.
                                    stage("Garmin service replaced", "Reinitializing GFDI for handle=$newHandle")
                                    current?.let { if (pending.size < MAX_PENDING) pending.addFirst(it) }
                                    current = null; updateSent = false
                                    notificationSendToken++
                                    notificationTransfer.reset(); ++dataAckToken
                                    outgoing.clear(); incoming.reset()
                                    mlr?.close(); mlr = null
                                    subscribed = false; subscriptionSeen = false
                                    informationExchanged = false; configurationExchanged = false
                                    applicationInitialized = false; setupEventsAwaitingAck = 0
                                    deferredAppAttributes = null; appAttributeTransferActive = false
                                    lastAttributeRequestId = null
                                    ignoredMlrAckCount = 0
                                }
                                SalusGarminRegistrationPolicy.Decision.INITIAL -> Unit
                            }
                            handle = newHandle
                            registered = true
                            if (registered) {''')

# Confirm an attr request actually happened before 9s timer. If it did not,
# reconnect ONCE and replay current notification; don't endlessly retry an ID.
replace_one(sender,
'''            updateSent = true
            stage("Sending notification", "Watch subscribed; posting Garmin GFDI notification update")''',
'''            updateSent = true
            lastAttributeRequestId = null
            val sendToken = ++notificationSendToken
            stage("Sending notification", "Watch subscribed; posting Garmin GFDI notification update")''')

replace_one(sender,
'''                if (enabled && current?.id == thisId && updateSent) {
                    stage("No watch attribute request", "Garmin did not request this notification's text")
                    current = null; updateSent = false
                    maybeSend()
                }''',
'''                if (enabled && sendToken == notificationSendToken &&
                    current?.id == thisId && updateSent &&
                    lastAttributeRequestId != thisId && !notificationTransfer.awaitingAck) {
                    if (notificationRecoveryId != thisId) {
                        notificationRecoveryId = thisId
                        // fail() preserves/requeues the active alert and reconnects automatically.
                        fail("Garmin notification session stalled",
                            "No Garmin 5034 request in 9 seconds; reconnecting once to retry")
                    } else {
                        stage("No watch attribute request",
                            "Retry failed; Garmin did not request this notification's text")
                        notificationRecoveryId = null
                        current = null; updateSent = false
                        maybeSend()
                    }
                }''')

replace_one(sender,
'''                            if (alert != null) {
                                SalusWatchTransportStatus.metadata(app, deviceId, "protocol", "Garmin GFDI confirmed; 5034 attribute request received")''',
'''                            if (alert != null) {
                                if (current?.id == requested) lastAttributeRequestId = requested
                                SalusWatchTransportStatus.metadata(app, deviceId, "protocol", "Garmin GFDI confirmed; 5034 attribute request received")''')

replace_one(sender,
'''                            stage("Garmin accepted notification data",
                                "Watch acknowledged all 5035 data chunks; on-screen display still unverified")
                            if (appAttributeTransferActive) {''',
'''                            stage("Garmin accepted notification data",
                                "Watch acknowledged all 5035 data chunks; on-screen display still unverified")
                            // A successful notification content transfer clears its recovery budget.
                            if (!appAttributeTransferActive) notificationRecoveryId = null
                            if (appAttributeTransferActive) {''')

# Logs contain only app package names and coarse routing decisions (never body,
# title or Gmail account identifier). This separates listener filtering from BLE.
replace_one(listener,
'''        if (item.packageName == packageName) return // prevent relay loops
        if (item.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (item.notification.flags and Notification.FLAG_ONGOING_EVENT != 0 &&
            item.notification.category != Notification.CATEGORY_CALL) return''',
'''        if (item.packageName == packageName) return // prevent relay loops
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
        }''')

replace_one(listener,
'''        if (approved.isEmpty()) return
        SalusWatchNotificationStore.recordEligibleNotification(this, item.packageName)

        for (target in approved) {
            executor.execute {''',
'''        if (approved.isEmpty()) {
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
            executor.execute {''')

replace_one('pubspec.yaml','version: 0.21.17+55','version: 0.21.18+56')
for path in ('test/build52_garmin_attribute_payload_contract_test.dart',
             'test/build54_garmin_protocol_contract_test.dart',
             'test/build55_garmin_realwatch_regressions_test.dart'):
    replace_one(path,'0.21.17+55','0.21.18+56')

print('Build 56: duplicate registration preserved, genuine handle replacement reset, '
      'one-shot stalled notification recovery, Gmail routing diagnostics, version updated.')
