import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/direct_metric_service.dart';
import '../../services/salus_temperature_service.dart';
import '../../state/app_state.dart';
import '../../widgets/salus_widgets.dart';

/// Evidence-first health trends. No made-up biological age/disease diagnosis.
class SalusHealthIntelligenceScreen extends ConsumerStatefulWidget {
  const SalusHealthIntelligenceScreen({super.key});
  @override
  ConsumerState<SalusHealthIntelligenceScreen> createState() => _SalusHealthIntelligenceScreenState();
}

class _SalusHealthIntelligenceScreenState extends ConsumerState<SalusHealthIntelligenceScreen> {
  final _service = const SalusTemperatureService();
  List<DirectMetricSample> _samples = const [];
  bool _working = false;
  String? _message;

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    try {
      final values = await _service.load();
      if (mounted) setState(() => _samples = values);
    } catch (e) {
      if (mounted) setState(() => _message = 'Cannot read temperature history: $e');
    }
  }

  Future<void> _import() async {
    if (_working) return;
    setState(() { _working = true; _message = null; });
    try {
      final result = await _service.importHealthConnect();
      await _refresh();
      if (mounted) setState(() => _message =
        'Imported ${result.imported} temperature reading(s). '
        '${result.warnings.join(' ')}'.trim());
    } catch (e) {
      if (mounted) setState(() => _message = 'Temperature import failed: $e');
    } finally { if (mounted) setState(() => _working = false); }
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(appStateProvider).health;
    final absoluteSkin = _samples.where((s) => s.metric == 'Skin temperature').toList();
    final core = _samples.where((s) => s.metric == 'Body temperature').toList();
    final delta = _samples.where((s) => s.metric == 'Skin temperature delta').toList();
    final change = SalusTemperatureService.baselineDelta(absoluteSkin);
    final recentSkin = absoluteSkin.reversed.take(48).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Health Intelligence')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        const SalusSectionTitle(title: 'Temperature & trends', eyebrow: 'Measured, source-attributed'),
        const SizedBox(height: 8),
        const Text('Skin temperature is not core body temperature. '
          'Salus shows only valid readings actually returned by your devices.',
          style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 14),
        _temperatureCard('Skin temperature', absoluteSkin, Icons.thermostat_outlined),
        const SizedBox(height: 8),
        _temperatureCard('Body temperature', core, Icons.device_thermostat),
        const SizedBox(height: 8),
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Personal skin-temperature trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 5),
          Text(change == null ? 'Not enough readings across four separate days to establish a trend.' :
            '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)} °C vs earlier daily averages from the same source.',
            style: const TextStyle(color: AppTheme.textSecondary)),
          if (delta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 7),
            child: Text('Health Connect has ${delta.length} temperature-delta record(s) without absolute baselines. '
              'They are kept separate from measured temperatures.',
              style: const TextStyle(color: AppTheme.textSecondary))),
        ])),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _working ? null : _import,
          icon: const Icon(Icons.health_and_safety_outlined),
          label: Text(_working ? 'Reading Health Connect…' : 'Import temperatures from Health Connect')),
        const SizedBox(height: 6),
        OutlinedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/sources'),
          icon: const Icon(Icons.monitor_heart_outlined), label: const Text('Health Connect sources')),
        if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(_message!, style: const TextStyle(color: AppTheme.textSecondary))),
        const SizedBox(height: 18),
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Other signals currently available', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          _signal('Resting heart rate', health.restingHeartRate, 'bpm'),
          _signal('HRV', health.hrvMs, 'ms'),
          _signal('Blood oxygen', health.bloodOxygenPercent, '%'),
          _signal('Respiratory rate', health.respiratoryRate, '/min'),
          const Text('Metrics are shown side by side, not combined into an invented illness score.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
        const SizedBox(height: 18),
        const Text('Recent skin-temperature readings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (recentSkin.isEmpty) const Text('No verified skin-temperature measurements yet. '
          'Import permissioned Health Connect records.',
          style: TextStyle(color: AppTheme.textSecondary))
        else for (final s in recentSkin)
          Padding(padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Expanded(child: Text('${s.deviceName} • ${_timestamp(s.capturedAt)}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary))),
              Text('${(s.value * 9 / 5 + 32).toStringAsFixed(1)} °F',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            ])),
        const SizedBox(height: 18),
        const Text('Next: validated lab-based biological age and cardiovascular risk. '
          'No unsupported longevity or illness score is generated in this beta.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      ]),
    );
  }

  Widget _signal(String name, double? value, String unit) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(name, style: const TextStyle(color: AppTheme.textSecondary))),
          Text(value == null ? 'No reading' : '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        ]));

  Widget _temperatureCard(String title, List<DirectMetricSample> values, IconData icon) {
    final latest = values.isEmpty ? null : values.last;
    return SalusPaper(child: Row(children: [
      Icon(icon, color: AppTheme.cyan, size: 30),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(latest == null ? 'No source reading yet' :
          '${latest.deviceName} • ${_timestamp(latest.capturedAt)}',
          maxLines: 2, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ])),
      Text(latest == null ? '—' : '${(latest.value * 9 / 5 + 32).toStringAsFixed(1)} °F',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    ]));
  }

  String _timestamp(DateTime date) {
    final t = date.toLocal();
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
