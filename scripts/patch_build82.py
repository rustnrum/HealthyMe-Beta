#!/usr/bin/env python3
"""Build 82: expose COLMI ring firmware HRV-index history without mislabeling RMSSD.
No change to Recovery scoring, signing, package id, or saved readings.
"""
from pathlib import Path

def replace(path, old, new):
    p = Path(path)
    s = p.read_text()
    n = s.count(old)
    if n != 1:
        raise RuntimeError(f'Build82 anchor mismatch {path}: {n}: {old[:100]!r}')
    p.write_text(s.replace(old, new, 1))

pub=Path('pubspec.yaml').read_text()
if 'version: 0.21.44+82' in pub:
    print('Build 82 already applied')
    raise SystemExit(0)
if 'version: 0.21.43+81' not in pub:
    raise RuntimeError('Build 82 needs a successful 0.21.43+81 base')

# Keep the firmware index separate from standard Health Connect RMSSD.
replace('lib/services/metric_history_service.dart',
    '  final List<DirectMetricSample> excludedGarminHrv;\n  const MetricHistoryResult({required this.readings, this.warning,\n      this.excludedGarminHrv = const []});',
    '  final List<DirectMetricSample> excludedGarminHrv;\n'
    '  /// COLMI command-57 firmware index, NOT validated RMSSD (milliseconds).\n'
    '  final List<DirectMetricSample> ringHrvProxy;\n'
    '  const MetricHistoryResult({required this.readings, this.warning,\n'
    '      this.excludedGarminHrv = const [], this.ringHrvProxy = const []});')
replace('lib/services/metric_history_service.dart',
    '    final stored = await DirectMetricService().loadSamples();\n    final readings = <DirectMetricSample>[...stored];',
    '    final stored = await DirectMetricService().loadSamples();\n'
    "    final ringHrvProxy = metric == 'HRV'\n"
    "        ? normalize('Ring HRV proxy', stored.where((s) =>\n"
    "            s.metric == 'Ring HRV proxy' && s.value >= 1 && s.value <= 254))\n"
    '        : <DirectMetricSample>[];\n'
    '    final readings = <DirectMetricSample>[...stored];')
replace('lib/services/metric_history_service.dart',
    '      excludedGarminHrv: excludedGarmin,\n',
    '      excludedGarminHrv: excludedGarmin,\n      ringHrvProxy: ringHrvProxy,\n')

# HRV details: direct evidence, source isolation, count, timestamped chart,
# and explicit statement that a proprietary index cannot fill RMSSD Recovery.
replace('lib/screens/metric_detail_screen.dart',
    '          final all = snapshot.data?.readings ?? const <DirectMetricSample>[];',
    "          final all = snapshot.data?.readings ?? const <DirectMetricSample>[];\n"
    "          final ringHistory = snapshot.data?.ringHrvProxy ?? const <DirectMetricSample>[];\n"
    "          final ringSelected = configured != null && configured.startsWith('ble:');\n"
    "          final selectedRingHistory = ringSelected\n"
    "              ? ringHistory.where((s) => SourceNameService.sameProvider(s.sourceId, configured)).toList()\n"
    "              : ringHistory;\n")
replace('lib/screens/metric_detail_screen.dart',
    "              if (widget.metric == 'HRV' && sources.isEmpty) ...[",
    "              if (widget.metric == 'HRV') ...[\n"
    "                Container(\n"
    "                  padding: const EdgeInsets.all(14),\n"
    "                  decoration: BoxDecoration(\n"
    "                    color: AppTheme.surfaceHigh,\n"
    "                    border: Border.all(color: AppTheme.border),\n"
    "                    borderRadius: BorderRadius.circular(16)),\n"
    "                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n"
    "                    const Text('Ring HRV firmware history', style: TextStyle(\n"
    "                        color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),\n"
    "                    const SizedBox(height: 5),\n"
    "                    Text('${selectedRingHistory.length} saved index readings from the selected ring',\n"
    "                        style: const TextStyle(color: AppTheme.textSecondary)),\n"
    "                    const SizedBox(height: 7),\n"
    "                    const Text('These are real device-reported firmware index values, not verified RMSSD in milliseconds. They cannot count toward the Recovery HRV baseline.',\n"
    "                        style: TextStyle(color: AppTheme.amber, fontSize: 12)),\n"
    "                    if (selectedRingHistory.isNotEmpty) ...[\n"
    "                      const SizedBox(height: 13),\n"
    "                      Text('Last index: ${selectedRingHistory.last.value.round()} • ${_time(selectedRingHistory.last.capturedAt)}',\n"
    "                          style: const TextStyle(color: AppTheme.textPrimary)),\n"
    "                      const SizedBox(height: 8),\n"
    "                      SizedBox(height: 180, child: CustomPaint(\n"
    "                        painter: _MetricChartPainter(selectedRingHistory),\n"
    "                        child: const SizedBox.expand())),\n"
    "                    ] else ...[\n"
    "                      const SizedBox(height: 7),\n"
    "                      const Text('No ring-index records have been imported into Salus from this source. QRing may have its own separate history. Tap Refresh to request a new Bluetooth read.',\n"
    "                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),\n"
    "                    ],\n"
    "                    TextButton.icon(onPressed: _syncAndLoad,\n"
    "                      icon: const Icon(Icons.refresh),\n"
    "                      label: const Text('Refresh ring history')),\n"
    "                  ]),\n"
    "                ),\n"
    "                const SizedBox(height: 14),\n"
    "              ],\n"
    "              if (widget.metric == 'HRV' && sources.isEmpty && ringHistory.isEmpty) ...[")
