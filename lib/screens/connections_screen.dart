import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/debug_flags.dart';
import '../core/theme/app_theme.dart';
import '../services/ble_discovery_service.dart';
import '../services/device_category_service.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../services/notification_access_service.dart';
import '../services/source_hub_service.dart';
import '../services/source_name_service.dart';
import '../services/watch_notification_service.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen>
    with WidgetsBindingObserver {
  static const _sourceMetrics = <String>[
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

  final _ble = BleDiscoveryService();
  final _store = DirectDeviceStore();
  final _direct = DirectMetricService();
  final _notificationAccessService = NotificationAccessService();

  List<SavedDirectDevice> _saved = const [];
  List<BleDeviceCandidate> _nearby = const [];
  Map<String, double> _battery = const {};
  final Set<String> _syncing = {};
  final Set<String> _adding = {};
  bool _scanning = false;
  bool _notificationAccessEnabled = false;
  bool _checkingNotificationAccess = false;
  bool _showOther = false;
  String _filter = 'All';
  String? _scanMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSaved();
    _refreshNotificationAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationAccess();
    }
  }

  Future<void> _refreshNotificationAccess() async {
    if (_checkingNotificationAccess) return;
    setState(() => _checkingNotificationAccess = true);
    try {
      final enabled = await _notificationAccessService.isEnabled();
      if (!mounted) return;
      setState(() => _notificationAccessEnabled = enabled);
    } finally {
      if (mounted) {
        setState(() => _checkingNotificationAccess = false);
      }
    }
  }

  Future<void> _changeNotificationAccess(bool value) async {
    if (value == _notificationAccessEnabled) return;

    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enable device notifications?'),
          content: const Text(
            'Android notification access is optional. Enable it only if you want '
            'Salus to mirror supported phone alerts to a connected wearable.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      await _notificationAccessService.openSettings();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open notification access: $error')),
      );
    }
  }

  Future<void> _loadSaved() async {
    final devices = await _store.load();
    final samples = await _direct.loadSamples();

    final battery = <String, double>{};
    for (final sample in samples.where((item) => item.metric == 'Battery')) {
      battery[sample.deviceId] = sample.value;
    }

    if (!mounted) return;
    setState(() {
      _saved = devices;
      _battery = battery;
    });

    final app = ref.read(appStateProvider);
    final merged = _direct.mergeIntoSnapshot(
      app.health,
      metricSources: app.metricSources,
      samples: samples,
      registeredDevices: devices,
    );
    ref.read(appStateProvider.notifier).setHealthSnapshot(merged);
  }

  BleDeviceCandidate _candidate(SavedDirectDevice device) => BleDeviceCandidate(
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

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _scanMessage = null;
      _nearby = const [];
      _showOther = false;
    });

    try {
      final devices = await _ble.scan();
      final savedIds = _saved.map((item) => item.id).toSet();
      final nearby =
          devices.where((device) => !savedIds.contains(device.id)).take(40).toList();
      final recognized =
          nearby.where((device) => device.hasKnownCapabilities).length;

      if (!mounted) return;
      setState(() {
        _nearby = nearby;
        _scanMessage = nearby.isEmpty
            ? 'No Bluetooth devices found. Keep the device awake and nearby, then scan again.'
            : '$recognized health device${recognized == 1 ? '' : 's'} recognized • '
                '${nearby.length - recognized} other nearby';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _scanMessage = 'Could not scan: $error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _add(BleDeviceCandidate device) async {
    if (_adding.contains(device.id)) return;
    setState(() => _adding.add(device.id));

    try {
      final inspection = await _ble.inspect(device);
      final pair = await _ble.pair(device);
      await _store.save(
        device: device,
        inspection: inspection,
        pair: pair,
      );
      await _loadSaved();

      if (!mounted) return;
      setState(() {
        _nearby =
            _nearby.where((candidate) => candidate.id != device.id).toList();
      });

      final added = _saved.where((item) => item.id == device.id).toList();
      if (added.isNotEmpty) {
        await _syncSaved(added.first, showMessage: false);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${device.name} added to Salus.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add ${device.name}: $error')),
      );
    } finally {
      if (mounted) setState(() => _adding.remove(device.id));
    }
  }

  Future<void> _syncSaved(
    SavedDirectDevice device, {
    bool showMessage = true,
  }) async {
    if (_syncing.contains(device.id)) return;
    setState(() => _syncing.add(device.id));

    try {
      final result = await _direct.readAndStore(
        _candidate(device),
        protocolId: device.protocolId,
      );
      await _loadSaved();
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.summary)),
        );
      }
    } catch (error) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sync ${device.name}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing.remove(device.id));
    }
  }

  Future<void> _syncAll() async {
    for (final device
        in _saved.where((item) => item.protocolId != 'cpap-family')) {
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
    await WatchNotificationService().setMaster(
      deviceId: device.id,
      protocolId: device.protocolId ?? '',
      deviceName: device.name,
      enabled: false,
    );
    await _store.remove(device.id);
    await _loadSaved();
  }

  Future<void> _healthConnectAction() async {
    final app = ref.read(appStateProvider);
    if (app.health.authorized) {
      await ref.read(healthSyncProvider.notifier).sync();
    } else {
      await ref.read(healthSyncProvider.notifier).connectAndSync();
    }
  }

  Future<void> _chooseSource(String metric) async {
    final app = ref.read(appStateProvider);
    final sources = app.health.availableSources[metric] ?? const <String>[];

    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No source is available for $metric yet.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  metric,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Text('Use one source for this metric.'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('Automatic'),
                subtitle: const Text('Chooses one provider, never a blend.'),
                onTap: () => Navigator.pop(sheetContext, 'Auto'),
              ),
              for (final source in sources)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    source.startsWith('ble:')
                        ? Icons.bluetooth_rounded
                        : Icons.health_and_safety_outlined,
                  ),
                  title: Text(
                    app.health.sourceLabels[source] ??
                        SourceNameService.friendly(source),
                  ),
                  onTap: () => Navigator.pop(sheetContext, source),
                ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    ref.read(appStateProvider.notifier).setMetricSource(metric, selected);
    await _loadSaved();

    final current = ref.read(appStateProvider);
    if (current.health.authorized) {
      await ref.read(healthSyncProvider.notifier).sync();
    }
  }

  bool _matchesFilter({
    required String kind,
    required String? protocolId,
    required String name,
  }) {
    if (_filter == 'All') return true;
    return DeviceCategoryService.category(
          deviceKind: kind,
          protocolId: protocolId,
          name: name,
        ) ==
        _filter;
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final health = app.health;
    final sync = ref.watch(healthSyncProvider);
    final hcSources = SourceHubService.healthSources(health)
        .where((source) => source.transport == SourceTransport.healthConnect)
        .toList();

    final saved = _saved
        .where(
          (device) => _matchesFilter(
            kind: device.deviceKind,
            protocolId: device.protocolId,
            name: device.name,
          ),
        )
        .toList();

    final recognized = _nearby
        .where((device) => device.hasKnownCapabilities)
        .where(
          (device) => _matchesFilter(
            kind: device.deviceKind,
            protocolId: device.protocolId,
            name: device.name,
          ),
        )
        .toList();

    final other =
        _nearby.where((device) => !device.hasKnownCapabilities).toList();

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
          const _Hero(),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter
                    in const ['All', 'Watch', 'Ring', 'Scale', 'CPAP', 'Other'])
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _Section(
            title: 'Your devices',
            subtitle: 'Capabilities come from the device, not a brand list.',
          ),
          const SizedBox(height: 10),
          if (saved.isEmpty)
            const _Paper(
              child: Text(
                'No connected devices in this category yet.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else
            for (final device in saved) ...[
              _SavedCard(
                device: device,
                battery: _battery[device.id],
                syncing: _syncing.contains(device.id),
                onSync: () => _syncSaved(device),
                onRemove: () => _remove(device),
                onOpen: () {
                  if (device.protocolId == 'cpap-family') {
                    Navigator.of(context)
                        .pushNamed('/cpap', arguments: device.id);
                  } else if (DeviceCategoryService.category(
                        deviceKind: device.deviceKind,
                        protocolId: device.protocolId,
                        name: device.name,
                      ) ==
                      'Watch') {
                    Navigator.of(context)
                        .pushNamed('/watch-device', arguments: device.id);
                  }
                },
              ),
              const SizedBox(height: 9),
            ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(_scanning ? 'Scanning Bluetooth…' : 'Add device'),
          ),
          if (_scanMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _scanMessage!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ],
          if (recognized.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _Section(
              title: 'Recognized nearby',
              subtitle: 'Standard GATT and local compatibility packs.',
            ),
            const SizedBox(height: 8),
            for (final device in recognized) ...[
              _NearbyCard(
                device: device,
                adding: _adding.contains(device.id),
                onAdd: () => _add(device),
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (other.isNotEmpty) ...[
            const SizedBox(height: 6),
            ExpansionTile(
              initiallyExpanded: _showOther,
              onExpansionChanged: (value) =>
                  setState(() => _showOther = value),
              title: Text('Other nearby Bluetooth (${other.length})'),
              subtitle: const Text(
                'Open this only if the device you want was not recognized.',
              ),
              children: [
                for (final device in other)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NearbyCard(
                      device: device,
                      adding: _adding.contains(device.id),
                      onAdd: () => _add(device),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const _Section(
            title: 'Health Connect',
            subtitle: 'One additional source of health data, not a device hub.',
          ),
          const SizedBox(height: 9),
          _HealthConnectCard(
            authorized: health.authorized,
            providerCount: hcSources.length,
            syncing: sync.isLoading,
            onTap: _healthConnectAction,
          ),
          const SizedBox(height: 24),
          const _Section(
            title: 'Metric sources',
            subtitle: 'Each metric uses one source. Tap to change it.',
          ),
          const SizedBox(height: 9),
          _SourceCard(
            metrics: _sourceMetrics,
            selected: app.metricSources,
            resolved: health.resolvedSources,
            labels: health.sourceLabels,
            onTap: _chooseSource,
          ),
          const SizedBox(height: 24),
          const _Section(
            title: 'Device notifications',
            subtitle:
                'Optional. Only needed if you want supported wearables to mirror phone alerts.',
          ),
          const SizedBox(height: 9),
          _Paper(
            padding: EdgeInsets.zero,
            child: SwitchListTile.adaptive(
              value: _notificationAccessEnabled,
              onChanged:
                  _checkingNotificationAccess ? null : _changeNotificationAccess,
              title: const Text('Enable device notifications'),
              subtitle: Text(
                _notificationAccessEnabled
                    ? 'Android notification access is enabled.'
                    : 'Off by default. Tap to review Android notification access.',
              ),
              secondary: const Icon(Icons.notifications_active_outlined),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Compatibility built on Bluetooth standards and independent protocol research.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10.8,
            ),
          ),
          if (salusShowDeviceDebug) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/sources-debug'),
                icon: const Icon(Icons.bug_report_outlined, size: 17),
                label: const Text('Diagnostics'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return const _Paper(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bluetooth_searching_rounded, color: AppTheme.cyan, size: 34),
          SizedBox(width: 13),
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
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Salus scans capabilities first, then loads a bundled compatibility family only when the device needs one.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13.2,
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

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Section({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _SavedCard extends StatelessWidget {
  final SavedDirectDevice device;
  final double? battery;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  const _SavedCard({
    required this.device,
    required this.battery,
    required this.syncing,
    required this.onSync,
    required this.onRemove,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final category = DeviceCategoryService.category(
      deviceKind: device.deviceKind,
      protocolId: device.protocolId,
      name: device.name,
    );

    final capabilities = device.capabilities
        .where((item) => item != 'Raw motion' && item != 'Device information')
        .toList();

    return _Paper(
      onTap: onOpen,
      child: Row(
        children: [
          Icon(_icon(category), color: AppTheme.cyan, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    category,
                    if (battery != null) 'Battery ${battery!.round()}%',
                  ].join(' • '),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.2,
                  ),
                ),
                if (capabilities.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    capabilities.take(5).join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sync',
            onPressed: syncing ? null : onSync,
            icon: syncing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'remove') onRemove();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }

  IconData _icon(String category) => switch (category) {
        'Watch' => Icons.watch_outlined,
        'Ring' => Icons.circle_outlined,
        'Scale' => Icons.monitor_weight_outlined,
        'CPAP' => Icons.air_rounded,
        _ => Icons.sensors_rounded,
      };
}

class _NearbyCard extends StatelessWidget {
  final BleDeviceCandidate device;
  final bool adding;
  final VoidCallback onAdd;

  const _NearbyCard({
    required this.device,
    required this.adding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final category = DeviceCategoryService.category(
      deviceKind: device.deviceKind,
      protocolId: device.protocolId,
      name: device.name,
    );

    final subtitle = device.hasKnownCapabilities
        ? [
            category,
            if (device.capabilities.isNotEmpty)
              device.capabilities.take(4).join(' • '),
          ].join(' • ')
        : 'Needs identification';

    return _Paper(
      child: Row(
        children: [
          Icon(
            device.hasKnownCapabilities
                ? Icons.bluetooth_connected_rounded
                : Icons.bluetooth_rounded,
            color: device.hasKnownCapabilities
                ? AppTheme.cyan
                : AppTheme.textMuted,
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: adding ? null : onAdd,
            child: Text(adding ? 'Adding…' : 'Add'),
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
  final VoidCallback onTap;

  const _HealthConnectCard({
    required this.authorized,
    required this.providerCount,
    required this.syncing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Paper(
      onTap: syncing ? null : onTap,
      child: Row(
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: AppTheme.blue,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorized ? 'Connected' : 'Not connected',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  authorized
                      ? '$providerCount provider${providerCount == 1 ? '' : 's'} detected'
                      : 'Connect supported Android health apps.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.2,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final List<String> metrics;
  final Map<String, String> selected;
  final Map<String, String> resolved;
  final Map<String, String> labels;
  final Future<void> Function(String metric) onTap;

  const _SourceCard({
    required this.metrics,
    required this.selected,
    required this.resolved,
    required this.labels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Paper(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            ListTile(
              title: Text(metrics[i]),
              subtitle: Text(_source(metrics[i])),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onTap(metrics[i]),
            ),
            if (i != metrics.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  String _source(String metric) {
    final id = selected[metric] ?? resolved[metric];
    if (id == null) return 'No source yet';
    final label = labels[id] ?? SourceNameService.friendly(id);
    return selected[metric] == null ? 'Automatic • $label' : label;
  }
}

class _Paper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const _Paper({
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: content,
    );
  }
}
