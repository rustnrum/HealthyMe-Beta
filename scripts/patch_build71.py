"""Build 71 targeted, repeatable patch on top of validated Build 70.
Do NOT overwrite Salus histories, package ID, signers, account state or old features.
"""
from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    src = p.read_text(encoding='utf-8')
    if new in src:
        return
    if src.count(old) != 1:
        raise RuntimeError(f'{path}: expected one anchor but found {src.count(old)}: {old[:90]}')
    p.write_text(src.replace(old, new, 1), encoding='utf-8')


replace('pubspec.yaml', 'version: 0.21.32+70', 'version: 0.21.33+71')
replace('native/android/AndroidManifest.xml',
        '    <uses-permission android:name="android.permission.health.READ_WEIGHT" />',
        '    <uses-permission android:name="android.permission.health.READ_BODY_TEMPERATURE" />\n'
        '    <uses-permission android:name="android.permission.health.READ_SKIN_TEMPERATURE" />\n'
        '    <uses-permission android:name="android.permission.health.READ_WEIGHT" />')
replace('native/android/MainActivity.kt',
        '    private val mainHandler = Handler(Looper.getMainLooper())',
        '    private val backupBridge by lazy { SalusBackupBridge(this) }\n'
        '    private val mainHandler = Handler(Looper.getMainLooper())')
replace('native/android/MainActivity.kt',
        '        super.configureFlutterEngine(flutterEngine)\n',
        '''        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.rustnrum.healthyme/backup").setMethodCallHandler(backupBridge)
''')
# A method at class level immediately before configureFlutterEngine, not inside it.
replace('native/android/MainActivity.kt',
        '    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {',
        '''    @Deprecated("Android's SAF activity result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (backupBridge.onActivityResult(requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {''')
replace('native/android/SalusProtocolReader.kt',
        '        private var ringSpo2Requested = false',
        '        private var ringSpo2Requested = false\n'
        '        private var ringTempRequested = false')
replace('native/android/SalusProtocolReader.kt',
        '''        private fun startRingRequests() {''',
        '''        private fun requestRingTemperature() {
            if (completed.get() || ringTempRequested) return
            val activeGatt = gatt ?: return
            val characteristic = ringBigWrite ?: return
            ringTempRequested = true
            ringBigBuffer.reset()
            // COLMI history 0x25, read only. No sensor settings or firmware writes.
            writeCharacteristic(activeGatt, characteristic,
                byteArrayOf(0xbc.toByte(), 0x25, 0x01, 0x00, 0x3e, 0x81.toByte(), 0x02))
        }

        private fun startRingRequests() {''')
replace('native/android/SalusProtocolReader.kt',
        '''                12800L,
            )
        }

        private fun parseRingPacket''',
        '''                12800L,
            )
            // Fallback when a ring firmware never replies to SpO2 big-data.
            mainHandler.postDelayed({ requestRingTemperature() }, 16300L)
        }

        private fun parseRingPacket''')
replace('native/android/SalusProtocolReader.kt',
        '''            } else if (dataId == 0x2a) {
                parseRingSpo2(payload)
            }
        }''',
        '''            } else if (dataId == 0x2a) {
                parseRingSpo2(payload)
                mainHandler.postDelayed({ requestRingTemperature() }, 400L)
            } else if (dataId == 0x25) {
                val temperatures = SalusRingTemperatureDecoder.decode(payload)
                for (sample in temperatures) {
                    addHistoryMetric("Skin temperature", sample.celsius, sample.timestampMs)
                }
                if (temperatures.isEmpty) notes.add("COLMI 0x25: no verified temperature samples")
                else notes.add("COLMI 0x25: ${temperatures.size} timestamped skin-temperature samples")
            }
        }''')
replace('lib/services/direct_metric_service.dart',
        '''    'HRV' => ' ms', 'SpO2' => '%',''',
        '''    'HRV' => ' ms', 'SpO2' => '%', 'Skin temperature' => ' °C',''')
