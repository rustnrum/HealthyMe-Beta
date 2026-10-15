"""Build 89: remove active hardware/Bluetooth routes, use Health Connect only.

Intentionally preserves data keys, package ID, signing configuration, and the
Home/Training/Nutrition designs. No blanket reset of saved user records.
"""
from pathlib import Path
import re

VERSION='version: 0.21.51+89'
assert VERSION in Path('pubspec.yaml').read_text()

def edit(path, before, after, expected=1):
    p=Path(path)
    s=p.read_text()
    n=s.count(before)
    if n==0 and after in s:return
    if n!=expected:raise RuntimeError(f'{path}: expected {expected} occurrences for {before[:75]!r}, got {n}')
    p.write_text(s.replace(before,after))

def regex(path, pattern, replacement, expected=1, flags=re.S):
    p=Path(path)
    s=p.read_text()
    out,n=re.subn(pattern,replacement,s,flags=flags)
    if n!=expected:raise RuntimeError(f'{path}: regex expected {expected} for {pattern[:100]}, got {n}')
    p.write_text(out)

# Existing source is fully migrated. Do not rerun the old Build 47-88 writers.
# Native packaging is restricted to the encrypted backup bridge and the
# default Flutter activity; watch notification and hardware protocol readers
# cannot be included in a published Android binary.
p='scripts/prepare_android.sh'
s=Path(p).read_text()
s=re.sub(r'(?m)^test -f native/android/(?!MainActivity.kt|SalusBackupBridge.kt|AndroidManifest.xml)[^\n]+\n','',s)
s=s.replace('test -f lib/widgets/garmin_body_battery_panel.dart\n','')
s=s.replace('cp native/android/*.kt "$PKG_DIR"/',
    'cp native/android/MainActivity.kt native/android/SalusBackupBridge.kt "$PKG_DIR"/')
Path(p).write_text(s)

p=Path('native/android/AndroidManifest.xml')
s=Path(p).read_text()
s='\n'.join(line for line in s.split('\n') if not (
    'android.hardware.bluetooth_le' in line or
    'android.permission.BLUETOOTH' in line or
    'android.permission.ACCESS_FINE_LOCATION' in line or
    'android.permission.ACCESS_COARSE_LOCATION' in line))
s,n=re.subn(r'\s*<service\s+android:name="\.SalusNotificationListenerService".*?</service>','',s,flags=re.S)
if n!=1:raise RuntimeError('Notification-listener service anchor absent')
# Remove package-visibility queries that only served notification mirroring.
s=re.sub(r'(?m)^\s*<package android:name="(?!com\.google\.android\.apps\.healthdata")[^"]+" />\n','',s)
Path(p).write_text(s)

# Remove discovery/pairing screens from the app graph. Existing deep-link
# names resolve to Health Connect settings rather than dead device code.
p='lib/app.dart'
for old in [
    "import 'screens/auto_discovery_screen.dart';\n",
    "import 'screens/cpap_screen_v38.dart';\n",
    "import 'screens/device_gallery_screen.dart';\n",
    "import 'screens/watch_device_screen.dart';\n",
    "import 'screens/sources_screen.dart';\n",
]:
    edit(p,old,'')
for a,b in [
    ('const DeviceGalleryScreen()', 'const ConnectionsScreen()'),
    ('const AutoDiscoveryScreen()', 'const ConnectionsScreen()'),
    ('const SourcesScreen()', 'const ConnectionsScreen()'),
    ('const CpapScreenV38()', 'const ConnectionsScreen()'),
    ('const WatchDeviceScreen()', 'const ConnectionsScreen()'),
]:
    edit(p,a,b)

# Links on the More page now point only to a genuine Health Connect screen.
p='lib/screens/more_screen.dart'
regex(p,r"      _link\(context, 'Devices & Sources'.*?const SizedBox\(height: 9\),\n",'',1)
regex(p,r"      _link\(context, 'My saved devices'.*?const SizedBox\(height: 9\),\n",'',1)
regex(p,r"      _link\(context, 'Automatic wearable discovery'.*?const SizedBox\(height: 9\),\n",'',1)
edit(p,"'Source settings', 'Manage connections and choose a source per metric'",
       "'Health Connect sources', 'Select the originating app for each health metric'")