replace('lib/screens/metric_detail_screen.dart',
    "                const Text(\n                    'The vívoactive 6 Bluetooth stream does not supply a '\n                    'verified overnight HRV average through this Salus reader. '\n                    'Your previous brief R–R estimates cannot establish a '\n                    'reliable HRV baseline. Recovery will exclude them. '\n                    'A source that provides timestamped RMSSD records is needed.',",
    "                const Text(\n                    'The selected device has not supplied verified RMSSD HRV '\n                    'readings through Salus. Ring firmware-index records are '\n                    'shown separately when available and cannot substitute '\n                    'for a verified HRV baseline in Recovery. Recovery will exclude them.',")

# Make the currently selected ring's index trend visible in Home while
# leaving clinical-style HRV & Recovery untouched.
replace('lib/screens/premium/salus_home_77.dart',
    "import '../../services/recovery_service.dart';",
    "import '../../services/recovery_service.dart';\nimport '../../services/direct_metric_service.dart';")
replace('lib/screens/premium/salus_home_77.dart',
    '  double? _calorieGoal;\n  @override void initState(){super.initState();SalusAppearance.load();_loadTarget();}',
    "  double? _calorieGoal;\n"
    "  List<DirectMetricSample> _ringHrvHistory = const [];\n"
    "  Future<void> _loadRingHrvHistory() async {\n"
    "    try {\n"
    "      final samples = await const DirectMetricService().loadSamples();\n"
    "      if (mounted) setState(() => _ringHrvHistory = samples.where((s) =>\n"
    "          s.metric == 'Ring HRV proxy' && s.value >= 1 && s.value <= 254).toList());\n"
    "    } catch (_) { /* Failed history read must not block the Home page. */ }\n"
    "  }\n"
    "  @override void initState(){super.initState();SalusAppearance.load();_loadTarget();_loadRingHrvHistory();}")
replace('lib/screens/premium/salus_home_77.dart',
    "    final app=ref.watch(appStateProvider),h=app.health;",
    "    final app=ref.watch(appStateProvider),h=app.health;\n"
    "    ref.listen(appStateProvider, (previous, next) {\n"
    "      if (previous?.health.lastSync != next.health.lastSync) _loadRingHrvHistory();\n"
    "    });\n"
    "    final ringSource=app.metricSources['HRV'];\n"
    "    final selectedRingHrv=ringSource != null && ringSource.startsWith('ble:')\n"
    "        ? _ringHrvHistory.where((s) => s.sourceId == ringSource).toList()\n"
    "        : <DirectMetricSample>[];")
replace('lib/screens/premium/salus_home_77.dart',
    "Expanded(child:_trend(context,'HRV',h.hrv30.map((v)=>v.toDouble()).toList(),S77.blue,'ms','/metric-hrv'))",
    "Expanded(child:h.hrv30.length < 2 && selectedRingHrv.isNotEmpty\n"
    "              ? _ringIndexTrend(context,selectedRingHrv)\n"
    "              : _trend(context,'HRV',h.hrv30.map((v)=>v.toDouble()).toList(),S77.blue,'ms','/metric-hrv'))")
replace('lib/screens/premium/salus_home_77.dart',
    "  Widget _signal(IconData icon,Color color,String label,String reading)=>Row(children:[",
    "  Widget _ringIndexTrend(BuildContext context,List<DirectMetricSample> values)=>\n"
    "    S77Surface(onTap:()=>Navigator.pushNamed(context,'/metric-hrv'),\n"
    "      padding:const EdgeInsets.all(10),\n"
    "      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[\n"
    "        Text('Ring HRV index',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:12)),\n"
    "        Text('${values.length} ring records • not RMSSD',\n"
    "          style:TextStyle(color:S77.sub,fontSize:9)),\n"
    "        const SizedBox(height:4),\n"
    "        PremiumLineChart(values:values.map((s)=>s.value).toList(),\n"
    "          color:S77.blue,height:90,unit:'index'),\n"
    "      ]));\n"
    "  Widget _signal(IconData icon,Color color,String label,String reading)=>Row(children:[")

replace('lib/screens/sources_screen.dart',
    "              const Text(\n                'Salus routes this metric to the provider you choose.',",
    "              if (metric == 'HRV') const Padding(\n"
    "                padding: EdgeInsets.only(top: 6, bottom: 9),\n"
    "                child: Text('COLMI ring firmware HRV-index data is not verified RMSSD. Choosing the ring cannot turn its index into HRV milliseconds; ring history is shown separately in the HRV detail screen.',\n"
    "                  style: TextStyle(color: AppTheme.amber, fontSize: 12)),\n"
    "              ),\n"
    "              const Text(\n                'Salus routes this metric to the provider you choose.',")

replace('pubspec.yaml','version: 0.21.43+81','version: 0.21.44+82')
for filename in [
    'build76_light_dark_navigation_contract_test.dart',
    'build77_visual_navigation_contract_test.dart',
    'build78_visual_match_test.dart',
    'build79_energy_contract_test.dart',
    'build80_design_energy_contract_test.dart',
    'build81_rhr_hrv_contract_test.dart',
]:
    replace('test/'+filename,'version: 0.21.43+81','version: 0.21.44+82')
replace('test/build75_dark_premium_contract_test.dart',
    "r'^version: 0\\.21\\.(37|38|39|40|41|42|43)\\+(75|76|77|78|79|80|81)$'",
    "r'^version: 0\\.21\\.(37|38|39|40|41|42|43|44)\\+(75|76|77|78|79|80|81|82)$'")
print('Build82: ring firmware HRV index is visible and source-isolated')
