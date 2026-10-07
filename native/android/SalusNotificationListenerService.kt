package com.rustnrum.healthyme.beta03

import android.service.notification.NotificationListenerService

class SalusNotificationListenerService : NotificationListenerService() {
    @Volatile
    private var connected = false

    override fun onListenerConnected() {
        super.onListenerConnected()
        connected = true
    }

    override fun onListenerDisconnected() {
        connected = false
        super.onListenerDisconnected()
    }
}
