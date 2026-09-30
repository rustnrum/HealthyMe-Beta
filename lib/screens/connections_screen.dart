import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_models.dart';
import '../providers/connections_provider.dart';
import '../widgets/section_card.dart';

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  static const metrics = [
    'Steps',
    'Sleep',
    'Heart rate',
    'Weight',
    'Body fat',
    'Workouts',
  ];

  void _showSetupInfo(BuildContext context, DataSource source) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(source.subtitle),
            const SizedBox(height: 16),
            const Text(
              'Native authorization is not enabled in Beta 0.2 yet. Healthy Me will not pretend this provider is connected.',
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionsProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        Text(
          'Connections',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Pick a source per metric. Your phone brand does not decide the whole app.',
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Metric sources',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Auto is recommended until you want to override a metric.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              ...metrics.map((metric) {
                final compatible = supportedSources
                    .where((source) => source.metrics.contains(metric))
                    .toList();
                final selected =
                    state.preferredSourceByMetric[metric] ?? 'auto';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration: InputDecoration(labelText: metric),
                    items: [
                      const DropdownMenuItem(
                        value: 'auto',
                        child: Text('Auto / Recommended'),
                      ),
                      ...compatible.map(
                        (source) => DropdownMenuItem(
                          value: source.id,
                          child: Text(source.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(connectionsProvider.notifier)
                            .setPreferredSource(metric, value);
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Supported providers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        ...supportedSources.map(
          (source) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      _providerIcon(source.id),
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                source.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const _StatusPill(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(source.subtitle),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: source.metrics
                              .map(
                                (metric) => Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(metric),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showSetupInfo(context, source),
                          icon: const Icon(Icons.link),
                          label: const Text('Connection details'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _providerIcon(String id) {
    switch (id) {
      case 'smart_scale':
        return Icons.monitor_weight_outlined;
      case 'health_connect':
        return Icons.health_and_safety_outlined;
      case 'samsung_health':
        return Icons.watch_outlined;
      case 'fitbit':
        return Icons.watch_outlined;
      case 'garmin':
        return Icons.directions_run;
      default:
        return Icons.hub_outlined;
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Not connected',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
