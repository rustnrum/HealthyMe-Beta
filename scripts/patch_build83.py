#!/usr/bin/env python3
"""Build83: provider-neutral HRV resolution, COLMI command-57 layout correction.

Persisted keys, applicationId, signing, and user history are unchanged.
Apply only to a committed Build82 source tree. All anchors must match exactly.
"""
from pathlib import Path


def replace(file, old, new, count=1):
    path = Path(file)
    text = path.read_text()
    found = text.count(old)
    if found != count:
        raise RuntimeError(f'Build83 anchor mismatch in {file}: expected {count}, got {found}; {old[:90]!r}')
    path.write_text(text.replace(old, new))


pub = Path('pubspec.yaml').read_text()
if 'version: 0.21.45+83' in pub:
    print('Build83 already applied')
    raise SystemExit(0)
if 'version: 0.21.44+82' not in pub:
    raise RuntimeError('Build83 requires Build82 0.21.44+82 checked-in source')

# Source detection: ring exposes command-57 firmware INDEX, not calibrated RMSSD.
# Preserve historical chosen ring as the manual source; future source pickers
# will show it as an index-only provider until RMSSD is actually available.
replace('lib/services/ble_protocol_profiles.dart',
    "        'Sleep',\n        'HRV',\n        'Raw motion',",
    "        'Sleep',\n        'Ring HRV proxy',\n        'Raw motion',")

# Home: one source-aware resolver for qualified RMSSD and index-only readings.
replace('lib/screens/premium/salus_home_77.dart',
    "import '../../services/direct_metric_service.dart';",
    "import '../../services/direct_metric_service.dart';\nimport '../../services/hrv_source_service.dart';")
replace('lib/screens/premium/salus_home_77.dart',
    "    final ringSource=app.metricSources['HRV'];\n"
    "    final selectedRingHrv=ringSource != null && ringSource.startsWith('ble:')\n"
    "        ? _ringHrvHistory.where((s) => s.sourceId == ringSource).toList()\n"
    "        : <DirectMetricSample>[];",
    "    final hrvView=HrvSourceService.resolve(health:h,\n"
    "        selectedSource:app.metricSources['HRV'], directSamples:_ringHrvHistory);")
replace('lib/screens/premium/salus_home_77.dart',
    "              const SizedBox(height:7),_signal(Icons.monitor_heart,S77.blue,'HRV',\n"
    "                h.hrvMs==null?'—':'${h.hrvMs!.round()} ms'),",
    "              const SizedBox(height:7),_signal(Icons.monitor_heart,S77.blue,\n"
    "                hrvView.hasRmssd?'HRV':hrvView.hasIndex?'HRV index':'HRV',\n"
    "                hrvView.hasRmssd?'${hrvView.rmssdMs!.round()} ms':\n"
    "                hrvView.hasIndex?'${hrvView.latestIndex!.value.round()}':'—'),")
replace('lib/screens/premium/salus_home_77.dart',
    "          const SizedBox(width:9),Expanded(child:h.hrv30.length < 2 && selectedRingHrv.isNotEmpty\n"
    "              ? _ringIndexTrend(context,selectedRingHrv)\n"
    "              : _trend(context,'HRV',h.hrv30.map((v)=>v.toDouble()).toList(),S77.blue,'ms','/metric-hrv'))",
    "          const SizedBox(width:9),Expanded(child:hrvView.rmssdHistory.length < 2 && hrvView.hasIndex\n"
    "              ? _ringIndexTrend(context,hrvView.indexHistory)\n"
    "              : _trend(context,'HRV',hrvView.rmssdHistory.map((v)=>v.toDouble()).toList(),S77.blue,'ms','/metric-hrv'))")
replace('lib/screens/premium/salus_home_77.dart',
    'if (previous?.health.lastSync != next.health.lastSync) _loadRingHrvHistory();',
    'if (previous?.health != next.health) _loadRingHrvHistory();')
replace('lib/screens/premium/salus_home_77.dart',
    "        Text('Ring HRV index',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:12)),",
    "        Text('Device HRV index',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:12)),")
replace('lib/screens/premium/salus_home_77.dart',
    "        Text('${values.length} ring records • not RMSSD',",
    "        Text('${values.length} device records • not RMSSD',")
