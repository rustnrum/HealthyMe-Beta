import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../services/source_name_service.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';

class SourcesScreen extends ConsumerStatefulWidget {
  const SourcesScreen({super.key});

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  static const metrics = [
    'Steps',
    'Sleep',
    'Heart rate',
    'Resting heart rate',
    'HRV',
    'SpO2',
    'Respiratory rate',
    'Weight',
    'Body fat',
    'Body water',
    'Lean body mass',
    'Workouts',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = ref.read(appStateProvider);
      final sync = ref.read(healthSyncProvider);
      if (app.health.authorized && !sync.isLoading) {
        ref.read(healthSyncProvider.notifier).sync();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final sync = ref.watch(healthSyncProvider);
    final h = app.health;

    return Scaffold(
      appBar: AppBar(title: const Text('Data Sources')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          CommandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                                : 'Last refresh ${relativeAge(h.lastSync)}',
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
                const SizedBox(height: 12),
                const Text(
                  'Healthy Me rescans Health Connect when this page opens, when the app resumes, every few minutes while open, and when you tap Refresh. A device app still has to write its data into Health Connect first.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
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
                    icon: Icon(
                      h.authorized ? Icons.refresh_rounded : Icons.add_link_rounded,
                    ),
                    label: Text(h.authorized ? 'Refresh data' : 'Connect'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const HmSectionHeader(title: 'Data sources'),
          const SizedBox(height: 6),
          const Text(
            'One source per metric. Automatic uses the freshest provider that actually supplied that metric; Steps uses Health Connect’s aggregate result when Automatic is selected.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          CommandCard(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
            child: Column(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  _MetricSourceRow(
                    metric: metrics[i],
                    selectedRaw: app.metricSources[metrics[i]],
                    resolvedRaw: h.resolvedSources[metrics[i]],
                    sources: h.availableSources[metrics[i]] ?? const [],
                    sourceLabels: h.sourceLabels,
                    freshness: h.freshness[metrics[i]],
                    onChange: () => _chooseSource(
                      context,
                      ref,
                      metric: metrics[i],
                      selectedRaw: app.metricSources[metrics[i]],
                      sources: h.availableSources[metrics[i]] ?? const [],
                      sourceLabels: h.sourceLabels,
                      authorized: h.authorized,
                    ),
                  ),
                  if (i != metrics.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
          if (h.detectedSources.isNotEmpty) ...[
            const SizedBox(height: 24),
            const HmSectionHeader(title: 'Detected providers'),
            const SizedBox(height: 6),
            const Text(
              'Providers are identified by their Health Connect data origin. This is diagnostic information so you can see what is actually supplying data.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            CommandCard(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
              child: Column(
                children: [
                  for (var i = 0; i < h.detectedSources.length; i++) ...[
                    _ProviderRow(
                      sourceKey: h.detectedSources[i],
                      label: h.sourceLabels[h.detectedSources[i]] ??
                          SourceNameService.friendly(h.detectedSources[i]),
                      metrics: h.availableSources.entries
                          .where((entry) => entry.value.contains(h.detectedSources[i]))
                          .map((entry) => entry.key)
                          .toList(),
                      lastSeen: h.sourceLastSeen[h.detectedSources[i]],
                    ),
                    if (i != h.detectedSources.length - 1)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _chooseSource(
    BuildContext context,
    WidgetRef ref, {
    required String metric,
    required String? selectedRaw,
    required List<String> sources,
    required Map<String, String> sourceLabels,
    required bool authorized,
  }) async {
    final unique = SourceNameService.uniqueRawByFriendly(sources);
    final selected = selectedRaw == null ? 'Auto' : selectedRaw;
    final next = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$metric source',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Choose the data Healthy Me should use for this metric.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _SourceChoice(
                title: 'Automatic',
                subtitle: metric == 'Steps'
                    ? 'Use Health Connect’s aggregate step result'
                    : 'Use the freshest provider supplying this metric',
                selected: selected == 'Auto',
                onTap: () => Navigator.pop(context, 'Auto'),
              ),
              for (final source in unique)
                _SourceChoice(
                  title: sourceLabels[source] ?? SourceNameService.friendly(source),
                  subtitle: 'Use only this source for $metric',
                  selected: SourceNameService.sameProvider(selected, source),
                  onTap: () => Navigator.pop(context, source),
                ),
              if (unique.isEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'No additional source has supplied this metric yet.',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (next == null) return;
    ref.read(appStateProvider.notifier).setMetricSource(metric, next);
    if (authorized) {
      await ref.read(healthSyncProvider.notifier).sync();
    }
  }
}

class _MetricSourceRow extends StatelessWidget {
  final String metric;
  final String? selectedRaw;
  final String? resolvedRaw;
  final List<String> sources;
  final Map<String, String> sourceLabels;
  final DateTime? freshness;
  final VoidCallback onChange;

  const _MetricSourceRow({
    required this.metric,
    required this.selectedRaw,
    required this.resolvedRaw,
    required this.sources,
    required this.sourceLabels,
    required this.freshness,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = resolvedRaw == null
        ? null
        : (sourceLabels[resolvedRaw!] ?? SourceNameService.friendly(resolvedRaw!));
    final selectedLabel = selectedRaw == null
        ? null
        : (sourceLabels[selectedRaw!] ?? SourceNameService.friendly(selectedRaw!));
    final current = selectedRaw == null
        ? (resolvedLabel == null ? 'Automatic' : 'Automatic • $resolvedLabel')
        : (resolvedRaw != null &&
                !SourceNameService.sameProvider(selectedRaw!, resolvedRaw!))
            ? '$selectedLabel selected • using $resolvedLabel'
            : selectedLabel!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          HmIconBadge(
            icon: _icon(metric),
            color: _color(metric),
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  current,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (freshness != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Data ${relativeAge(freshness)}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onChange,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  IconData _icon(String metric) => switch (metric) {
        'Steps' => Icons.directions_walk_rounded,
        'Sleep' => Icons.bedtime_rounded,
        'Heart rate' => Icons.favorite_rounded,
        'Resting heart rate' => Icons.favorite_border_rounded,
        'HRV' => Icons.insights_rounded,
        'SpO2' => Icons.bloodtype_rounded,
        'Respiratory rate' => Icons.air_rounded,
        'Weight' => Icons.monitor_weight_outlined,
        'Body fat' => Icons.percent_rounded,
        'Body water' => Icons.water_drop_rounded,
        'Lean body mass' => Icons.fitness_center_rounded,
        'Workouts' => Icons.fitness_center_rounded,
        _ => Icons.sensors_rounded,
      };

  Color _color(String metric) => switch (metric) {
        'Steps' => AppTheme.cyan,
        'Sleep' => AppTheme.purple,
        'Heart rate' => AppTheme.rose,
        'Resting heart rate' => AppTheme.rose,
        'HRV' => AppTheme.purple,
        'SpO2' => AppTheme.blue,
        'Respiratory rate' => AppTheme.cyan,
        'Weight' => AppTheme.mint,
        'Body fat' => AppTheme.amber,
        'Body water' => AppTheme.blue,
        'Lean body mass' => AppTheme.mint,
        'Workouts' => AppTheme.blue,
        _ => AppTheme.cyan,
      };
}


class _ProviderRow extends StatelessWidget {
  final String sourceKey;
  final String label;
  final List<String> metrics;
  final DateTime? lastSeen;

  const _ProviderRow({
    required this.sourceKey,
    required this.label,
    required this.metrics,
    required this.lastSeen,
  });

  @override
  Widget build(BuildContext context) {
    final metricText = metrics.isEmpty ? 'No current metric records' : metrics.join(' • ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HmIconBadge(
            icon: Icons.sensors_rounded,
            color: AppTheme.cyan,
            size: 40,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  metricText,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.2,
                    height: 1.3,
                  ),
                ),
                if (lastSeen != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last record ${relativeAge(lastSeen)}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  sourceKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceChoice extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SourceChoice({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
        color: selected ? AppTheme.cyan : AppTheme.textMuted,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
