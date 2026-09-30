import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../services/source_name_service.dart';
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
    final detected = SourceNameService.uniqueRawByFriendly(h.detectedSources)
        .where((source) => SourceNameService.friendly(source) != 'Health Connect')
        .toList()
      ..sort((a, b) => SourceNameService.friendly(a)
          .compareTo(SourceNameService.friendly(b)));

    return Scaffold(
      appBar: AppBar(title: const Text('Devices & Sources')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
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
                      size: 48,
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
                                    color: AppTheme.textPrimary,
                                    fontSize: 17,
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
                          const SizedBox(height: 5),
                          Text(
                            h.lastSync == null
                                ? 'Android health-data hub'
                                : 'Last sync ${relativeAge(h.lastSync)}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
                        icon: Icon(h.authorized
                            ? Icons.sync_rounded
                            : Icons.add_link_rounded),
                        label: Text(h.authorized ? 'Sync now' : 'Connect'),
                      ),
                    ),
                    if (h.authorized) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: sync.isLoading
                              ? null
                              : () => ref
                                  .read(healthSyncProvider.notifier)
                                  .disconnect(),
                          child: const Text('Disconnect'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const HmSectionHeader(title: 'Detected data origins'),
          const SizedBox(height: 10),
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
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
              child: Column(
                children: [
                  for (var i = 0; i < detected.length; i++) ...[
                    _DetectedSourceRow(source: detected[i]),
                    if (i != detected.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),
          const HmSectionHeader(title: 'Preferred source by metric'),
          const SizedBox(height: 6),
          const Text(
            'Auto combines Health Connect data. Override only when you want a specific detected source for one metric.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          CommandCard(
            child: Column(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  _MetricSourcePicker(
                    metric: metrics[i],
                    selected: app.metricSources[metrics[i]] ?? 'Auto',
                    sources: detected,
                    onChanged: (value) async {
                      ref
                          .read(appStateProvider.notifier)
                          .setMetricSource(metrics[i], value);
                      if (h.authorized) {
                        await ref.read(healthSyncProvider.notifier).sync();
                      }
                    },
                  ),
                  if (i != metrics.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'A vendor appears as detected only when real Health Connect records identify that origin. Package IDs are kept internal and are never shown as provider names.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static IconData sourceIcon(String source) {
    final value = source.toLowerCase();
    if (value.contains('samsung')) return Icons.directions_run_rounded;
    if (value.contains('garmin')) return Icons.navigation_rounded;
    if (value.contains('fitbit')) return Icons.watch_rounded;
    if (value.contains('withings')) return Icons.monitor_weight_outlined;
    if (value.contains('google fit')) return Icons.fitness_center_rounded;
    return Icons.sensors_rounded;
  }

  static Color sourceColor(String source) {
    final value = source.toLowerCase();
    if (value.contains('samsung')) return AppTheme.mint;
    if (value.contains('garmin')) return AppTheme.textPrimary;
    if (value.contains('fitbit')) return AppTheme.cyan;
    if (value.contains('withings')) return AppTheme.blue;
    if (value.contains('google fit')) return AppTheme.mint;
    return AppTheme.purple;
  }
}

class _DetectedSourceRow extends StatelessWidget {
  final String source;

  const _DetectedSourceRow({required this.source});

  @override
  Widget build(BuildContext context) {
    final name = SourceNameService.friendly(source);
    final color = SourcesScreen.sourceColor(name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          HmIconBadge(
            icon: SourcesScreen.sourceIcon(name),
            color: color,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
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

    Widget labelFor(String option) => Text(
          option == 'Auto'
              ? 'Auto / Recommended'
              : SourceNameService.friendly(option),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        );

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: metric,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      selectedItemBuilder: (context) => [
        for (final option in options)
          Align(
            alignment: Alignment.centerLeft,
            child: labelFor(option),
          ),
      ],
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: labelFor(option),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}