replace('lib/screens/premium/salus_home_77.dart',
    "      if (mounted) setState(() => _ringHrvHistory = samples.where((s) =>\n"
    "          s.metric == 'Ring HRV proxy' && s.value >= 1 && s.value <= 254).toList());",
    "      if (mounted) setState(() => _ringHrvHistory = samples);")

# Health overview was previously hardcoded to health.hrvMs and hrv30 and had
# no access to saved direct samples. Same resolver now supplies both modules.
replace('lib/screens/premium/salus_health_77.dart',
    "import '../../services/recovery_service.dart';",
    "import '../../services/recovery_service.dart';\n"
    "import '../../services/direct_metric_service.dart';\n"
    "import '../../services/hrv_source_service.dart';")
replace('lib/screens/premium/salus_health_77.dart',
    "class _SalusHealth77State extends ConsumerState<SalusHealth77>{\n"
    "  @override void initState(){super.initState();SalusAppearance.load();}",
    "class _SalusHealth77State extends ConsumerState<SalusHealth77>{\n"
    "  List<DirectMetricSample> _hrvSamples=const [];\n"
    "  Future<void> _loadHrvSamples() async {\n"
    "    try {\n"
    "      final samples=await const DirectMetricService().loadSamples();\n"
    "      if(mounted) setState(()=>_hrvSamples=samples);\n"
    "    } catch (_) { /* A missing history must not block Health. */ }\n"
    "  }\n"
    "  @override void initState(){super.initState();SalusAppearance.load();_loadHrvSamples();}")
replace('lib/screens/premium/salus_health_77.dart',
    "    final health=app.health,rec=RecoveryService.build(app,completedWorkouts:workouts.history);",
    "    final health=app.health,rec=RecoveryService.build(app,completedWorkouts:workouts.history);\n"
    "    ref.listen(appStateProvider,(previous,next){\n"
    "      if(previous?.health!=next.health) _loadHrvSamples();\n"
    "    });\n"
    "    final hrvView=HrvSourceService.resolve(health:health,\n"
    "        selectedSource:app.metricSources['HRV'],directSamples:_hrvSamples);")
replace('lib/screens/premium/salus_health_77.dart',
    "          const SizedBox(width:9),Expanded(child:S77Metric(label:'HRV',value:health.hrvMs==null?'—':'${health.hrvMs!.round()}',\n"
    "            caption:'ms',icon:Icons.monitor_heart,color:S77.cyan,height:91,onTap:()=>Navigator.pushNamed(context,'/metric-hrv'))),",
    "          const SizedBox(width:9),Expanded(child:S77Metric(\n"
    "            label:hrvView.hasRmssd?'HRV':hrvView.hasIndex?'HRV device index':'HRV',\n"
    "            value:hrvView.hasRmssd?'${hrvView.rmssdMs!.round()}':\n"
    "                hrvView.hasIndex?'${hrvView.latestIndex!.value.round()}':'—',\n"
    "            caption:hrvView.hasIndex&&!hrvView.hasRmssd?'index · not RMSSD':'ms',\n"
    "            icon:Icons.monitor_heart,color:S77.cyan,height:91,\n"
    "            onTap:()=>Navigator.pushNamed(context,'/metric-hrv'))),")
replace('lib/screens/premium/salus_health_77.dart',
    "            Text('HRV history',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:12)),\n"
    "            const SizedBox(height:8),PremiumLineChart(values:health.hrv30.map((x)=>x.toDouble()).toList(),color:S77.cyan,height:118,unit:'ms'),",
    "            Text(hrvView.hasIndex&&!hrvView.hasRmssd?'HRV device index':'HRV history',\n"
    "                style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:12)),\n"
    "            const SizedBox(height:8),PremiumLineChart(\n"
    "              values:hrvView.hasRmssd\n"
    "                ? hrvView.rmssdHistory.map((x)=>x.toDouble()).toList()\n"
    "                : hrvView.indexHistory.map((x)=>x.value).toList(),\n"
    "              color:S77.cyan,height:118,unit:hrvView.hasRmssd?'ms':'index'),\n"
    "            if(hrvView.hasIndex&&!hrvView.hasRmssd) Text(\n"
    "              'Firmware index • excluded from Recovery',\n"
    "              style:TextStyle(color:S77.sub,fontSize:9)),")

