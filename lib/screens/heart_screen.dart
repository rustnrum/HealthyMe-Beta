import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/command_card.dart';

class HeartScreen extends ConsumerWidget {
  const HeartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(appStateProvider).health;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Heart Health',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          CommandCard(
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: AppTheme.rose,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.restingHeartRate == null
                            ? '—'
                            : '${h.restingHeartRate!.round()} bpm',
                        style: const TextStyle(
                          fontSize: 31,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text('Resting heart rate'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CommandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Heart rate • recent',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                HeartTrendChart(values: h.heartSeries),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Average',
                  value: _bpm(h.averageHeartRate),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: 'Highest',
                  value: _bpm(h.maximumHeartRate),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(
                  label: 'Lowest',
                  value: _bpm(h.minimumHeartRate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CommandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Other available signals',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _line(
                  'HRV',
                  h.hrvMs == null ? '—' : '${h.hrvMs!.round()} ms',
                ),
                _line(
                  'Blood oxygen',
                  h.bloodOxygenPercent == null
                      ? '—'
                      : '${h.bloodOxygenPercent!.toStringAsFixed(1)}%',
                ),
                _line(
                  'Respiratory rate',
                  h.respiratoryRate == null
                      ? '—'
                      : '${h.respiratoryRate!.toStringAsFixed(1)} /min',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Healthy Me compares available cardiovascular signals with your own recent pattern. It does not diagnose heart conditions.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _bpm(double? value) =>
      value == null ? '—' : '${value.round()}';

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return CommandCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value == '—' ? value : '$value bpm',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
