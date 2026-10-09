from pathlib import Path
p=Path('native/android/MainActivity.kt')
s=p.read_text()
old='''                    result.success(
                        SalusWatchNotificationStore.state(
                            this,
                            deviceId,
                            deviceName,
                            protocolId,
                            isNotificationServiceEnabled(),
                        )
                    )'''
new='''                    result.success(
                        SalusWatchNotificationStore.state(
                            this,
                            deviceId,
                            deviceName,
                            protocolId,
                            isNotificationServiceEnabled(),
                        ) + SalusWatchTransportStatus.state(this, deviceId)
                    )'''
if "SalusWatchTransportStatus.state(this, deviceId)" not in s:
    assert s.count(old)==1, f'Expected 1 notification state hook, got {s.count(old)}'
    s=s.replace(old,new)
old='''                        SalusWatchNotificationStore.setMaster(
                            this,
                            deviceId,
                            deviceName,
                            protocolId,
                            enabled,
                        )'''
new=old+'''
                        if (protocolId == "garmin-family") {
                            if (enabled) SalusGarminNotificationSender.watch(this, deviceId)
                            else SalusGarminNotificationSender.unwatch(deviceId)
                        }'''
if "SalusGarminNotificationSender.watch(this, deviceId)" not in s:
    assert s.count(old)==1, f'Expected 1 master hook, got {s.count(old)}'
    s=s.replace(old,new)
needle='''                "notificationAccessStatus" -> {'''
addition='''                "sendWatchTestNotification" -> {
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    val target = SalusWatchNotificationStore.targets(this)
                        .firstOrNull { it.deviceId == deviceId && it.protocolId == "garmin-family" }
                    if (target != null && isNotificationServiceEnabled()) {
                        SalusGarminNotificationSender.test(this, deviceId)
                        result.success(true)
                    } else result.success(false)
                }
'''
if '"sendWatchTestNotification" -> {' not in s:
    assert s.count(needle)==1, 'Could not find channel insert point'
    s=s.replace(needle,addition+needle)
# An explicit ON action is user approval for Android bonding. Passive listener
# startup must NEVER display a pairing prompt behind the user's back.
s=s.replace('SalusGarminNotificationSender.watch(this, deviceId)',
            'SalusGarminNotificationSender.watch(this, deviceId, true)')
p.write_text(s)
print('Patches installed: watch state, on/off connection, direct test action')
