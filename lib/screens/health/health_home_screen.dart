import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../widgets/salus_widgets.dart';

class HealthHomeScreen extends ConsumerWidget {
  const HealthHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final h = app.health;
    final dated = app.labs.where((e) => e.date != null).toList()
      ..sort((a, b) => b.date!.compareTo(a.date!));
    final newest = dated.isEmpty ? null : dated.first.date;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
      const SalusSectionTitle(title: 'Health', eyebrow: 'Your measured history'),
      const SizedBox(height: 5),
      const Text('Real data from your chosen devices and health providers. Tap a vital for its own chart.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
      const SizedBox(height: 15),
      SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.monitor_heart_outlined, size: 28, color: AppTheme.mint),
          const SizedBox(width: 10),
          const Expanded(child: Text('Current vitals', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 21,
              fontWeight: FontWeight.w800))),
          Text(h.lastSync == null ? 'Not synced' :
              '${h.lastSync!.month}/${h.lastSync!.day}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: _card(context, 'Resting HR', h.restingHeartRate,
              'bpm', Icons.favorite_border_rounded, '/metric-resting-heart-rate')),
          const SizedBox(width: 9),
          Expanded(child: _card(context, 'HRV', h.hrvMs, 'ms',
              Icons.insights_rounded, '/metric-hrv')),
        ]),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(child: _card(context, 'Blood oxygen', h.bloodOxygenPercent,
              '%', Icons.water_drop_outlined, '/spo2-history')),
          const SizedBox(width: 9),
          Expanded(child: _card(context, 'Respiration', h.respiratoryRate,
              '/min', Icons.air_rounded, '/metric-respiratory-rate')),
        ]),
      ])),
      const SizedBox(height: 11),
      SalusPaper(onTap: () => Navigator.of(context).pushNamed('/metric-heart-rate'),
        child: const Row(children: [
          Icon(Icons.favorite_rounded, color: AppTheme.rose, size: 26),
          SizedBox(width: 11), Expanded(child: Text('Heart-rate history',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 17,
                fontWeight: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ])),
      const SizedBox(height: 11),
      SalusPaper(onTap: () => Navigator.of(context).pushNamed('/cpap'),
        child: const Row(children: [
          Icon(Icons.air_rounded, color: AppTheme.cyan, size: 28),
          SizedBox(width: 11), Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CPAP Therapy', style: TextStyle(color: AppTheme.textPrimary,
                  fontSize: 19, fontWeight: FontWeight.w800)),
              Text('Read-only therapy history from your supported device',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
            ])),
          Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ])),
      const SizedBox(height: 11),
      SalusPaper(onTap: () => Navigator.of(context).pushNamed('/labs'),
        child: Row(children: [
          const Icon(Icons.science_outlined, color: AppTheme.mint, size: 30),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bloodwork', style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 19, fontWeight: FontWeight.w800)),
            Text('${app.labs.length} result${app.labs.length == 1 ? '' : 's'} stored',
                style: const TextStyle(color: AppTheme.textSecondary)),
            if (newest != null)
              Text('Latest: ${newest.month}/${newest.day}/${newest.year}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ])),
      const SizedBox(height: 12),
      const Text('Salus displays wellness data and personal trends, not medical diagnoses.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5)),
    ]);
  }

  Widget _card(BuildContext context, String label, double? value,
      String unit, IconData icon, String route) => SalusPaper(
    padding: const EdgeInsets.all(12),
    onTap: () => Navigator.of(context).pushNamed(route),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppTheme.cyan, size: 22),
      const SizedBox(height: 7),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary,
          fontSize: 12)),
      const SizedBox(height: 4),
      Text(value == null ? '—' : '${value.toStringAsFixed(0)} $unit',
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 19,
            fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Align(alignment: Alignment.centerRight,
          child: Icon(Icons.chevron_right_rounded,
              color: AppTheme.textMuted, size: 17)),
    ]),
  );
}