edit(p,'Icons.settings_input_antenna_rounded','Icons.monitor_heart_outlined')

# Disable hardware-specific steps branch while retaining the real timeline.
p='lib/screens/activity_screen.dart'
regex(p,r'      final app = ref.read\(appStateProvider\);.*?      if \(!mounted\) return;\n',
    "      await ref.read(healthSyncProvider.notifier).sync();\n      final result = ref.read(healthSyncProvider).hasError\n          ? 'Health Connect sync failed. Check permissions.'\n          : 'Health Connect steps sync completed.';\n      if (!mounted) return;\n",1)
regex(p,r"    final directStepSource =\s*health\.resolvedSources\['Steps'\]\?\.startsWith\('ble:'\) == true;\n",'',1)
edit(p,'final hasSteps = health.authorized || directStepSource;',
       'final hasSteps = health.authorized;')
edit(p,"'Day' => directStepSource ? const <int>[] : health.hourlySteps,",
       "'Day' => health.hourlySteps,")
edit(p,"_ => directStepSource ? const <int>[] : health.monthlySteps12,",
       "_ => health.monthlySteps12,")
regex(p,r"    final stepIsStale = directStepSource && stepFreshness != null &&\s*DateTime\.now\(\)\.difference\(stepFreshness\) > const Duration\(hours: 1\);\n",'',1)
regex(p,r"\s*if \(stepIsStale\) \.\.\.\[.*?\],\n",'\n',1)
regex(p,r"\s*if \(directStepSource\) \.\.\.\[.*?\],\n",'\n',1)

# Sleep keeps imported sessions and stages; old ring transport timing card is gone.
p='lib/screens/sleep_screen.dart'
edit(p,"import '../services/direct_metric_service.dart';\n",'')
edit(p,"import '../services/sleep_window_service.dart';\n",'')
regex(p,r"        if \(_range == 'Day' && sleepSourceKey\?\.startsWith\('ble:'\) == true\) \.\.\.\[.*?        \],\n        if \(_range == 'Day'\) \.\.\.\[",
    "        if (_range == 'Day') ...[",1)

# Home: no ring firmware index, no fake direct watch Body Battery.
p='lib/screens/premium/salus_home_87.dart'
edit(p,"import '../../services/direct_metric_service.dart';\n",'')
regex(p,r'  List<DirectMetricSample> _ringHrvHistory=const \[\];\n','',1)
edit(p,'_loadRingHrvHistory();_loadTarget();','_loadTarget();')
regex(p,r'  Future<void> _loadRingHrvHistory\(\) async \{.*?  \}\n  Future<void> _loadTarget',
    '  Future<void> _loadTarget',1)
regex(p,r'    ref.listen\(appStateProvider,\(previous,next\)\{.*?    \}\);\n','',1)
edit(p,"selectedSource:app.metricSources['HRV'],directSamples:_ringHrvHistory);",
       "selectedSource:app.metricSources['HRV']);")
regex(p,r"    final hrvValue=hrv\.hasRmssd\?.*?:'—';\n",
    "    final hrvValue=hrv.displayedValue;\n",1)
regex(p,r'    // Body Battery is a device-reported measurement.*?    final bodyBattery=bodyBatteryRecords.isEmpty\?null:bodyBatteryRecords.last;\n','',1)
edit(p,"label:hrv.hasIndex&&!hrv.hasRmssd?'HRV index':'HRV'", "label:'HRV'")
regex(p,r"\s*S87MetricLine\(label:'Body Battery',\s*value:bodyBattery==null\?'—':.*?\),\n",'\n',1)
regex(p,r"\s*if\(bodyBattery!=null\)Padding\(.*?\),\n(?=          \]\)\),)",'\n',1)
regex(p,r"          final hasIndexHistory=.*?          final hrvPanel=",
    "          final hrvChartValues=hrv.rmssdHistory;\n          final hrvPanel=",1)
