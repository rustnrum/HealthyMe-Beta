import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';

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
    final detected = h.detectedSources.toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Devices & Sources')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          CommandCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HmIconBadge(
                      icon: Icons.health_and_safety_rounded,
                      color: AppTheme.cyan,
                      size: 44,
                    ),
                    const SizedBox(width: 10),
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
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              HmStatusPill(
                                text: h.authorized ? 'Connected' : 'Not connected',
                                color: h.authorized ? AppTheme.mint : AppTheme.rose,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            h.lastSync == null
                                ? 'Android health-data hub'
                                : 'Last sync ${relativeAge(h.lastSync)}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: sync.isLoading
                            ? null
                            : () async {
                                if (h.authorized) {
                                  await ref.read(healthSyncProvider.notifier).sync();
                                } else {
                                  await ref
                                      .read(healthSyncProvider.notifier)
                                      .connectAndSync();
                                }
                              },
                        icon: Icon(h.authorized ? Icons.sync_rounded : Icons.add_link_rounded),
                        label: Text(h.authorized ? 'Sync now' : 'Connect'),
                      ),
                    ),
                    if (h.authorized) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: sync.isLoading
                              ? null
                              : () => ref
                                  .read(healthSyncProvider.notifier)
                                  .disconnect(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: const BorderSide(color: AppTheme.border),
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Disconnect'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const HmSectionHeader(title: 'Detected data origins'),
          const SizedBox(height: 8),
          if (detected.isEmpty)
            const CommandCard(
              child: HmEmptyState(
                icon: Icons.sensors_off_rounded,
                title: 'No vendor source detected yet',
                detail: 'Healthy Me will show the real source names here once Health Connect records identify them.',
              ),
            )
          else
            CommandCard(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
              child: Column(
                children: [
                  for (var i = 0; i < detected.length; i++) ...[
                    _DetectedSourceRow(source: detected[i]),
                    if (i != detected.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 18),
          const HmSectionHeader(title: 'Preferred source by metric'),
          const SizedBox(height: 4),
          const Text(
            'Auto combines Health Connect data. Override only when you want a specific detected source for one metric.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          CommandCard(
            child: Column(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  _MetricSourcePicker(
                    metric: metrics[i],
                    selected: app.metricSources[metrics[i]] ?? 'Auto',
                    sources: detected,
                    onChanged: (value) async {
                      ref.read(appStateProvider.notifier).setMetricSource(metrics[i], value);
                      if (h.authorized) {
                        await ref.read(healthSyncProvider.notifier).sync();
                      }
                    },
                  ),
                  if (i != metrics.length - 1) const SizedBox(height: 9),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Healthy Me never marks a vendor connected just because it is supported. A vendor appears as detected only when real records identify that origin.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 9.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  static String friendlySource(String source) {
    final lower = source.toLowerCase();
    if (lower.contains('samsung')) return 'Samsung Health';
    if (lower.contains('garmin')) return 'Garmin Connect';
    if (lower.contains('fitbit')) return 'Fitbit';
    if (lower.contains('withings')) return 'Withings';
    if (lower.contains('google fit')) return 'Google Fit';
    if (lower.contains('health connect') ||
        lower.contains('com.google.android.apps.healthdata')) {
      return 'Health Connect';
    }
    return source;
  }

  static IconData sourceIcon(String source) {
    final value = source.toLowerCase();
    if (value.contains('samsung')) return Icons.directions_run_rounded;
    if (value.contains('garmin')) return Icons.navigation_rounded;
    if (value.contains('fitbit')) return Icons.watch_rounded;
    if (value.contains('withings')) return Icons.monitor_weight_outlined;
    return Icons.sensors_rounded;
  }

  static Color sourceColor(String source) {
    final value = source.toLowerCase();
    if (value.contains('samsung')) return AppTheme.mint;
    if (value.contains('garmin')) return AppTheme.textPrimary;
    if (value.contains('fitbit')) return AppTheme.cyan;
    if (value.contains('withings')) return AppTheme.blue;
    return AppTheme.purple;
  }
}

class _DetectedSourceRow extends StatelessWidget {
  final String source;

  const _DetectedSourceRow({required this.source});

  @override
  Widget build(BuildContext context) {
    final name = SourcesScreen.friendlySource(source);
    final color = SourcesScreen.sourceColor(name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          HmIconBadge(
            icon: SourcesScreen.sourceIcon(name),
            color: color,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const HmStatusPill(text: 'Detected', color: AppTheme.mint),
        ],
      ),
    );
  }
}

class _MetricSourcePicker extends StatelessWidget {
  final String metric;
  final String selected;
  final List<String> sources;
  final ValueChanged<String> onChanged;

  const _MetricSourcePicker({
    required this.metric,
    required this.selected,
    required this.sources,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = ['Auto', ...sources];
    final value = options.contains(selected) ? selected : 'Auto';
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: metric,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
      items: [
        const DropdownMenuItem(value: 'Auto', child: Text('Auto / Recommended')),
        for (final source in sources)
          DropdownMenuItem(
            value: source,
            child: Text(SourcesScreen.friendlySource(source)),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}
