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
    final sourceRaw = app.metricSources['Heart rate'];
    final source = sourceRaw == null
        ? 'Health Connect recommended'
        : SourceNameService.friendly(sourceRaw);
    final freshness = h.freshness['Heart rate'];

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
        Text(
          freshness == null
              ? 'No connected vital data available yet.'
              : '$source • data ${relativeAge(freshness)}',
          style: const TextStyle(
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
        ),
        _VitalRow(
          icon: Icons.insights_rounded,
          label: 'Heart-rate variability',
          value: h.hrvMs == null ? '—' : '${h.hrvMs!.round()} ms',
        ),
        _VitalRow(
          icon: Icons.bloodtype_rounded,
          label: 'Blood oxygen',
          value: h.bloodOxygenPercent == null
              ? '—'
              : '${h.bloodOxygenPercent!.toStringAsFixed(1)}%',
        ),
        _VitalRow(
          icon: Icons.air_rounded,
          label: 'Respiratory rate',
          value: h.respiratoryRate == null
              ? '—'
              : '${h.respiratoryRate!.toStringAsFixed(1)} /min',
        ),
        _VitalRow(
          icon: Icons.favorite_border_rounded,
          label: 'Latest heart rate',
          value: h.latestHeartRate == null
              ? '—'
              : '${h.latestHeartRate!.round()} bpm',
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

  const _VitalRow({
    required this.icon,
    required this.label,
    required this.value,
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
            child: Text(
              label,
              style: const TextStyle(
                color: HealthPalette.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