regex(p,r'          final hasRmssdHistory=hrv\.hasRmssd&&hrv\.rmssdHistory\.length>=2;\n','',1)
edit(p,"Text(hrv.hasIndex&&!hrv.hasRmssd?'Device HRV Index':'HRV (RMSSD)',",
       "Text('HRV (RMSSD)',")
edit(p,'if(hasRmssdHistory||hasIndexHistory)', 'if(hrv.hasRmssd&&hrvChartValues.length>=2)')
edit(p,"unit:hasRmssdHistory?'ms':'index'", "unit:'ms'")
regex(p,r"              Text\(hrv\.hasIndex&&!hrv\.hasRmssd\?.*?                'Source: \$\{hrv\.sourceLabel\}',",
    "              Text(hrv.hasRmssd?'${hrv.rmssdHistory.length} recorded RMSSD values':\n                'Source: ${hrv.sourceLabel}',",1)

# Health module keeps the live recovery and Health Connect vitals.
p='lib/screens/premium/salus_health_77.dart'
edit(p,"import '../../services/direct_metric_service.dart';\n",'')
regex(p,r"  List<DirectMetricSample> _hrvSamples=const \[\];.*?  @override Widget build",
    "  @override void initState(){super.initState();SalusAppearance.load();}\n  @override Widget build",1)
regex(p,r"    ref.listen\(appStateProvider,\(previous,next\)\{.*?    \}\);\n",'',1)
edit(p,"selectedSource:app.metricSources['HRV'],directSamples:_hrvSamples);",
       "selectedSource:app.metricSources['HRV']);")
regex(p,r"            label:hrvView.hasRmssd\?'HRV':hrvView.hasIndex\?'HRV device index':'HRV',\n            value:hrvView.hasRmssd\?'\$\{hrvView.rmssdMs!\.round\(\)\}':\s*hrvView.hasIndex\?'\$\{hrvView.latestIndex!\.value.round\(\)\}':'—',\n            caption:hrvView.hasIndex&&!hrvView.hasRmssd\?'index · not RMSSD':'ms',",
    "            label:'HRV',\n            value:hrvView.hasRmssd?'${hrvView.rmssdMs!.round()}':'—',\n            caption:'ms',",1)
edit(p,"Text(hrvView.hasIndex&&!hrvView.hasRmssd?'HRV device index':'HRV history',",
       "Text('HRV history',")
regex(p,r"              values:hrvView\.hasRmssd\s*\? hrvView\.rmssdHistory.*?unit:hrvView\.hasRmssd\?'ms':'index'\),\n            if\(hrvView\.hasIndex&&!hrvView\.hasRmssd\) Text\(.*?\),",
    "              values:hrvView.rmssdHistory.map((x)=>x.toDouble()).toList(),\n              color:S77.cyan,height:118,unit:'ms'),",1)

# A watch sync widget no longer belongs in Recovery.
p='lib/screens/recovery_detail_screen.dart'
edit(p,"import '../widgets/garmin_body_battery_panel.dart';\n",'')
regex(p,r'          GarminBodyBatteryPanel\(\s*recoveryScore: report.score,\s*recoveryConfidence: report.confidence,\s*\),\n          const SizedBox\(height: 24\),\n','',1)

# Temperature: import from Health Connect and retain older *HC* cache only.
p='lib/services/salus_temperature_service.dart'
edit(p,"    final direct = await const DirectMetricService().loadSamples();\n    return distinct([...stored, ...direct]);",
       "    return distinct(stored.where((s)=>s.sourceId.startsWith('hc:')));")

# SpO2 history: Health Connect only.
p='lib/services/spo2_history_service.dart'
regex(p,r'    final readings = <DirectMetricSample>\[\s*\.\.\.await DirectMetricService\(\)\.loadSamples\(\),\s*\];',
    '    final readings = <DirectMetricSample>[];',1)
