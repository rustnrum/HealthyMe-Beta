"""Build 68: separate, source-authentic Garmin Body Battery Recovery panel.

Retains existing score calculation, app data, BLE transport, ring reader,
Garmin notification sender, pairing, and signing key. Idempotent migrations.
"""
from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    if new in s:
        return
    count = s.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one patch anchor, got {count}: {old[:110]}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')


replace('pubspec.yaml', 'version: 0.21.29+67', 'version: 0.21.30+68')

replace('lib/screens/recovery_detail_screen.dart',
        "import '../widgets/command_card.dart';",
        "import '../widgets/command_card.dart';\nimport '../widgets/garmin_body_battery_panel.dart';")
replace('lib/screens/recovery_detail_screen.dart',
'''          const SizedBox(height: 24),
          const HmSectionHeader(title: 'Recovery contributors'),''',
'''          const SizedBox(height: 16),
          GarminBodyBatteryPanel(
            recoveryScore: report.score,
            recoveryConfidence: report.confidence,
          ),
          const SizedBox(height: 24),
          const HmSectionHeader(title: 'Recovery contributors'),''')

# Expose only read-only registration/telemetry evidence from the Garmin parser.
replace('native/android/SalusProtocolReader.kt',
'''        private var garminPendingService: Int? = null
        private var garminRegistrationStarted = false''',
'''        private var garminPendingService: Int? = null
        private var garminRegistrationStarted = false
        // 0 = not requested; 1 = requested; 2 = registered/no reading;
        // 3 = rejected; 4 = no reply/write failed; 5 = value received.
        private var garminBodyBatteryStatus = 0''')

replace('native/android/SalusProtocolReader.kt',
'''                        } else if (mode == "ring") {
                            mapOf(''',
'''                        } else if (mode == "garmin") {
                            mapOf(
                                "garminBodyBatteryStatus" to garminBodyBatteryStatus,
                            )
                        } else if (mode == "ring") {
                            mapOf(''')

replace('native/android/SalusProtocolReader.kt',
'''            val service = GARMIN_SERVICES[garminRegisterIndex]
            garminPendingService = service
            if (!garminWrite(registerPacket(service))) {''',
'''            val service = GARMIN_SERVICES[garminRegisterIndex]
            garminPendingService = service
            if (service == GARMIN_REALTIME_BODY_BATTERY) {
                garminBodyBatteryStatus = 1
            }
            if (!garminWrite(registerPacket(service))) {
                if (service == GARMIN_REALTIME_BODY_BATTERY) {
                    garminBodyBatteryStatus = 4
                }''')

replace('native/android/SalusProtocolReader.kt',
'''                    if (garminPendingService == service) {
                        garminPendingService = null
                        garminRegisterIndex += 1
                        registerNextGarmin()
                    }
                },
                900L,''',
'''                    if (garminPendingService == service) {
                        if (service == GARMIN_REALTIME_BODY_BATTERY &&
                            garminBodyBatteryStatus == 1) {
                            garminBodyBatteryStatus = 4
                        }
                        garminPendingService = null
                        garminRegisterIndex += 1
                        registerNextGarmin()
                    }
                },
                900L,''')

replace('native/android/SalusProtocolReader.kt',
'''                val handle = value[13].toInt() and 0xff

                if (status == 0 && handle in 1..127) {''',
'''                val handle = value[13].toInt() and 0xff
                if (service == GARMIN_REALTIME_BODY_BATTERY &&
                    garminBodyBatteryStatus != 5) {
                    garminBodyBatteryStatus = if (status == 0 && handle in 1..127) 2 else 3
                }

                if (status == 0 && handle in 1..127) {''')

replace('native/android/SalusProtocolReader.kt',
'''                        if (bodyBattery in 0..100) {
                            metrics["Body battery"] = bodyBattery.toDouble()''',
'''                        if (bodyBattery in 1..100) {
                            metrics["Body battery"] = bodyBattery.toDouble()
                            garminBodyBatteryStatus = 5''')

# Persist just the latest probe status for an individual Garmin device.
# Re-use the existing encrypted/OS-private preferences approach; no cloud sync.
replace('lib/services/direct_metric_service.dart',
'''    return DirectMetricReadResult(
      metrics: metrics, message: message, reader: reader,
      observations: observations, diagnostics: diagnostics, history: history,
    );''',
'''    if (resolvedProtocolId == 'garmin-family') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'salus_garmin_body_battery_status_${device.id}',
        diagnostics['garminBodyBatteryStatus'] ?? 0,
      );
      await prefs.setString(
        'salus_garmin_body_battery_attempt_${device.id}',
        DateTime.now().toIso8601String(),
      );
    }
    return DirectMetricReadResult(
      metrics: metrics, message: message, reader: reader,
      observations: observations, diagnostics: diagnostics, history: history,
    );''')
