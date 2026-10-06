import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/ble_discovery_service.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../services/source_hub_service.dart';
import '../services/source_name_service.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../widgets/command_card.dart';
import '../widgets/design_widgets.dart';
import '../widgets/salus_widgets.dart';

class SourcesScreen extends ConsumerStatefulWidget {
  const SourcesScreen({super.key});

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen> {
  static const metrics = [
    'Steps',
    'Sleep',
    'Sleep Stages',
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
  final _directDeviceStore = DirectDeviceStore();
  final _directMetricService = DirectMetricService();
  final Set<String> _readingDirect = {};
  final Map<String, String> _directReadSummary = {};
  List<BleDeviceCandidate> _bleDevices = const [];
  List<SavedDirectDevice> _savedDirectDevices = const [];
  final Map<String, BleDeviceInspection> _bleInspections = {};
  final Set<String> _inspecting = {};
  final Set<String> _pairing = {};
  bool _scanningBle = false;
  String? _bleError;

  @override
  void initState() {
    super.initState();
    _loadSavedDirectDevices();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = ref.read(appStateProvider);
      final sync = ref.read(healthSyncProvider);
      if (app.health.authorized && !sync.isLoading) {
        await ref.read(healthSyncProvider.notifier).sync();
      }
    });
  }

  Future<void> _loadSavedDirectDevices() async {
    final devices = await _directDeviceStore.load();
    if (!mounted) return;
    setState(() => _savedDirectDevices = devices);
  }

  Future<void> _useWithSalus(BleDeviceCandidate device) async {
    if (_pairing.contains(device.id)) return;
    setState(() => _pairing.add(device.id));

    try {
      final pair = await _bleDiscovery.pair(device);
      BleDeviceInspection? inspection = _bleInspections[device.id];
      try {
        final resolvedInspection =
            inspection ?? await _bleDiscovery.inspect(device);
        inspection = resolvedInspection;
        if (mounted) {
          setState(() => _bleInspections[device.id] = resolvedInspection);
        }
      } catch (_) {
        // Some devices expose services only after protocol-specific
        // authentication. Saving the device still lets Salus retry later.
      }

      await _directDeviceStore.save(
        device: device,
        inspection: inspection,
        pair: pair,
      );
      await _loadSavedDirectDevices();
      final directRead = await _readDirectMetrics(
        device,
        showSnackBar: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(directRead?.message ?? pair.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save ${device.name}: $error')),
      );
    } finally {
      if (mounted) setState(() => _pairing.remove(device.id));
    }
  }

  Future<void> _removeSavedDirectDevice(String id) async {
    await _directDeviceStore.remove(id);
    await _loadSavedDirectDevices();
  }

  Future<DirectMetricReadResult?> _readDirectMetrics(
    BleDeviceCandidate device, {
    bool showSnackBar = true,
  }) async {
    if (_readingDirect.contains(device.id)) return null;
    setState(() => _readingDirect.add(device.id));

    try {
      if (!_bleInspections.containsKey(device.id)) {
        try {
          final inspection = await _bleDiscovery.inspect(device);
          if (mounted) {
            setState(() => _bleInspections[device.id] = inspection);
          }
          if (_savedDirectDevices.any((saved) => saved.id == device.id)) {
            await _directDeviceStore.refreshInspection(
              device: device,
              inspection: inspection,
            );
            await _loadSavedDirectDevices();
          }
        } catch (_) {
          // The native reader independently identifies the full GATT service
          // family, so a UI inspection failure does not block the read.
        }
      }

      final result = await _directMetricService.readAndStore(device);
      final samples = await _directMetricService.loadSamples();
      final app = ref.read(appStateProvider);
      final merged = _directMetricService.mergeIntoSnapshot(
        app.health,
        metricSources: app.metricSources,
        samples: samples,
      );
      ref.read(appStateProvider.notifier).setHealthSnapshot(merged);

      if (!mounted) return result;
      setState(() => _directReadSummary[device.id] = result.summary);
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
      return result;
    } catch (error) {
      if (!mounted) return null;
      final message = 'Could not read ${device.name}: $error';
      setState(() => _directReadSummary[device.id] = message);
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _readingDirect.remove(device.id));
    }
  }