edit(p,'Direct-device readings are still shown.',
       'Please check Health Connect permissions and the originating provider.')

p='lib/screens/spo2_history_screen.dart'
edit(p,'Actual direct-device and Health Connect readings only. One source at a time; no invented history.',
       'Health Connect readings only. One originating provider at a time; no invented history.')

p='lib/screens/health/salus_health_intelligence_screen.dart'
edit(p,"import '../../services/direct_metric_service.dart';",
       "import '../../services/direct_metric_service.dart';")
edit(p,'Ring support is firmware-dependent; ', '')
edit(p,'Sync your ring / manage sources','Health Connect sources')
edit(p,'Icons.bluetooth_searching','Icons.monitor_heart_outlined')
edit(p,'Try a ring sync, or import permissioned Health Connect records.',
       'Import permissioned Health Connect records.')

# Old direct transport routes remain in version history, not executable UI.
# Current metric origin selections are scrubbed on hydration without resetting
# nutrition, manual weights, labs, plans, or other app state.
p='lib/state/app_state.dart'
regex(p,r"    final source = saved\.resolvedSources\['HRV'\];.*?    return saved\.copyWith\(clearHrv: true, hrv30: const \[\],\s*resolvedSources: resolved, freshness: freshness\);",
    "    final json = saved.toJson();\n"
    "    final origins = Map<String,String>.from(saved.resolvedSources);\n"
    "    final old = origins.entries.where((e)=>e.value.startsWith('ble:')).map((e)=>e.key).toList();\n"
    "    if (old.isEmpty) return saved;\n"
    "    for (final metric in old) {\n"
    "      origins.remove(metric);\n"
    "      const field = <String,String>{'Steps':'stepsToday','Sleep':'sleepMinutes',\n"
    "        'Heart rate':'latestHeartRate','Resting heart rate':'restingHeartRate',\n"
    "        'HRV':'hrvMs','SpO2':'bloodOxygenPercent',\n"
    "        'Respiratory rate':'respiratoryRate','Active calories':'activeCaloriesToday'};\n"
    "      final key=field[metric];\n"
    "      if(key!=null) json[key]=key=='stepsToday'||key=='sleepMinutes'||key=='activeCaloriesToday'?0:null;\n"
    "      if(metric=='HRV') json['hrv30']=<double>[];\n"
    "    }\n"
    "    json['resolvedSources']=origins;\n"
    "    return HealthSnapshot.fromJson(json);",1)
edit(p,'.map((key, value) => MapEntry(key, value.toString())),',
       ".map((key, value) => MapEntry(key, value.toString()))\n              ..removeWhere((metric, source)=>source.startsWith('ble:')),")

# Legacy source registry/old direct screens are no longer navigable; quarantine
# unused hardware code after the import graph is checked (below).
# Allow idempotent reruns only on a checkout with this release version.

# Update version text of non-hardware regressions. Feature-specific test cases
# are moved out of the Flutter test tree with an explicit retirement manifest.
retired=[]
for test in Path('test').glob('*.dart'):
    s=test.read_text()
    original=s
    for old in ['version: 0.21.50+88','version: 0.21.49+87','version: 0.21.48+86']:
        s=s.replace(old,VERSION)
    if test.name=='build75_dark_premium_contract_test.dart':
        s=s.replace('37|38|39|40|41|42|43|44|45|46|47|48|49|50',
          '37|38|39|40|41|42|43|44|45|46|47|48|49|50|51')
        s=s.replace('75|76|77|78|79|80|81|82|83|84|85|86|87|88',
          '75|76|77|78|79|80|81|82|83|84|85|86|87|88|89')
    if s!=original:test.write_text(s)

