package com.rustnrum.healthyme.beta03

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Production activity. Health Connect is provided by the Flutter health plugin.
 * No direct hardware discovery, pairing, GATT channels, or notification bridge.
 */
class MainActivity : FlutterFragmentActivity() {
    private val backupBridge by lazy { SalusBackupBridge(this) }

    @Deprecated("Android Storage Access Framework activity result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (backupBridge.onActivityResult(requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.rustnrum.healthyme/backup").setMethodCallHandler(backupBridge)
    }
}