replace('lib/services/direct_metric_service.dart',
        '''      'Ring HRV proxy',
''',
        '''      'Ring HRV proxy', 'Skin temperature',
''')
replace('lib/services/direct_metric_service.dart',
        '''      duration: duration,
      cpapPasskey: cpapPasskey,''',
        '''      duration: (resolvedProtocolId?.contains('colmi') == true ||
              resolvedProtocolId?.contains('ring') == true ||
              device.name.toLowerCase().contains('r02') ||
              device.name.toLowerCase().contains('colmi')) &&
            duration < const Duration(seconds: 23)
          ? const Duration(seconds: 23) : duration,
      cpapPasskey: cpapPasskey,''')
replace('lib/services/direct_metric_service.dart',
        '''    'HRV' => 'ms', 'SpO2' => '%',''',
        '''    'HRV' => 'ms', 'SpO2' => '%', 'Skin temperature' => '°C',''')
replace('lib/services/direct_metric_service.dart',
        'final cutoff = DateTime.now().subtract(const Duration(days: 35));',
        'final cutoff = DateTime.now().subtract(const Duration(days: 365));')
replace('lib/services/direct_metric_service.dart',
        '''    if (next.length > 3200) {
      next.removeRange(0, next.length - 3200);
    }''',
        '''    if (next.length > 24000) {
      next.removeRange(0, next.length - 24000);
    }''')
replace('lib/app.dart',
        '''import 'screens/health/health_shell.dart';''',
        '''import 'screens/health/health_shell.dart';
import 'screens/health/salus_health_intelligence_screen.dart';
import 'screens/health/salus_backup_screen.dart';''')
replace('lib/app.dart',
        "        '/health': (_) => const HealthShell(),",
        "        '/health': (_) => const HealthShell(),\n"
        "        '/health-intelligence': (_) => const SalusHealthIntelligenceScreen(),\n"
        "        '/backup': (_) => const SalusBackupScreen(),")
replace('lib/screens/health/health_home_screen.dart',
        '''      const SizedBox(height: 11),
      SalusPaper(onTap: () => Navigator.of(context).pushNamed('/metric-heart-rate'),''',
        '''      const SizedBox(height: 11),
      SalusPaper(onTap: () => Navigator.of(context).pushNamed('/health-intelligence'),
        child: const Row(children: [
          Icon(Icons.thermostat_outlined, color: AppTheme.cyan, size: 28),
          SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Health Intelligence', style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Skin temperature and source-verified trends',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ])),
          Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ])),
      const SizedBox(height: 11),
      SalusPaper(onTap: () => Navigator.of(context).pushNamed('/backup'),
        child: const Row(children: [
          Icon(Icons.backup_outlined, color: AppTheme.mint, size: 28),
          SizedBox(width: 11),
          Expanded(child: Text('Backup & Restore', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800))),
          Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ])),
      const SizedBox(height: 11),
      SalusPaper(onTap: () => Navigator.of(context).pushNamed('/metric-heart-rate'),''')
replace('lib/screens/health/health_vitals_screen.dart',
        '''      const SizedBox(height: 13),
      const Text('Recorded wellness signals are not a diagnosis.',''',
        '''      const SizedBox(height: 13),
      ListTile(leading: const Icon(Icons.thermostat_outlined, color: AppTheme.cyan),
        title: const Text('Temperature and Health Intelligence'),
        subtitle: const Text('COLMI ring and Health Connect readings'),
        onTap: () => Navigator.of(context).pushNamed('/health-intelligence')),
      const SizedBox(height: 13),
      const Text('Recorded wellness signals are not a diagnosis.',''')

# Preserve existing device and food histories: no keys are removed/renamed.
assert 'version: 0.21.33+71' in Path('pubspec.yaml').read_text()
assert 'com.rustnrum.healthyme.beta03' in Path('native/android/MainActivity.kt').read_text()
print('Build 71: temperature, Health Intelligence, portable backup patched')