# Any unreferenced BLE implementation is kept only in git history; never
# packaged. Determine reachability from main.dart/app.dart, not filenames.
lib=Path('lib')
def dep(src, name):
    if name.startswith('package:healthy_me/'):
        return Path('lib')/name.removeprefix('package:healthy_me/')
    if name.startswith('package:') or name.startswith('dart:'):
        return None
    return (src.parent/name)

def dependencies(f):
    content=f.read_text(encoding='utf-8')
    return [p for p in (dep(f,s) for s in re.findall(r"(?:import|export|part)\s+'([^']+)'",content)) if p is not None]
reachable=set()
def visit(path):
    path=path.resolve()
    if path in reachable or not path.is_file() or lib.resolve() not in path.parents:return
    reachable.add(path)
    for child in dependencies(path):visit(child)
for root in [Path('lib/main.dart'), Path('lib/app.dart')]:visit(root)

# Explicit BLE families must not be reachable. Dormant former hardware modules
# are removed from lib/ to keep flutter analyze from compiling dead drivers.
hardware_names={
 'ble_device_information_service.dart','ble_discovery_service.dart',
 'ble_protocol_profiles.dart','cpap_pairing_service.dart','cpap_therapy_service.dart',
 'device_category_service.dart','direct_device_store.dart','garmin_battery_service.dart',
 'local_device_driver.dart','local_protocol_pack_registry.dart',
 'native_source_discovery_service.dart','notification_access_service.dart',
 'watch_notification_service.dart','auto_discovery_screen.dart','device_gallery_screen.dart',
 'device_information_screen.dart','cpap_screen.dart','cpap_screen_v38.dart',
 'watch_device_screen.dart','garmin_body_battery_panel.dart',
 'device_battery_indicator.dart','source_hub_service.dart',
 'sleep_window_service.dart','salus_home_77.dart',
}
removed=[]
for file in sorted(lib.rglob('*.dart')):
    source=file.read_text()
    if file.name in hardware_names:
        if file.resolve() in reachable:
            raise RuntimeError(f'Hardware implementation still reachable from app: {file}')
        file.unlink(); removed.append(str(file));continue
    # Archived screens that import the now-removed hardware stack must also be
    # retired if not reachable. Do not delete live app screens silently.
    hardware_imports=any(name in source for name in [
        "import '../services/ble_", "import '../../services/ble_",
        "import 'ble_", "import 'direct_device_store.dart'",
        "import 'garmin_battery_service.dart'",
        "import 'source_hub_service.dart'",
        "import '../services/source_hub_service.dart'",
        "import '../services/direct_device_store.dart'",
        "import '../services/garmin_battery_service.dart'",
        "import '../services/watch_notification_service.dart'",
    ])
    # Unused archived readers may still refer to DirectMetricService APIs
    # that were removed with the transport. They must not be analyzed or ship.
    stale_code=('DirectMetricService(' in source or
        'DirectMetricService.' in source or
        'Ring HRV proxy' in source or 'Bluetooth' in source or
        "startsWith('ble:')" in source)
    if hardware_imports or (stale_code and file.resolve() not in reachable):
        if file.resolve() in reachable:
            raise RuntimeError(f'Unremoved hardware dependency in live code: {file}')
        file.unlink();removed.append(str(file))

# Recurse through dead source files whose imports were made obsolete by those
# removals. Fail instead of pruning if an actual app route still needs them.
changed=True
while changed:
    changed=False
    for file in sorted(lib.rglob('*.dart')):
        if any(not child.exists() for child in dependencies(file)):
            if file.resolve() in reachable:
                raise RuntimeError(f'Live screen has a missing Dart import: {file}')
            file.unlink();removed.append(str(file));changed=True

# Historical tests tied to removed Bluetooth classes or test fixture paths
# are obsolete. Preserve a retirement report rather than silently skipping
# them or modifying their assertions to pass.
old_test_pattern=re.compile(
    r'(?i)ble_|ble:|bluetooth|DirectMetricService|DirectDeviceStore|'
    r'Garmin|GATT|CpapPairing|WatchNotification|DirectMetricReadResult|ringHrvProxy|'
    r'Ring HRV proxy|\.hasIndex|\.indexHistory|\.latestIndex|'
    r'HealthSyncNotifier\.refreshSelectedDirect|'
    r'SalusNotificationListenerService|source_discovery|'
    r'garmin_body_battery_panel|SalusBleDeviceInfoReader|'
    r'copyWith\(.*clearHrv')
