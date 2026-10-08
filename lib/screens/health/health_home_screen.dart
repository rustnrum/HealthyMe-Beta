import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../widgets/salus_widgets.dart';
import 'health_shell.dart';

class HealthHomeScreen extends ConsumerWidget {
  const HealthHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final h = app.health;
    final labs = [...app.labs]..sort((a,b) => (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900)));
    final latestLabDate = labs.where((e) => e.date != null).isEmpty ? null : labs.where((e) => e.date != null).first.date;
    final updated = h.lastSync == null ? 'Not synced yet' : 'Updated ${h.lastSync!.hour.toString().padLeft(2,'0')}:${h.lastSync!.minute.toString().padLeft(2,'0')}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        const SalusSectionTitle(title: 'Health', eyebrow: 'A broader picture'),
        const SizedBox(height: 5),
        const Text('Vitals and bloodwork Salus can use as slower-moving health context.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4, fontStyle: FontStyle.italic)),
        const SizedBox(height: 14),
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x226C7849)), child: const Icon(Icons.monitor_heart_outlined, color: HealthPalette.mint, size: 25)), const SizedBox(width: 12), const Expanded(child: Text('Current Vitals', style: TextStyle(color: HealthPalette.textPrimary, fontSize: 22, fontWeight: FontWeight.w700))), Text(updated, style: const TextStyle(color: HealthPalette.textMuted, fontSize: 12))]),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: _VitalCard(label: 'Resting HR', value: h.restingHeartRate == null ? '—' : '${h.restingHeartRate!.round()} bpm', icon: Icons.favorite_border_rounded, tint: AppTheme.rose)), const SizedBox(width: 9), Expanded(child: _VitalCard(label: 'HRV', value: h.hrvMs == null ? '—' : '${h.hrvMs!.round()} ms', icon: Icons.insights_rounded, tint: AppTheme.mint))]),
          const SizedBox(height: 9),
          Row(children: [Expanded(child: InkWell(
            onTap: () => Navigator.of(context).pushNamed('/spo2-history'),
            child: _VitalCard(label: 'Blood Oxygen', value: h.bloodOxygenPercent == null ? '—' : '${h.bloodOxygenPercent!.toStringAsFixed(1)}%', icon: Icons.air_rounded, tint: AppTheme.blue))), const SizedBox(width: 9), Expanded(child: _VitalCard(label: 'Breathing', value: h.respiratoryRate == null ? '—' : '${h.respiratoryRate!.toStringAsFixed(1)}/min', icon: Icons.air_rounded, tint: AppTheme.teal))]),
          const SizedBox(height: 6),
          const Text('Tap Blood Oxygen to see your stored history and source.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ])),
        const SizedBox(height: 11),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/cpap'),
          child: SalusPaper(child: Row(children: [
            Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x2262E8F2)), child: const Icon(Icons.air_rounded, color: AppTheme.cyan, size: 25)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CPAP Therapy', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 3),
              Text('Nightly therapy, 7/30-day trends and Salus insights from your CPAP provider.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.2, height: 1.35)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          ])),
        ),
        const SizedBox(height: 11),
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.science_outlined, color: AppTheme.mint, size: 28), SizedBox(width: 10), Text('Bloodwork', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 10),
          Text('${labs.length} result${labs.length == 1 ? '' : 's'} stored', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(latestLabDate == null ? 'No dated bloodwork entered yet.' : 'Newest collection: ${latestLabDate.month}/${latestLabDate.day}/${latestLabDate.year}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.surfaceHigh.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(11)), child: const Row(children: [Icon(Icons.note_add_outlined, color: AppTheme.amber), SizedBox(width: 10), Expanded(child: Text('Add results to help Salus understand your longer-term baseline.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5))), Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary)])),
        ])),
        const SizedBox(height: 11),
        SalusPaper(child: const Row(children: [CircleAvatar(backgroundColor: Color(0x226C7849), child: Icon(Icons.eco_outlined, color: AppTheme.mint)), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Health Context', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)), SizedBox(height: 3), Text('Vitals and labs help Salus understand your baseline and track meaningful changes over time.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.35))]))])),
      ],
    );
  }
}

class _VitalCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color tint;
  const _VitalCard({required this.label, required this.value, required this.icon, required this.tint});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.surfaceHigh.withValues(alpha: 0.68), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border.withValues(alpha: 0.45))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: tint, size: 19), const SizedBox(width: 7), Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)))]), const SizedBox(height: 8), Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700))]));
}