# Details: get source-matched, recorded index through the same resolver.
replace('lib/screens/metric_detail_screen.dart',
    "import '../services/direct_metric_service.dart';",
    "import '../services/direct_metric_service.dart';\nimport '../services/hrv_source_service.dart';")
replace('lib/screens/metric_detail_screen.dart',
    "          final ringSelected = configured != null && configured.startsWith('ble:');\n"
    "          final selectedRingHistory = ringSelected\n"
    "              ? ringHistory.where((s) => SourceNameService.sameProvider(s.sourceId, configured)).toList()\n"
    "              : ringHistory;",
    "          final hrvView = HrvSourceService.resolve(\n"
    "            health: app.health, selectedSource: configured,\n"
    "            directSamples: ringHistory);\n"
    "          final selectedRingHistory = hrvView.indexHistory;")

# Explicit HRV refresh reads the selected Bluetooth provider rather than
# polling every device; expose whether it returned any source-classified data.
replace('lib/state/health_sync_provider.dart',
    '  BleDeviceCandidate _candidate(SavedDirectDevice device) =>',
    "  Future<String> refreshSelectedHrv() async {\n"
    "    if (state.isLoading) return 'A health sync is already running. Try again shortly.';\n"
    "    final app = ref.read(appStateProvider);\n"
    "    final source = app.metricSources['HRV'];\n"
    "    if (source == null || !source.startsWith('ble:')) {\n"
    "      return 'The selected HRV provider is not a direct Bluetooth device.';\n"
    "    }\n"
    "    state = const AsyncLoading();\n"
    "    try {\n"
    "      final saved = await _savedDevices.load();\n"
    "      SavedDirectDevice? selected;\n"
    "      for (final device in saved) {\n"
    "        if ('ble:${device.id}' == source) { selected = device; break; }\n"
    "      }\n"
    "      if (selected == null) {\n"
    "        state = const AsyncData(null);\n"
    "        return 'The selected HRV device is not saved in Connections.';\n"
    "      }\n"
    "      if (!await Permission.bluetoothConnect.isGranted ||\n"
    "          !await Permission.bluetoothScan.isGranted) {\n"
    "        state = const AsyncData(null);\n"
    "        return 'Bluetooth permissions are missing for Salus.';\n"
    "      }\n"
    "      final reading = await _directService.readAndStore(\n"
    "        _candidate(selected), protocolId: selected.protocolId,\n"
    "        duration: const Duration(seconds: 30),\n"
    "      );\n"
    "      final stored = await _directService.loadSamples();\n"
    "      final latest = ref.read(appStateProvider);\n"
    "      final merged = _directService.mergeIntoSnapshot(latest.health,\n"
    "        metricSources: latest.metricSources, samples: stored,\n"
    "        registeredDevices: saved);\n"
    "      ref.read(appStateProvider.notifier).setHealthSnapshot(merged);\n"
    "      final qualified = stored.where((s) =>\n"
    "          s.sourceId == source && s.metric == 'HRV').length;\n"
    "      final indexed = stored.where((s) =>\n"
    "          s.sourceId == source && s.metric == 'Ring HRV proxy').length;\n"
    "      state = const AsyncData(null);\n"
    "      return '${selected.name}: $qualified RMSSD records, $indexed firmware-index records saved. '\n"
    "          'Reader: ${reading.reader}. ${reading.message} '\n"
    "          'Diagnostics: ${reading.diagnostics}';\n"
    "    } catch (error, stack) {\n"
    "      state = AsyncError(error, stack);\n"
    "      return 'Selected HRV device refresh failed: $error';\n"
    "    }\n"
    "  }\n\n"
    "  BleDeviceCandidate _candidate(SavedDirectDevice device) =>")
replace('lib/screens/metric_detail_screen.dart',
    "  String? _selectedSource;",
    "  String? _selectedSource;\n  String? _refreshStatus;")