  // SALUS_BUILD29_AUTO_IDENTIFY
  bool _looksLikeHealthDevice(BleDeviceCandidate device) {
    if (device.hasKnownCapabilities) return true;
    if (_savedDirectDevices.any((saved) => saved.id == device.id)) return true;

    final name = device.name.trim().toLowerCase();
    if (name.isEmpty || name == 'unnamed ble device') return false;
    const hints = <String>[
      'garmin',
      'vivoactive',
      'vívoactive',
      'venu',
      'fenix',
      'forerunner',
      'instinct',
      'ring',
      'colmi',
      'qring',
      'watch',
      'band',
      'amazfit',
      'xiaomi',
      'zepp',
      'fitcloud',
      'dafit',
      'da fit',
      'scale',
      'weight',
      'oximeter',
      'spo2',
      'blood pressure',
      'glucose',
      'cpap',
      'bipap',
      'airsense',
      'aircurve',
      'dreamstation',
    ];
    return hints.any((hint) => name.contains(hint));
  }

  Future<void> _autoIdentifyScannedDevices(
    List<BleDeviceCandidate> devices,
  ) async {
    final likely = devices.where(_looksLikeHealthDevice).take(12).toList();
    for (final device in likely) {
      if (!mounted) return;
      if (_bleInspections.containsKey(device.id)) continue;
      setState(() => _inspecting.add(device.id));
      try {
        final inspection = await _bleDiscovery.inspect(device);
        if (!mounted) return;
        setState(() => _bleInspections[device.id] = inspection);
        if (_savedDirectDevices.any((saved) => saved.id == device.id)) {
          await _directDeviceStore.refreshInspection(
            device: device,
            inspection: inspection,
          );
          await _loadSavedDirectDevices();
        }
      } catch (_) {
        // Keep the scan result. A device that does not answer GATT inspection
        // is not promoted to a health device just because it was nearby.
      } finally {
        if (mounted) setState(() => _inspecting.remove(device.id));
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
      await _autoIdentifyScannedDevices(devices);
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
      if (_savedDirectDevices.any((saved) => saved.id == device.id)) {
        await _directDeviceStore.refreshInspection(
          device: device,
          inspection: inspection,
        );
        await _loadSavedDirectDevices();
      }
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
      appBar: AppBar(title: const Text('Devices & Sources')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          _buildIdentityCard(),
          // SALUS_BUILD25_DIRECT_FIRST — direct_device_patch compatibility: Use with Salus
          const SizedBox(height: 18),
          const HmSectionHeader(title: 'Direct devices'),
          const SizedBox(height: 6),
          const Text(
            'Put your ring, watch, scale or respiratory device in pairing mode, then scan. '
            'Salus will show the real Bluetooth devices it can see and let you connect them directly.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                SalusDeviceTypeCard(
                  asset: SalusAssets.deviceRing,
                  title: 'Ring',
                  subtitle: 'Sleep • HRV • SpO₂',
                  highlighted: true,
                ),
                SizedBox(width: 10),
                SalusDeviceTypeCard(
                  asset: SalusAssets.deviceWatch,
                  title: 'Watch',
                  subtitle: 'Activity • HR • Workouts',
                ),
                SizedBox(width: 10),
                SalusDeviceTypeCard(
                  asset: SalusAssets.deviceScale,
                  title: 'Scale',
                  subtitle: 'Weight • Body composition',
                ),
                SizedBox(width: 10),
                SalusDeviceTypeCard(
                  asset: SalusAssets.deviceCpap,
                  title: 'CPAP',
                  subtitle: 'Sleep • Therapy data',
                ),
              ],
            ),
          ),
          if (_savedDirectDevices.isNotEmpty) ...[
            const SizedBox(height: 12),
            _savedDirectDevicesCard(),
          ],
          const SizedBox(height: 12),
          _bluetoothCard(bluetoothSources),
          const SizedBox(height: 24),
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
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    return CommandCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      child: SizedBox(
        height: 150,
        child: Stack(
          children: [
            Positioned(
              right: -14,
              top: -24,
              width: 170,
              height: 170,
              child: Opacity(
                opacity: 0.88,
                child: Image.asset(
                  SalusAssets.sourcesOrbit,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const Positioned(
              left: 0,
              top: 5,
              child: Text(
                'CONNECT YOUR WORLD',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
            ),
            const Positioned(
              left: 0,
              top: 34,
              right: 115,
              child: Text(
                'Devices &\nSources',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 31,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.9,
                ),
              ),
            ),
            const Positioned(
              left: 0,
              bottom: 2,
              right: 105,
              child: Text(
                'Pair direct hardware or use Health Connect when it gives Salus the metric you need.',
                maxLines: 3,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
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

  Widget _savedDirectDevicesCard() {
    return CommandCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 8, 0, 3),
            child: Text(
              'Saved direct devices',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (var i = 0; i < _savedDirectDevices.length; i++) ...[
            _SavedDirectDeviceRow(
              device: _savedDirectDevices[i],
              onRemove: () => _removeSavedDirectDevice(
                _savedDirectDevices[i].id,
              ),
            ),
            if (i != _savedDirectDevices.length - 1)
              const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _bluetoothCard(List<HealthyDataSource> sources) {
    final healthSources = sources
        .where(SourceHubService.isBluetoothHealthCandidate)
        .toList();
    final otherSources = sources
        .where((source) => !SourceHubService.isBluetoothHealthCandidate(source))
        .toList();

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
                _scanningBle ? 'Scanning & identifying…' : 'Scan for devices',
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
          if (healthSources.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Health devices',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            for (final source in healthSources.take(20))
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
                saved: _savedDirectDevices.any(
                  (saved) => saved.id == source.id.replaceFirst('ble:', ''),
                ),
                pairing: _pairing.contains(
                  source.id.replaceFirst('ble:', ''),
                ),
                onUse: () => _useWithSalus(
                  _bleDevices.firstWhere(
                    (device) => source.id == 'ble:${device.id}',
                  ),
                ),
                reading: _readingDirect.contains(
                  source.id.replaceFirst('ble:', ''),
                ),
                readSummary: _directReadSummary[
                  source.id.replaceFirst('ble:', '')
                ],
                onRead: () => _readDirectMetrics(
                  _bleDevices.firstWhere(
                    (device) => source.id == 'ble:${device.id}',
                  ),
                ),
                healthCandidate: true,
              ),
          ],
          if (otherSources.isNotEmpty) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Other Bluetooth devices (${otherSources.length})',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'Nearby devices not identified as health hardware',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11.5,
                ),
              ),
              children: [
                for (final source in otherSources.take(20))
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
                    saved: _savedDirectDevices.any(
                      (saved) => saved.id == source.id.replaceFirst('ble:', ''),
                    ),
                    pairing: _pairing.contains(
                      source.id.replaceFirst('ble:', ''),
                    ),
                    onUse: () => _useWithSalus(
                      _bleDevices.firstWhere(
                        (device) => source.id == 'ble:${device.id}',
                      ),
                    ),
                    reading: _readingDirect.contains(
                      source.id.replaceFirst('ble:', ''),
                    ),
                    readSummary: _directReadSummary[
                      source.id.replaceFirst('ble:', '')
                    ],
                    onRead: () => _readDirectMetrics(
                      _bleDevices.firstWhere(
                        (device) => source.id == 'ble:${device.id}',
                      ),
                    ),
                    healthCandidate: false,
                  ),
              ],
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
                  maxLines: 3,
                  softWrap: true,
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
        'Sleep Stages' => Icons.bedtime_off_rounded,
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
        'Sleep Stages' => AppTheme.purple,
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
                  maxLines: 5,
                  softWrap: true,
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

class _SavedDirectDeviceRow extends StatelessWidget {
  final SavedDirectDevice device;
  final VoidCallback onRemove;

  const _SavedDirectDeviceRow({
    required this.device,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_deviceIcon(device.deviceKind), color: AppTheme.mint, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.deviceKind} • ${device.bonded ? 'Android paired' : 'Direct GATT saved'}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (device.protocolLabel != null)
                  Text(
                    device.protocolLabel!,
                    style: const TextStyle(
                      color: AppTheme.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (device.capabilities.isNotEmpty)
                  Text(
                    device.capabilities.join(' • '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onRemove, child: const Text('Remove')),
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
  final bool saved;
  final bool pairing;
  final bool reading;
  final String? readSummary;
  final VoidCallback onInspect;
  final VoidCallback onUse;
  final VoidCallback onRead;
  final bool healthCandidate;

  const _BleSourceRow({
    required this.source,
    required this.device,
    required this.inspection,
    required this.inspecting,
    required this.saved,
    required this.pairing,
    required this.reading,
    required this.readSummary,
    required this.onInspect,
    required this.onUse,
    required this.onRead,
    this.healthCandidate = true,
  });

  @override
  Widget build(BuildContext context) {
    final capabilities = source.metrics;
    final protocol = inspection?.protocolProfile ?? device.protocolProfile;
    final kind = inspection?.deviceKind ?? device.deviceKind;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: saved ? AppTheme.mint : AppTheme.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _deviceIcon(kind),
                  color: saved ? AppTheme.mint : AppTheme.blue,
                  size: 25,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.label,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        protocol == null ? kind : '$kind • $protocol',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        saved
                            ? 'Paired with Salus • ${device.bondState} • Read data to sync'
                            : !healthCandidate
                                ? 'Nearby Bluetooth device • not identified as health hardware'
                                : inspection == null
                                    ? 'Detected nearby • ${device.bondState}'
                                    : source.note ?? 'Health services identified',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (capabilities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Detected/potential: ${capabilities.join(' • ')}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.mint,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (readSummary != null) ...[
              const SizedBox(height: 7),
              Text(
                readSummary!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                OutlinedButton(
                  onPressed: inspecting ? null : onInspect,
                  child: Text(
                    inspecting
                        ? 'Identifying…'
                        : inspection == null
                            ? 'Identify'
                            : 'Identify again',
                  ),
                ),
                if (!saved && healthCandidate)
                  FilledButton.tonalIcon(
                    onPressed: pairing ? null : onUse,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: Text(pairing ? 'Pairing…' : 'Pair'),
                  )
                else if (saved)
                  FilledButton.tonalIcon(
                    onPressed: reading ? null : onRead,
                    icon: const Icon(Icons.sensors_rounded, size: 18),
                    label: Text(reading ? 'Reading…' : 'Read data'),
                  ),
              ],
            ),
            if (inspection != null)
              ExpansionTile(
                dense: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
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
                  _DiagnosticText('Device class', kind),
                  _DiagnosticText('Android bond', device.bondState),
                  _DiagnosticText('Signal', '${device.rssi} dBm'),
                  if (protocol != null)
                    _DiagnosticText('Protocol family', protocol),
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
      ),
    );
  }
}

IconData _deviceIcon(String kind) {
  final value = kind.toLowerCase();
  if (value.contains('ring')) return Icons.circle_outlined;
  if (value.contains('scale')) return Icons.monitor_weight_outlined;
  if (value.contains('cpap') || value.contains('respiratory')) return Icons.air_rounded;
  if (value.contains('watch') || value.contains('band')) return Icons.watch_outlined;
  if (value.contains('blood pressure')) return Icons.favorite_border_rounded;
  return Icons.bluetooth_rounded;
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
