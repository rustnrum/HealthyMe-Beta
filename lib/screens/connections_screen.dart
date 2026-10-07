import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/ble_discovery_service.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../services/source_hub_service.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';

const bool _showDeviceDebugTools = bool.fromEnvironment(
  'SALUS_SHOW_DEVICE_DEBUG',
  defaultValue: true,
);

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  final _ble = BleDiscoveryService();
  final _store = DirectDeviceStore();
  final _direct = DirectMetricService();

  List<SavedDirectDevice> _saved = const [];
  List<_DiscoveredHealthDevice> _discovered = const [];
  final Set<String> _syncing = {};
  final Set<String> _connecting = {};
  bool _scanning = false;
  String? _scanMessage;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final values = await _store.load();
    if (!mounted) return;
    setState(() => _saved = values);
  }

  BleDeviceCandidate _candidateFromSaved(SavedDirectDevice device) {
    return BleDeviceCandidate(
      id: device.id,
      name: device.name,
      rssi: -127,
      advertisedServices: const [],
      capabilities: device.capabilities,
      protocolProfile: device.protocolLabel,
      protocolId: device.protocolId,
      protocolNote: null,
      deviceKind: device.deviceKind,
      manufacturerDataHex: '',
      bondState: device.bonded ? 'bonded' : device.pairState,
    );
  }

  bool _looksLikeHealthDevice(BleDeviceCandidate device) {
    if (device.hasKnownCapabilities) return true;
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
    return hints.any(name.contains);
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _scanMessage = null;
      _discovered = const [];
    });

    try {
      final devices = await _ble.scan();
      final found = <_DiscoveredHealthDevice>[];

      for (final device in devices.where(_looksLikeHealthDevice).take(10)) {
        if (_saved.any((saved) => saved.id == device.id)) continue;

        BleDeviceInspection? inspection;
        try {
          inspection = await _ble.inspect(device);
        } catch (_) {
          // Keep the advertisement-level identity. We only surface the result
          // if the source classifier still recognizes it as health hardware.
        }

        final source = SourceHubService.bluetoothSources(
          devices: [device],
          inspections: inspection == null
              ? const {}
              : <String, BleDeviceInspection>{device.id: inspection},
        ).single;

        if (SourceHubService.isBluetoothHealthCandidate(source)) {
          found.add(
            _DiscoveredHealthDevice(
              device: device,
              inspection: inspection,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _discovered = found;
        _scanMessage = found.isEmpty
            ? 'No compatible health devices found. Keep the device awake and nearby, then scan again.'
            : '${found.length} compatible device${found.length == 1 ? '' : 's'} found.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _scanMessage = 'Could not scan: $error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(_DiscoveredHealthDevice item) async {
    final device = item.device;
    if (_connecting.contains(device.id)) return;
    setState(() => _connecting.add(device.id));

    try {
      final pair = await _ble.pair(device);
      BleDeviceInspection? inspection = item.inspection;
      try {
        inspection ??= await _ble.inspect(device);
      } catch (_) {
        // Some direct protocols can still be read by the native driver even
        // when a one-off GATT inspection is unavailable.
      }

      await _store.save(
        device: device,
        inspection: inspection,
        pair: pair,
      );
      await _loadSaved();

      if (!mounted) return;
      setState(() {
        _discovered = _discovered
            .where((candidate) => candidate.device.id != device.id)
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${device.name} added to Salus.')),
      );

      await _syncSaved(
        _saved.firstWhere((saved) => saved.id == device.id),
        showMessage: false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add ${device.name}: $error')),
      );
    } finally {
      if (mounted) setState(() => _connecting.remove(device.id));
    }
  }

  Future<void> _syncSaved(
    SavedDirectDevice saved, {
    bool showMessage = true,
  }) async {
    if (_syncing.contains(saved.id)) return;
    setState(() => _syncing.add(saved.id));

    try {
      final result = await _direct.readAndStore(
        _candidateFromSaved(saved),
      );
      final samples = await _direct.loadSamples();
      final app = ref.read(appStateProvider);
      final merged = _direct.mergeIntoSnapshot(
        app.health,
        metricSources: app.metricSources,
        samples: samples,
      );
      ref.read(appStateProvider.notifier).setHealthSnapshot(merged);

      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.summary)),
        );
      }
    } catch (error) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sync ${saved.name}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing.remove(saved.id));
    }
  }

  Future<void> _syncAll() async {
    for (final device in _saved) {
      await _syncSaved(device, showMessage: false);
    }
    final app = ref.read(appStateProvider);
    if (app.health.authorized) {
      await ref.read(healthSyncProvider.notifier).sync();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connections synced.')),
    );
  }

  Future<void> _remove(SavedDirectDevice device) async {
    await _store.remove(device.id);
    await _loadSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${device.name} removed from Salus.')),
    );
  }

  Future<void> _healthConnectAction() async {
    final app = ref.read(appStateProvider);
    if (app.health.authorized) {
      await ref.read(healthSyncProvider.notifier).sync();
    } else {
      await ref.read(healthSyncProvider.notifier).connectAndSync();
    }
  }

  List<String> _displayMetrics(List<String> values) {
    const hidden = {'Raw motion', 'Battery', 'Device information'};
    final unique = values.where((value) => !hidden.contains(value)).toSet().toList()
      ..sort();
    return unique;
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final sync = ref.watch(healthSyncProvider);
    final health = app.health;
    final healthConnectSources = SourceHubService.healthSources(health)
        .where((source) => source.transport == SourceTransport.healthConnect)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        actions: [
          IconButton(
            tooltip: 'Sync all',
            onPressed: _saved.isEmpty && !health.authorized ? null : _syncAll,
            icon: const Icon(Icons.sync_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
        children: [
          const _ConnectionsHero(),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Your devices',
            subtitle: _saved.isEmpty
                ? 'Add a watch, ring, scale or health sensor.'
                : 'Salus handles the data routing automatically.',
          ),
          const SizedBox(height: 10),
          if (_saved.isEmpty)
            const _EmptyDeviceCard()
          else
            for (final device in _saved) ...[
              _SavedDeviceCard(
                device: device,
                lastSeen: health.sourceLastSeen['ble:${device.id}'],
                syncing: _syncing.contains(device.id),
                metrics: _displayMetrics(device.capabilities),
                onSync: () => _syncSaved(device),
                onRemove: () => _remove(device),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(
              _scanning ? 'Finding health devices…' : 'Add a device',
            ),
          ),
          if (_scanMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _scanMessage!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (_discovered.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final item in _discovered) ...[
              _DiscoveredDeviceCard(
                item: item,
                connecting: _connecting.contains(item.device.id),
                onConnect: () => _connect(item),
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 22),
          const _SectionHeader(
            title: 'Health Connect',
            subtitle:
                'Lets supported health apps share data with Salus. No metric-by-metric setup is required.',
          ),
          const SizedBox(height: 10),
          _HealthConnectCard(
            authorized: health.authorized,
            providerCount: healthConnectSources.length,
            syncing: sync.isLoading,
            lastSync: health.lastSync,
            onAction: _healthConnectAction,
          ),
          if (_showDeviceDebugTools) ...[
            const SizedBox(height: 26),
            Divider(color: AppTheme.border.withValues(alpha: 0.65)),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/sources-debug'),
                icon: const Icon(Icons.bug_report_outlined, size: 18),
                label: const Text('Open device debug'),
              ),
            ),
            const Center(
              child: Text(
                'Development only • hidden in release builds',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionsHero extends StatelessWidget {
  const _ConnectionsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 19, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceHigh.withValues(alpha: 0.96),
            AppTheme.surface.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyan.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroIcon(),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected health',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Connect it once. Salus figures out where your health data comes from.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
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

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.cyan.withValues(alpha: 0.10),
        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.28)),
      ),
      child: const Icon(
        Icons.hub_rounded,
        color: AppTheme.cyan,
        size: 25,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12.8,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _EmptyDeviceCard extends StatelessWidget {
  const _EmptyDeviceCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.blue.withValues(alpha: 0.10),
            ),
            child: const Icon(
              Icons.watch_outlined,
              color: AppTheme.blue,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No direct devices connected yet.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedDeviceCard extends StatelessWidget {
  final SavedDirectDevice device;
  final DateTime? lastSeen;
  final bool syncing;
  final List<String> metrics;
  final VoidCallback onSync;
  final VoidCallback onRemove;

  const _SavedDeviceCard({
    required this.device,
    required this.lastSeen,
    required this.syncing,
    required this.metrics,
    required this.onSync,
    required this.onRemove,
  });

  String _status(DateTime? value) {
    if (value == null) return 'Connected • waiting for data';
    final delta = DateTime.now().difference(value);
    if (delta.inMinutes < 1) return 'Connected • updated just now';
    if (delta.inMinutes < 60) return 'Connected • updated ${delta.inMinutes}m ago';
    if (delta.inHours < 24) return 'Connected • updated ${delta.inHours}h ago';
    return 'Connected • updated ${delta.inDays}d ago';
  }

  IconData _icon(String kind) {
    final value = kind.toLowerCase();
    if (value.contains('ring')) return Icons.circle_outlined;
    if (value.contains('scale')) return Icons.monitor_weight_outlined;
    if (value.contains('cpap') || value.contains('respiratory')) {
      return Icons.air_rounded;
    }
    if (value.contains('watch') || value.contains('band')) {
      return Icons.watch_outlined;
    }
    return Icons.sensors_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final therapyPending = device.protocolId == 'cpap-family';
    final displayMetrics = therapyPending
        ? const [
            'Usage time',
            'AHI',
            'Leak rate',
            'Therapy pressure',
            'Mask on/off',
          ]
        : metrics;
    final visible = displayMetrics.take(5).toList();
    final remaining = displayMetrics.length - visible.length;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.mint.withValues(alpha: 0.10),
                  border: Border.all(
                    color: AppTheme.mint.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  _icon(device.deviceKind),
                  color: AppTheme.mint,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.deviceKind} • Salus Direct',
                      style: const TextStyle(
                        color: AppTheme.cyan,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      therapyPending
                          ? 'Connected • CPAP therapy sync pending'
                          : _status(lastSeen),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.2,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Device options',
                onSelected: (value) {
                  if (value == 'remove') onRemove();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove from Salus'),
                  ),
                ],
              ),
            ],
          ),
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 13),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final metric in visible)
                  _MetricChip(label: metric),
                if (remaining > 0)
                  _MetricChip(label: '+$remaining more'),
              ],
            ),
          ],
          if (therapyPending) ...[
            const SizedBox(height: 10),
            const Text(
              'Salus recognizes this as a CPAP. It will not use the wearable heart-rate reader for this device.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.2,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: therapyPending || syncing ? null : onSync,
              icon: therapyPending
                  ? const Icon(Icons.air_rounded, size: 18)
                  : syncing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                therapyPending
                    ? 'Therapy sync pending'
                    : syncing
                        ? 'Syncing…'
                        : 'Sync now',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;

  const _MetricChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cyan.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.cyan.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DiscoveredHealthDevice {
  final BleDeviceCandidate device;
  final BleDeviceInspection? inspection;

  const _DiscoveredHealthDevice({
    required this.device,
    required this.inspection,
  });
}

class _DiscoveredDeviceCard extends StatelessWidget {
  final _DiscoveredHealthDevice item;
  final bool connecting;
  final VoidCallback onConnect;

  const _DiscoveredDeviceCard({
    required this.item,
    required this.connecting,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final device = item.device;
    final inspection = item.inspection;
    final kind = inspection?.deviceKind ?? device.deviceKind;
    final metrics = <String>{
      ...(inspection?.capabilities ?? device.capabilities),
    }.where((metric) => metric != 'Raw motion').take(5).toList();

    return _GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.bluetooth_searching_rounded,
            color: AppTheme.blue,
            size: 25,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kind,
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (metrics.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    metrics.join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.8,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonal(
            onPressed: connecting ? null : onConnect,
            child: Text(connecting ? 'Adding…' : 'Add'),
          ),
        ],
      ),
    );
  }
}

class _HealthConnectCard extends StatelessWidget {
  final bool authorized;
  final int providerCount;
  final bool syncing;
  final DateTime? lastSync;
  final VoidCallback onAction;

  const _HealthConnectCard({
    required this.authorized,
    required this.providerCount,
    required this.syncing,
    required this.lastSync,
    required this.onAction,
  });

  String _status() {
    if (!authorized) return 'Not connected';
    if (providerCount == 0) return 'Connected • waiting for data';
    return 'Connected • $providerCount data source${providerCount == 1 ? '' : 's'}';
  }

  String _lastSyncText() {
    if (lastSync == null) return 'No sync yet';
    final delta = DateTime.now().difference(lastSync!);
    if (delta.inMinutes < 1) return 'Last sync just now';
    if (delta.inMinutes < 60) return 'Last sync ${delta.inMinutes}m ago';
    if (delta.inHours < 24) return 'Last sync ${delta.inHours}h ago';
    return 'Last sync ${delta.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.blue.withValues(alpha: 0.10),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: AppTheme.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Health Connect',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _status(),
                      style: TextStyle(
                        color: authorized ? AppTheme.mint : AppTheme.textSecondary,
                        fontSize: 12.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _lastSyncText(),
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: syncing ? null : onAction,
              icon: syncing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      authorized
                          ? Icons.sync_rounded
                          : Icons.link_rounded,
                      size: 18,
                    ),
              label: Text(
                syncing
                    ? 'Working…'
                    : authorized
                        ? 'Sync Health Connect'
                        : 'Connect Health Connect',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.88),
        ),
      ),
      child: child,
    );
  }
}
