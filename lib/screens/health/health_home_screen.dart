import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import 'health_shell.dart';

class HealthHomeScreen extends ConsumerWidget {
  const HealthHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final h = app.health;
    final labs = [...app.labs]
      ..sort((a, b) {
        final aa = a.date ?? DateTime(1900);
        final bb = b.date ?? DateTime(1900);
        return bb.compareTo(aa);
      });
    final datedLabs = labs.where((lab) => lab.date != null).toList();
    final latestLabDate = datedLabs.isEmpty ? null : datedLabs.first.date;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: [
        const Text(
          'Health',
          style: TextStyle(
            color: HealthPalette.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Vitals and bloodwork Healthy Me can already use as slower-moving health context.',
          style: TextStyle(
            color: HealthPalette.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        _HealthCard(
          title: 'Current vitals',
          icon: Icons.monitor_heart_rounded,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: 'Resting HR',
                      value: h.restingHeartRate == null
                          ? '—'
                          : '${h.restingHeartRate!.round()} bpm',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniMetric(
                      label: 'HRV',
                      value: h.hrvMs == null ? '—' : '${h.hrvMs!.round()} ms',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: 'Blood oxygen',
                      value: h.bloodOxygenPercent == null
                          ? '—'
                          : '${h.bloodOxygenPercent!.toStringAsFixed(1)}%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Breathing',
                      value: h.respiratoryRate == null
                          ? '—'
                          : '${h.respiratoryRate!.toStringAsFixed(1)}/min',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HealthCard(
          title: 'Bloodwork',
          icon: Icons.science_rounded,
          accent: HealthPalette.blue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${labs.length} result${labs.length == 1 ? '' : 's'} stored',
                style: const TextStyle(
                  color: HealthPalette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                latestLabDate == null
                    ? 'No dated bloodwork entered yet.'
                    : 'Newest collection: ${latestLabDate.month}/${latestLabDate.day}/${latestLabDate.year}',
                style: const TextStyle(
                  color: HealthPalette.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color accent;

  const _HealthCard({
    required this.title,
    required this.icon,
    required this.child,
    this.accent = HealthPalette.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HealthPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HealthPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 23),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: HealthPalette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HealthPalette.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HealthPalette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: HealthPalette.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
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
