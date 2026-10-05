import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../services/ble_discovery_service.dart';
import '../services/native_source_discovery_service.dart';
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
  static const _buildLabel = 'Beta 0.9.0+13 • Source Discovery';

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

  final _nativeDiscovery = NativeSourceDiscoveryService();
  final _bleDiscovery = BleDiscoveryService();

  HealthDiscoveryStatus? _discoveryStatus;
  List<BleDeviceCandidate> _bleDevices = const [];
  final Map<String, BleDeviceInspection> _bleInspections = {};
  final Set<String> _inspecting = {};

  bool _checkingDiscovery = false;
  bool _launchingMatchmaking = false;
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

      if (mounted) {
        await _refreshSystemDiscovery();
      }
    });
  }

  Future<void> _refreshSystemDiscovery() async {
    if (_checkingDiscovery) return;
    setState(() => _checkingDiscovery = true);

    try {
      final status = await _nativeDiscovery.status();
      if (!mounted) return;
      setState(() {
        _discoveryStatus = status;
      });
    } finally {
      if (mounted) {
        setState(() => _checkingDiscovery = false);
      }
    }
  }

  Future<void> _launchSystemMatchmaking() async {
    if (_launchingMatchmaking) return;
    setState(() => _launchingMatchmaking = true);

    try {
      await _nativeDiscovery.launchMatchmaking();
      if (!mounted) return;

      final app = ref.read(appStateProvider);
      if (app.health.authorized) {
        await ref.read(healthSyncProvider.notifier).sync();
      }

      if (mounted) {
        await _refreshSystemDiscovery();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Health Connect discovery: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _launchingMatchmaking = false);
      }
    }
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
      if (mounted) {
        setState(() => _scanningBle = false);
      }
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
        SnackBar(content: Text('Could not inspect ${device.name}: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _inspecting.remove(device.id));
      }
    }
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
          _buildIdentityCard(),
          const SizedBox(height: 12),
          _healthConnectCard(
            authorized: h.authorized,
            lastSync: h.lastSync,
            syncLoading: sync.isLoading,
          ),
          const SizedBox(height: 12),
          _systemDiscoveryCard(),
          const SizedBox(height: 12),
          _bluetoothDiscoveryCard(),
          const SizedBox(height: 24),
          const HmSectionHeader(title: 'Metric sources'),
          const SizedBox(height: 6),
          const Text(
            'These rows show providers that have actually supplied records. '
            'Automatic uses the freshest provider for each metric; Steps uses '
            'Health Connect aggregate data when Automatic is selected.',
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
            const HmSectionHeader(title: 'Record provider diagnostics'),
            const SizedBox(height: 6),
            const Text(
              'These are the data origins Healthy Me can prove have supplied '
              'readable Health Connect records.',
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
                          .where(
                            (entry) =>
                                entry.value.contains(h.detectedSources[i]),
                          )
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
                  'This build includes Health Connect matchmaking plus direct Bluetooth LE '
                  'scanning and GATT inspection.',
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

  Widget _healthConnectCard({
    required bool authorized,
    required DateTime? lastSync,
    required bool syncLoading,
  }) {
    return CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HmIconBadge(
                icon: Icons.health_and_safety_rounded,
                color: AppTheme.cyan,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Health Connect records',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastSync == null
                          ? 'No refresh yet'
                          : 'Last refresh ${relativeAge(lastSync)}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              HmStatusPill(
                text: authorized ? 'Connected' : 'Not connected',
                color: authorized ? AppTheme.mint : AppTheme.rose,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
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
                      if (mounted) {
                        await _refreshSystemDiscovery();
                      }
                    },
              icon: Icon(
                authorized ? Icons.refresh_rounded : Icons.add_link_rounded,
              ),
              label: Text(
                authorized ? 'Refresh Health Connect records' : 'Connect',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _systemDiscoveryCard() {
    final status = _discoveryStatus;

    String statusText() {
      if (_checkingDiscovery) return 'Checking Android source discovery…';
      if (status == null) return 'Not checked yet';
      if (!status.matchmakingSupported) {
        return 'Health Connect matchmaking is not available on this Android build';
      }
      if (status.matchmakingPossible) {
        return 'Compatible sources are available to connect';
      }
      return 'No unconnected Health Connect sources found right now';
    }

    return CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HmIconBadge(
                icon: Icons.travel_explore_rounded,
                color: AppTheme.purple,
                size: 44,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Android source discovery',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_checkingDiscovery)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            statusText(),
            style: TextStyle(
              color: status?.matchmakingPossible == true
                  ? AppTheme.mint
                  : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: 5),
            Text(
              'Health Connect U extension ${status.healthExtensionVersion} • '
              'matchmaking ${status.matchmakingSupported ? 'available' : 'not available'}',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
            if (status.message.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                status.message,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _checkingDiscovery ? null : _refreshSystemDiscovery,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Recheck'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: status?.matchmakingSupported == true &&
                          status?.matchmakingPossible == true &&
                          !_launchingMatchmaking
                      ? _launchSystemMatchmaking
                      : null,
                  icon: const Icon(Icons.add_link_rounded),
                  label: Text(
                    _launchingMatchmaking
                        ? 'Opening…'
                        : 'Find compatible sources',
                  ),
                ),
              ),
            ],
          ),
          if (status?.visibleApps.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            const Text(
              'Visible Health Connect apps',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            for (final app in status!.visibleApps)
              _SimpleDiagnosticLine(
                title: app.label,
                detail: app.packageName,
              ),
          ],
        ],
      ),
    );
  }

  Widget _bluetoothDiscoveryCard() {
    return CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              HmIconBadge(
                icon: Icons.bluetooth_searching_rounded,
                color: AppTheme.blue,
                size: 44,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nearby Bluetooth health devices',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Direct BLE discovery does not depend on Health Connect records.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _scanningBle ? null : _scanBluetooth,
              icon: const Icon(Icons.radar_rounded),
              label: Text(
                _scanningBle ? 'Scanning for 8 seconds…' : 'Scan nearby BLE',
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
          if (!_scanningBle && _bleDevices.isEmpty && _bleError == null) ...[
            const SizedBox(height: 10),
            const Text(
              'Start a scan while the ring or scale is awake. Scales often '
              'advertise only while a measurement is being taken.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (_bleDevices.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '${_bleDevices.length} nearby BLE device'
              '${_bleDevices.length == 1 ? '' : 's'} found',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final device in _bleDevices.take(20))
              _BleDeviceRow(
                device: device,
                inspection: _bleInspections[device.id],
                inspecting: _inspecting.contains(device.id),
                onInspect: () => _inspectBluetooth(device),
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
    required List<String> sources,
    required Map<String, String> sourceLabels,
    required bool authorized,
  }) async {
    final unique = SourceNameService.uniqueRawByFriendly(sources);
    final selected = selectedRaw ?? 'Auto';

    final next = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (sheetContext) => SafeArea(
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
                'Choose the provider Healthy Me should use for this metric.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _SourceChoice(
                title: 'Automatic',
                subtitle: metric == 'Steps'
                    ? 'Use Health Connect aggregate step data'
                    : 'Use the freshest provider supplying this metric',
                selected: selected == 'Auto',
                onTap: () => Navigator.pop(sheetContext, 'Auto'),
              ),
              for (final source in unique)
                _SourceChoice(
                  title: sourceLabels[source] ??
                      SourceNameService.friendly(source),
                  subtitle: 'Use only this source for $metric',
                  selected: SourceNameService.sameProvider(selected, source),
                  onTap: () => Navigator.pop(sheetContext, source),
                ),
              if (unique.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'No provider has supplied this metric yet. Use Android '
                    'source discovery or BLE scan above to find additional sources.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
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
        : (sourceLabels[resolvedRaw!] ??
            SourceNameService.friendly(resolvedRaw!));
    final selectedLabel = selectedRaw == null
        ? null
        : (sourceLabels[selectedRaw!] ??
            SourceNameService.friendly(selectedRaw!));

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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (freshness != null)
                  Text(
                    'Data ${relativeAge(freshness)}',
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

class _BleDeviceRow extends StatelessWidget {
  final BleDeviceCandidate device;
  final BleDeviceInspection? inspection;
  final bool inspecting;
  final VoidCallback onInspect;

  const _BleDeviceRow({
    required this.device,
    required this.inspection,
    required this.inspecting,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    final capabilities = inspection?.capabilities ?? device.capabilities;
    final profile = inspection?.protocolProfile ?? device.protocolProfile;
    final note = inspection?.protocolNote ?? device.protocolNote;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bluetooth_rounded,
                color: AppTheme.blue,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  device.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${device.rssi} dBm',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            device.id,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
          if (capabilities.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Capabilities: ${capabilities.join(' • ')}',
              style: const TextStyle(
                color: AppTheme.mint,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (profile != null) ...[
            const SizedBox(height: 4),
            Text(
              'Protocol profile: $profile',
              style: const TextStyle(
                color: AppTheme.amber,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (note != null && inspection != null) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (device.advertisedServices.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Advertised services: ${device.advertisedServices.join(', ')}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
          if (device.manufacturerDataHex.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Manufacturer data: ${device.manufacturerDataHex}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
          if (inspection != null) ...[
            const SizedBox(height: 6),
            Text(
              '${inspection!.services.length} GATT services discovered',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final service in inspection!.services.take(8))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${service.serviceUuid}\n'
                  '${service.characteristicDetails.join('\n')}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: inspecting ? null : onInspect,
              icon: inspecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.manage_search_rounded),
              label: Text(
                inspection == null ? 'Inspect GATT' : 'Inspect again',
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    return _SimpleDiagnosticLine(
      title: label,
      detail: [
        metrics.isEmpty ? 'No current metric records' : metrics.join(' • '),
        if (lastSeen != null) 'Last record ${relativeAge(lastSeen)}',
        sourceKey,
      ].join('\n'),
    );
  }
}

class _SimpleDiagnosticLine extends StatelessWidget {
  final String title;
  final String detail;

  const _SimpleDiagnosticLine({
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textMuted,
            size: 18,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      height: 1.3,
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
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? AppTheme.cyan : AppTheme.textMuted,
      ),
    );
  }
}
