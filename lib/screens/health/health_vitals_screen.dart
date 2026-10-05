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
    final app = ref.watch(appStateProvider); final h = app.health;
    String sourceFor(String metric) { final key = h.resolvedSources[metric]; if (key == null || key.isEmpty) return 'No connected source'; return h.sourceLabels[key] ?? SourceNameService.friendly(key); }
    String detailFor(String metric) { final fresh = h.freshness[metric]; final source = sourceFor(metric); return fresh == null ? source : '$source • ${relativeAge(fresh)}'; }
    return ListView(padding: const EdgeInsets.fromLTRB(16,16,16,30), children: [
      const SalusSectionTitle(title: 'Vitals', eyebrow: 'Current signals'),
      const SizedBox(height: 5),
      const Text('Each vital keeps the provider that actually supplied that metric visible.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
      const SizedBox(height: 14),
      _VitalRow(icon: Icons.favorite_border_rounded, label: 'Resting heart rate', value: h.restingHeartRate == null ? '—' : '${h.restingHeartRate!.round()} bpm', source: detailFor('Resting heart rate'), tint: AppTheme.rose),
      _VitalRow(icon: Icons.insights_rounded, label: 'Heart-rate variability', value: h.hrvMs == null ? '—' : '${h.hrvMs!.round()} ms', source: detailFor('HRV'), tint: AppTheme.mint),
      _VitalRow(icon: Icons.air_rounded, label: 'Blood oxygen', value: h.bloodOxygenPercent == null ? '—' : '${h.bloodOxygenPercent!.toStringAsFixed(1)}%', source: detailFor('SpO2'), tint: AppTheme.blue),
      _VitalRow(icon: Icons.air_rounded, label: 'Respiratory rate', value: h.respiratoryRate == null ? '—' : '${h.respiratoryRate!.toStringAsFixed(1)} /min', source: detailFor('Respiratory rate'), tint: AppTheme.teal),
      _VitalRow(icon: Icons.favorite_rounded, label: 'Latest heart rate', value: h.latestHeartRate == null ? '—' : '${h.latestHeartRate!.round()} bpm', source: detailFor('Heart rate'), tint: AppTheme.amber),
      const SizedBox(height: 8),
      const Text('These are connected health signals, not diagnoses. Salus uses trends and personal baselines where enough history exists.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5, height: 1.4)),
    ]);
  }
}

class _VitalRow extends StatelessWidget {
  final IconData icon; final String label, value, source; final Color tint;
  const _VitalRow({required this.icon, required this.label, required this.value, required this.source, required this.tint});
  @override
  Widget build(BuildContext context) => SalusPaper(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(14), child: Row(children: [
    Container(width: 44,height:44,decoration:BoxDecoration(shape:BoxShape.circle,color:tint.withValues(alpha:0.15)),child:Icon(icon,color:tint,size:22)), const SizedBox(width:12),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:AppTheme.textPrimary,fontSize:15,fontWeight:FontWeight.w700)),const SizedBox(height:3),Text(source,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:12))])),
    const SizedBox(width:8),Text(value,style:const TextStyle(color:AppTheme.textPrimary,fontSize:17,fontWeight:FontWeight.w700)),
  ]));
}