for file in Path('test').glob('*.dart'):
    if file.name in {'build89_health_connect_only_test.dart','build88_metrics_contract_test.dart'}:continue
    content=file.read_text()
    if old_test_pattern.search(content):
        retired.append(file.name)
        file.unlink()

# Strip native Kotlin hardware implementations from the source repository,
# not merely from the Gradle build. Retain the working encrypted backup bridge.
for file in Path('native/android').glob('*.kt'):
    if file.name not in {'MainActivity.kt','SalusBackupBridge.kt'}:
        file.unlink();removed.append(str(file))
for file in Path('test').glob('*.kt'):
    file.unlink();removed.append(str(file))
for file in Path('docs').glob('*Ring*Decoder*.kt'):
    file.unlink();removed.append(str(file))

# Historical source-rewriters would recreate Bluetooth code if invoked. They
# have not been used since Build 85 and should not stay in active scripts.
for file in Path('scripts').glob('patch_build*.py'):
    file.unlink();removed.append(str(file))
for file in [Path('scripts/build87_apply.py'),Path('scripts/build88_apply.py')]:
    if file.exists():file.unlink();removed.append(str(file))

# The proprietary protocol pack is no longer reachable. Keep general device
# illustrations and user media intact in case unrelated screens need them.
for folder in [Path('assets/protocols')]:
    if folder.is_dir():
        for file in sorted(folder.rglob('*'),reverse=True):
            if file.is_file():file.unlink();removed.append(str(file))
        for directory in sorted(folder.rglob('*'),reverse=True):
            if directory.is_dir():directory.rmdir()
        folder.rmdir()
pub=Path('pubspec.yaml')
source=pub.read_text()
source=source.replace('    - assets/protocols/\n','')
pub.write_text(source)

# Additional obsolete tests may hardcode source files that were retired.
for file in Path('test').glob('*.dart'):
    if file.name in {'build89_health_connect_only_test.dart','build88_metrics_contract_test.dart'}:continue
    text=file.read_text()
    if any(name in text for name in removed) or any(not child.exists() for child in dependencies(file)):
        retired.append(file.name);file.unlink()

Path('docs').mkdir(exist_ok=True)
Path('docs/build89_removed_hardware.txt').write_text(
    'Salus Build 89 hardware cleanup\n\nDeleted legacy app files:\n'+'\n'.join(removed)+
    '\n\nRetired feature-specific tests:\n'+'\n'.join(sorted(set(retired)))+'\n')

# Every still-reachable Dart source must pass the privacy boundary.
for name in reachable:
    if not name.is_file():raise RuntimeError(f'Entry graph removed: {name}')
    text=name.read_text()
    if re.search(r'(?i)android\.bluetooth|Permission\.bluetooth|scanBle|readBleDeviceInfo|'
                 r'readProtocolMetrics|BleDiscoveryService|DirectDeviceStore|'
                 r'WatchNotificationService|ringHrvProxy|'
                 r'\bble_[A-Za-z]|Icons\.bluetooth',text):
        raise RuntimeError(f'BLE implementation remains reachable: {name}')

manifest=Path('native/android/AndroidManifest.xml').read_text()
activity=Path('native/android/MainActivity.kt').read_text()
assert 'BLUETOOTH' not in manifest and 'bluetooth_le' not in manifest
assert 'SalusNotificationListenerService' not in manifest
assert 'android.bluetooth' not in activity
assert 'com.rustnrum.healthyme.beta03' in Path('scripts/prepare_android.sh').read_text()
print(f'Salus Build 89: Health Connect only; removed {len(removed)} unused hardware files, retired {len(retired)} obsolete tests')
