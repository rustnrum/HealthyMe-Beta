import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../services/source_name_service.dart';
import '../../state/app_state.dart';
import 'health_shell.dart';

class HealthVitalsScreen extends ConsumerWidget {
  const HealthVitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final h = app.health;

    String sourceFor(String metric) {
      final key = h.resolvedSources[metric];
      if (key == null || key.isEmpty) return 'No connected source';
      return h.sourceLabels[key] ?? SourceNameService.friendly(key);
    }

    String detailFor(String metric) {
      final fresh = h.freshness[metric];
      final source = sourceFor(metric);
      return fresh == null ? source : '$source • ${relativeAge(fresh)}';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: [
        const Text(
          'Vitals',
          style: TextStyle(
            color: HealthPalette.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Each vital shows the provider that actually supplied that metric.',
          style: TextStyle(
            color: HealthPalette.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 18),
        _VitalRow(
          icon: Icons.favorite_rounded,
          label: 'Resting heart rate',
          value: h.restingHeartRate == null
              ? '—'
              : '${h.restingHeartRate!.round()} bpm',
          source: detailFor('Resting heart rate'),
        ),
        _VitalRow(
          icon: Icons.insights_rounded,
          label: 'Heart-rate variability',
          value: h.hrvMs == null ? '—' : '${h.hrvMs!.round()} ms',
          source: detailFor('HRV'),
        ),
        _VitalRow(
          icon: Icons.bloodtype_rounded,
          label: 'Blood oxygen',
          value: h.bloodOxygenPercent == null
              ? '—'
              : '${h.bloodOxygenPercent!.toStringAsFixed(1)}%',
          source: detailFor('SpO2'),
        ),
        _VitalRow(
          icon: Icons.air_rounded,
          label: 'Respiratory rate',
          value: h.respiratoryRate == null
              ? '—'
              : '${h.respiratoryRate!.toStringAsFixed(1)} /min',
          source: detailFor('Respiratory rate'),
        ),
        _VitalRow(
          icon: Icons.favorite_border_rounded,
          label: 'Latest heart rate',
          value: h.latestHeartRate == null
              ? '—'
              : '${h.latestHeartRate!.round()} bpm',
          source: detailFor('Heart rate'),
        ),
        const SizedBox(height: 8),
        const Text(
          'These are connected health signals, not diagnoses. Healthy Me uses trends and personal baselines where enough history exists.',
          style: TextStyle(
            color: HealthPalette.textMuted,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _VitalRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String source;

  const _VitalRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: HealthPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HealthPalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: HealthPalette.accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: HealthPalette.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: HealthPalette.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HealthPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: HealthPalette.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