replace('lib/screens/metric_detail_screen.dart',
    "  Future<void> _syncAndLoad() async {\n"
    "    await ref.read(healthSyncProvider.notifier).sync(forceDirect: true);\n"
    "    if (!mounted) return;\n"
    "    setState(() => _future = _load());\n"
    "  }",
    "  Future<void> _syncAndLoad() async {\n"
    "    final source=ref.read(appStateProvider).metricSources[widget.metric];\n"
    "    String? result;\n"
    "    if(widget.metric=='HRV' && source != null && source.startsWith('ble:')) {\n"
    "      result=await ref.read(healthSyncProvider.notifier).refreshSelectedHrv();\n"
    "    } else {\n"
    "      await ref.read(healthSyncProvider.notifier).sync(forceDirect:true);\n"
    "    }\n"
    "    if(!mounted)return;\n"
    "    setState(() { _refreshStatus=result; _future=_load(); });\n"
    "  }")
replace('lib/screens/metric_detail_screen.dart',
    "            children: [\n"
    "              Text(MetricHistoryService.labelFor(widget.metric),",
    "            children: [\n"
    "              if (_refreshStatus != null) ...[\n"
    "                Text(_refreshStatus!, style: const TextStyle(\n"
    "                  color: AppTheme.textSecondary, fontSize: 12)),\n"
    "                const SizedBox(height: 10),\n"
    "              ],\n"
    "              Text(MetricHistoryService.labelFor(widget.metric),")

# Source picker accurately distinguishes standard HRV from firmware index-only
# without locking the picker to one manufacturer's hardware.
replace('lib/screens/sources_screen.dart',
    "    final choices = SourceHubService.healthChoicesForMetric(health, metric);",
    "    final qualifiedChoices = SourceHubService.healthChoicesForMetric(health, metric);\n"
    "    final indexChoices = metric == 'HRV'\n"
    "        ? SourceHubService.healthChoicesForMetric(health, 'Ring HRV proxy')\n"
    "            .where((s) => !qualifiedChoices.any((q) =>\n"
    "                SourceNameService.sameProvider(q.id, s.id))).toList()\n"
    "        : <HealthyDataSource>[];\n"
    "    final choices = [...qualifiedChoices, ...indexChoices];")
replace('lib/screens/sources_screen.dart',
    "                  subtitle: '${source.transportLabel} • ${source.recordsFor(metric)} records • use only for $metric',",
    "                  subtitle: metric == 'HRV' && !source.provides('HRV')\n"
    "                      ? '${source.transportLabel} • ${source.recordsFor('Ring HRV proxy')} index records • not RMSSD or Recovery'\n"
    "                      : '${source.transportLabel} • ${source.recordsFor(metric)} records • use only for $metric',")
replace('lib/screens/sources_screen.dart',
    "                child: Text('COLMI ring firmware HRV-index data is not verified RMSSD. Choosing the ring cannot turn its index into HRV milliseconds; ring history is shown separately in the HRV detail screen.',",
    "                child: Text('Some providers expose an HRV firmware index rather than RMSSD in milliseconds. Their real index history is visible, but it is not used as verified HRV in Recovery.',")

# Versioning must skip older source migration scripts, and every existing
# version-dependent test needs the same current build identifier.
replace('pubspec.yaml','version: 0.21.44+82','version: 0.21.45+83')
for p in Path('test').glob('*.dart'):
    data=p.read_text()
    if 'version: 0.21.44+82' in data:
        p.write_text(data.replace('version: 0.21.44+82','version: 0.21.45+83'))
replace('test/build82_ring_hrv_visibility_test.dart',
    "expect(home, contains('Ring HRV index'));",
    "expect(home, contains('Device HRV index'));")
replace('test/build82_ring_hrv_visibility_test.dart',
    "expect(home, contains(\"s.metric == 'Ring HRV proxy'\"));",
    "expect(home, contains('HrvSourceService.resolve('));")
replace('test/build75_dark_premium_contract_test.dart',
    '(37|38|39|40|41|42|43|44)\\+(75|76|77|78|79|80|81|82)',
    '(37|38|39|40|41|42|43|44|45)\\+(75|76|77|78|79|80|81|82|83)')
print('Build83: device-neutral HRV source resolver, UI, and protocol')
