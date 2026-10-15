import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/source_name_service.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';

/// User-facing import and provider preferences. No hardware pairing.
class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});
  static const metrics = [
    'Steps','Sleep','Sleep Stages','Heart rate','Resting heart rate',
    'HRV','Respiratory rate','SpO2','Active calories','Distance',
    'Weight','Body fat','Workouts',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    final health = app.health;
    final sync = ref.watch(healthSyncProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Health Connect & Sources')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 36), children: [
        const Text('Salus reads your health measurements through Android Health Connect. '
          'Each record keeps the original provider, so data from different apps is not silently mixed.',
          style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(health.authorized ? 'Health Connect connected' : 'Health Connect not connected',
            style: const TextStyle(fontWeight: FontWeight.w800)),
          if (health.lastSync != null) Padding(padding: const EdgeInsets.only(top: 7),
            child: Text('Last sync: ${health.lastSync!.toLocal()}',
              style: const TextStyle(color: AppTheme.textSecondary))),
          if (health.error != null) Text(health.error!, style: const TextStyle(color: AppTheme.amber)),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: sync.isLoading ? null : () async {
              if (health.authorized) {
                await ref.read(healthSyncProvider.notifier).sync();
              } else {
                await ref.read(healthSyncProvider.notifier).connectAndSync();
              }
            },
            icon: const Icon(Icons.sync),
            label: Text(sync.isLoading ? 'Syncing…' : health.authorized ? 'Sync Health Connect' : 'Connect Health Connect'),
          ),
        ]))),
        const SizedBox(height: 18),
        const Text('Data source by metric', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Automatic uses available Health Connect records. Choose a provider to restrict a metric to that origin.',
          style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 10),
        for (final metric in metrics) Card(child: ListTile(
          dense: true,
          title: Text(metric),
          subtitle: Text(_selectionLabel(app.metricSources[metric], health.sourceLabels)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _choose(context, ref, metric,
            (health.availableSources[metric] ?? const <String>[])
              .where((id) => id.isNotEmpty && !id.startsWith('ble:') &&
                !SourceNameService.isTransportOnly(id)).toSet().toList(),
            health.sourceLabels, app.metricSources[metric]),
        )),
      ]),
    );
  }

  String _selectionLabel(String? selected, Map<String,String> labels) {
    if (selected == null || selected == 'Auto' || selected.startsWith('ble:')) return 'Automatic';
    return labels[selected] ?? SourceNameService.friendly(selected);
  }

  void _choose(BuildContext context, WidgetRef ref, String metric,
      List<String> sources, Map<String,String> labels, String? selected) {
    showModalBottomSheet<void>(context: context,
      builder: (sheet) => SafeArea(child: ListView(shrinkWrap: true, children: [
        ListTile(title: Text('$metric provider', style: const TextStyle(fontWeight: FontWeight.w800))),
        ListTile(title: const Text('Automatic'),
          trailing: (selected == null || selected == 'Auto') ? const Icon(Icons.check) : null,
          onTap: () { ref.read(appStateProvider.notifier).setMetricSource(metric, 'Auto');
            Navigator.pop(sheet); ref.read(healthSyncProvider.notifier).sync(); }),
        for (final source in sources) ListTile(
          title: Text(labels[source] ?? SourceNameService.friendly(source)),
          subtitle: Text(source, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: selected == source ? const Icon(Icons.check) : null,
          onTap: () { ref.read(appStateProvider.notifier).setMetricSource(metric, source);
            Navigator.pop(sheet); ref.read(healthSyncProvider.notifier).sync(); }),
        if (sources.isEmpty) const ListTile(title: Text('No providers have supplied this metric yet.')),
      ])),
    );
  }
}
