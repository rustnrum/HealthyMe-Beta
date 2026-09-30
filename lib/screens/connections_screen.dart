import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/health_provider.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(healthConnectionsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Connections',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose a provider per metric instead of locking the whole app to one ecosystem.',
        ),
        const SizedBox(height: 16),
        ...metrics.map((metric) {
          final compatible = state.sources
              .where((source) => source.metrics.contains(metric))
              .toList();
          final selected = state.selectedSourceByMetric[metric];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'auto',
                        child: Text('Auto (recommended)'),
                      ),
                      ...compatible.map(
                        (source) => DropdownMenuItem(
                          value: source.id,
                          child: Text(source.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      ref
                          .read(healthConnectionsProvider.notifier)
                          .chooseSource(metric, value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    compatible.isEmpty
                        ? 'No compatible source configured yet.'
                        : '${compatible.length} compatible source${compatible.length == 1 ? '' : 's'} available in this beta.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }),
        const Text(
          'Beta v0.1 models provider selection. Native provider authorization comes next.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
