import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../services/source_name_service.dart';
import '../../state/app_state.dart';
import '../../widgets/salus_widgets.dart';

class HealthVitalsScreen extends ConsumerWidget {
  const HealthVitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(appStateProvider).health;
    String sourceFor(String metric) {
      final id = h.resolvedSources[metric];
      if (id == null || id.isEmpty) return 'No connected source';
      return h.sourceLabels[id] ?? SourceNameService.friendly(id);
    }
    String detail(String metric) {
      final last = h.freshness[metric];
      final source = sourceFor(metric);
      return last == null ? source : '$source • ${relativeAge(last)}';
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      const SalusSectionTitle(title: 'Vitals', eyebrow: 'Measured signals'),
      const SizedBox(height: 6),
      const Text('Tap any measurement for its own source-separated chart, timestamps and history.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
      const SizedBox(height: 16),
      _row(context, 'Heart rate', 'Heart rate', h.latestHeartRate, 'bpm',
          Icons.favorite_rounded, AppTheme.amber, detail('Heart rate')),
      _row(context, 'Resting heart rate', 'Resting heart rate', h.restingHeartRate,
          'bpm', Icons.favorite_border_rounded, AppTheme.rose,
          detail('Resting heart rate')),
      _row(context, 'Heart-rate variability', 'HRV', h.hrvMs, 'ms',
          Icons.insights_rounded, AppTheme.mint, detail('HRV')),
      _row(context, 'Blood oxygen', 'SpO2', h.bloodOxygenPercent, '%',
          Icons.water_drop_outlined, AppTheme.blue, detail('SpO2')),
      _row(context, 'Respiratory rate', 'Respiratory rate', h.respiratoryRate,
          '/min', Icons.air_rounded, AppTheme.cyan, detail('Respiratory rate')),
      const SizedBox(height: 13),
      const Text('Recorded wellness signals are not a diagnosis.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
    ]);
  }

  Widget _row(BuildContext context, String label, String metric,
      double? value, String unit, IconData icon, Color accent, String source) {
    return SalusPaper(
      margin: const EdgeInsets.only(bottom: 9),
      onTap: () => Navigator.of(context).pushNamed(
          metric == 'SpO2' ? '/spo2-history' : '/metric-${_slug(metric)}'),
      child: Row(children: [
        Container(width: 46, height: 46,
          decoration: BoxDecoration(color: accent.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: accent, size: 23)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppTheme.textPrimary,
              fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(source, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ])),
        const SizedBox(width: 8),
        Text(value == null ? '—' : '${value.toStringAsFixed(0)} $unit',
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(width: 5),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
      ]),
    );
  }

  String _slug(String metric) => metric.toLowerCase().replaceAll(' ', '-');
}
