import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../widgets/command_card.dart';
import '../widgets/status_widgets.dart';

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

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
    final app = ref.watch(appStateProvider);
    final sync = ref.watch(healthSyncProvider);
    final h = app.health;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Devices & Sources',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          CommandCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0x2217C8F4),
                  child: Icon(
                    Icons.health_and_safety_outlined,
                    color: AppTheme.cyan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Health Connect',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TinyStatusPill(
                            text: h.authorized ? 'Connected' : 'Not connected',
                            color: h.authorized
                                ? AppTheme.mint
                                : AppTheme.amber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        h.lastSync == null
                            ? 'Central Android health-data connection'
                            : 'Last sync: ${relativeAge(h.lastSync)}',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: sync.isLoading
                                ? null
                                : () async {
                                    if (h.authorized) {
                                      await ref
                                          .read(healthSyncProvider.notifier)
                                          .sync();
                                    } else {
                                      await ref
                                          .read(healthSyncProvider.notifier)
                                          .connectAndSync();
                                    }
                                  },
                            icon: Icon(
                              h.authorized ? Icons.sync : Icons.add_link,
                            ),
                            label: Text(
                              h.authorized ? 'Sync now' : 'Connect',
                            ),
                          ),
                          if (h.authorized) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: sync.isLoading
                                  ? null
                                  : () => ref
                                      .read(healthSyncProvider.notifier)
                                      .disconnect(),
                              child: const Text('Disconnect'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Detected data origins',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (h.detectedSources.isEmpty)
            const CommandCard(
              child: Text(
                'No vendor data origins have been detected yet. Once Health Connect has records, Healthy Me will show the real source names here.',
              ),
            )
          else
            ...h.detectedSources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CommandCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _sourceColor(source).withValues(alpha: 0.14),
                        child: Icon(
                          _sourceIcon(source),
                          color: _sourceColor(source),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          source,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const TinyStatusPill(
                        text: 'Detected',
                        color: AppTheme.mint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Preferred source by metric',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'Auto uses Health Connect’s combined data. You can override a metric with a detected source.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          CommandCard(
            child: Column(
              children: metrics.map((metric) {
                final selected = app.metricSources[metric] ?? 'Auto';
                final options = ['Auto', ...h.detectedSources];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        options.contains(selected) ? selected : 'Auto',
                    decoration: InputDecoration(labelText: metric),
                    items: options
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      ref
                          .read(appStateProvider.notifier)
                          .setMetricSource(metric, value);
                      if (h.authorized) {
                        await ref
                            .read(healthSyncProvider.notifier)
                            .sync();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'A vendor is never labeled connected just because its logo exists. Healthy Me shows it as detected only when actual records identify that source.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static IconData _sourceIcon(String source) {
    final value = source.toLowerCase();
    if (value.contains('samsung')) return Icons.watch_outlined;
    if (value.contains('garmin')) return Icons.directions_run;
    if (value.contains('fitbit')) return Icons.watch;
    if (value.contains('withings')) return Icons.monitor_weight_outlined;
    return Icons.sensors_outlined;
  }

  static Color _sourceColor(String source) {
    final value = source.toLowerCase();
    if (value.contains('samsung')) return AppTheme.mint;
    if (value.contains('garmin')) return AppTheme.cyan;
    if (value.contains('fitbit')) return AppTheme.purple;
    if (value.contains('withings')) return AppTheme.amber;
    return AppTheme.cyan;
  }
}
