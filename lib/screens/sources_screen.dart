import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/ble_discovery_service.dart';
import '../services/source_hub_service.dart';
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
  static const _buildLabel = 'Beta 0.13.0+17 • Salus Source Registry';

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

  final _bleDiscovery = BleDiscoveryService();
  List<BleDeviceCandidate> _bleDevices = const [];
  final Map<String, BleDeviceInspection> _bleInspections = {};
  final Set<String> _inspecting = {};
  bool _scanningBle = false;
  String? _bleError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = ref.read(appStateProvider);
      final sync = ref.read(healthSyncProvider);
      if (app.health.authorized && !sync.isLoading) {
        await ref.read(healthSyncProvider.notifier).sync();
      }
    });
  }

  Future<void> _scanBluetooth() async {
    if (_scanningBle) return;
    setState(() {
      _scanningBle = true;
      _bleError = null;
      _bleDevices = const [];
      _bleInspections.clear();
    });

    try {
      final devices = await _bleDiscovery.scan();
      if (!mounted) return;
      setState(() => _bleDevices = devices);
    } catch (error) {
      if (!mounted) return;
      setState(() => _bleError = error.toString());
    } finally {
      if (mounted) setState(() => _scanningBle = false);
    }
  }

  Future<void> _inspectBluetooth(BleDeviceCandidate device) async {
    if (_inspecting.contains(device.id)) return;
    setState(() => _inspecting.add(device.id));

    try {
      final inspection = await _bleDiscovery.inspect(device);
      if (!mounted) return;
      setState(() => _bleInspections[device.id] = inspection);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not identify ${device.name}: $error')),
      );
    } finally {
      if (mounted) setState(() => _inspecting.remove(device.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final sync = ref.watch(healthSyncProvider);
    final h = app.health;
    final providerSources = SourceHubService.healthSources(h);
    final bluetoothSources = SourceHubService.bluetoothSources(
      devices: _bleDevices,
      inspections: _bleInspections,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Data Sources')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          _buildIdentityCard(),
          const SizedBox(height: 12),
          _transportCard(
            authorized: h.authorized,
            lastSync: h.lastSync,
            syncLoading: sync.isLoading,
          ),
          const SizedBox(height: 22),
          const HmSectionHeader(title: 'Your data providers'),
          const SizedBox(height: 6),
          const Text(
            'Salus identifies the original provider and keeps Health Connect '
            'in the background as a transport.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          _providerHubCard(providerSources),
          const SizedBox(height: 22),
          const HmSectionHeader(title: 'Metric sources'),
          const SizedBox(height: 6),
          const Text(
            'Choose the provider Salus should use for each metric. Automatic '
            'uses the freshest provider that has actually supplied that metric.',
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
                    // Keep metric-specific availability explicit in this screen.
                    sources: h.availableSources[metrics[i]] ?? const [],
                    sourceLabels: h.sourceLabels,
                    freshness: h.freshness[metrics[i]],
                    onChange: () => _chooseSource(
                      context,
                      metric: metrics[i],
                      selectedRaw: app.metricSources[metrics[i]],
                      health: h,
                      authorized: h.authorized,
                    ),
                  ),
                  if (i != metrics.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const HmSectionHeader(title: 'Nearby devices'),
          const SizedBox(height: 6),
          const Text(
            'Bluetooth is used to identify devices and capabilities. A device is '
            'not selectable as a metric source until Salus can actually read '
            'that metric from it.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          _bluetoothCard(bluetoothSources),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    return CommandCard(
      child: const Row(
        children: [
          HmIconBadge(
            icon: Icons.hub_rounded,
            color: AppTheme.mint,
            size: 44,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _buildLabel,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'One source hub routes each metric by the actual provider, not '
                  'by the transport used to import it.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _transportCard({
    required bool authorized,
    required DateTime? lastSync,
    required bool syncLoading,
  }) {
    return CommandCard(
      child: Row(
        children: [
          const HmIconBadge(
            icon: Icons.sync_alt_rounded,
            color: AppTheme.cyan,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Health Connect import',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  lastSync == null
                      ? 'Transport only • no refresh yet'
                      : 'Transport only • refreshed ${relativeAge(lastSync)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: syncLoading
                ? null
                : () async {
                    if (authorized) {
                      await ref.read(healthSyncProvider.notifier).sync();
                    } else {
                      await ref
                          .read(healthSyncProvider.notifier)
                          .connectAndSync();
                    }
                  },
            child: Text(authorized ? 'Refresh' : 'Connect'),
          ),
        ],
      ),
    );
  }

  Widget _providerHubCard(List<HealthyDataSource> providers) {
    if (providers.isEmpty) {
      return const CommandCard(
        child: Text(
          'No provider records found yet. Refresh after your health apps have '
          'written data to Health Connect.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      );
    }

    return CommandCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < providers.length; i++) ...[
            _ProviderRow(source: providers[i]),
            if (i != providers.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _bluetoothCard(List<HealthyDataSource> sources) {
    return CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _scanningBle ? null : _scanBluetooth,
              icon: const Icon(Icons.bluetooth_searching_rounded),
              label: Text(
                _scanningBle ? 'Scanning for 8 seconds…' : 'Scan nearby devices',
              ),
            ),
          ),
          if (_bleError != null) ...[
            const SizedBox(height: 10),
            Text(
              _bleError!,
              style: const TextStyle(
                color: AppTheme.rose,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (!_scanningBle && sources.isEmpty && _bleError == null) ...[
            const SizedBox(height: 10),
            const Text(
              'Nothing scanned yet. Keep the device awake and nearby, then scan.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final source in sources.take(20))
              _BleSourceRow(
                source: source,
                device: _bleDevices.firstWhere(
                  (device) => source.id == 'ble:${device.id}',
                ),
                inspection: _bleInspections[
                  source.id.replaceFirst('ble:', '')
                ],
                inspecting: _inspecting.contains(
                  source.id.replaceFirst('ble:', ''),
                ),
                onInspect: () => _inspectBluetooth(
                  _bleDevices.firstWhere(
                    (device) => source.id == 'ble:${device.id}',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _chooseSource(
    BuildContext context, {
    required String metric,
    required String? selectedRaw,
    required HealthSnapshot health,
    required bool authorized,
  }) async {
    final choices = SourceHubService.healthChoicesForMetric(health, metric);
    final unavailable = SourceHubService.healthSourcesMissingMetric(
      health,
      metric,
    );
    final selected = selectedRaw ?? 'Auto';

    final next = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            shrinkWrap: true,
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
                'Salus routes this metric to the provider you choose.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _SourceChoice(
                title: 'Automatic',
                subtitle: 'Use the freshest provider with actual $metric data',
                selected: selected == 'Auto',
                onTap: () => Navigator.pop(sheetContext, 'Auto'),
              ),
              for (final source in choices)
                _SourceChoice(
                  title: source.label,
                  subtitle: '${source.transportLabel} • ${source.recordsFor(metric)} records • use only for $metric',
                  selected: SourceNameService.sameProvider(
                    selected,
                    source.id,
                  ),
                  onTap: () => Navigator.pop(sheetContext, source.id),
                ),
              if (choices.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'No provider has supplied this metric yet.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              if (unavailable.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Other detected providers',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                for (final source in unavailable)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.block_rounded,
                          size: 18,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${source.label} • no $metric records found',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (next == null || !mounted) return;
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
        : sourceLabels[resolvedRaw!] ?? SourceNameService.friendly(resolvedRaw!);
    final selectedLabel = selectedRaw == null
        ? null
        : sourceLabels[selectedRaw!] ?? SourceNameService.friendly(selectedRaw!);

    final String current;
    if (selectedRaw == null) {
      current = resolvedLabel == null
          ? 'Automatic • no data yet'
          : 'Automatic • $resolvedLabel';
    } else if (resolvedRaw == null) {
      current = '$selectedLabel • no current $metric data';
    } else {
      current = selectedLabel!;
    }

    final providerCount = SourceNameService.uniqueRawByFriendly(sources).length;

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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  freshness == null
                      ? '$providerCount provider${providerCount == 1 ? '' : 's'} available'
                      : 'Data ${relativeAge(freshness)} • $providerCount provider${providerCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
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
        'Workouts' => Icons.directions_run_rounded,
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
  final HealthyDataSource source;

  const _ProviderRow({required this.source});

  @override
  Widget build(BuildContext context) {
    final metrics = source.metrics.isEmpty
        ? 'No readable metrics yet'
        : source.metrics
            .map((metric) {
              final count = source.recordsFor(metric);
              return count > 0 ? '$metric ($count)' : metric;
            })
            .join(' • ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sensors_rounded, color: AppTheme.mint, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  source.transportLabel,
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metrics,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (source.lastSeen != null)
            Text(
              relativeAge(source.lastSeen!),
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _BleSourceRow extends StatelessWidget {
  final HealthyDataSource source;
  final BleDeviceCandidate device;
  final BleDeviceInspection? inspection;
  final bool inspecting;
  final VoidCallback onInspect;

  const _BleSourceRow({
    required this.source,
    required this.device,
    required this.inspection,
    required this.inspecting,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    final capabilities = source.metrics;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.bluetooth_rounded, color: AppTheme.blue),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.label,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (source.secondaryLabel != null)
                        Text(
                          source.secondaryLabel!,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        inspection == null
                            ? 'Detected nearby'
                            : source.note ?? 'Bluetooth services identified',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: inspecting ? null : onInspect,
                  child: Text(
                    inspecting
                        ? 'Identifying…'
                        : inspection == null
                            ? 'Identify'
                            : 'Identify again',
                  ),
                ),
              ],
            ),
          ),
          if (capabilities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  capabilities.join(' • '),
                  style: const TextStyle(
                    color: AppTheme.mint,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (inspection != null)
            ExpansionTile(
              dense: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: const Text(
                'Advanced diagnostics',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              children: [
                _DiagnosticText('Address', device.id),
                _DiagnosticText('Signal', '${device.rssi} dBm'),
                if (device.advertisedServices.isNotEmpty)
                  _DiagnosticText(
                    'Advertised services',
                    device.advertisedServices.join(', '),
                  ),
                if (device.manufacturerDataHex.isNotEmpty)
                  _DiagnosticText(
                    'Manufacturer bytes',
                    device.manufacturerDataHex,
                  ),
                for (final service in inspection!.services)
                  _DiagnosticText(
                    service.serviceUuid,
                    service.characteristicDetails.join('\n'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DiagnosticText extends StatelessWidget {
  final String label;
  final String value;

  const _DiagnosticText(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$label\n$value',
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
            height: 1.3,
          ),
        ),
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
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppTheme.cyan : AppTheme.textMuted,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w900,
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
