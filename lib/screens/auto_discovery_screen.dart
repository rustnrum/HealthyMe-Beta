import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/ble_discovery_service.dart';
import '../services/ble_protocol_profiles.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../services/local_device_driver.dart';
import '../state/app_state.dart';
import '../widgets/salus_widgets.dart';

/// Manufacturer-independent discovery. Scanning and GATT inspection are read
/// only; registering/pairing a newly discovered device is user initiated.
/// Scans when opened and when returning from Android settings (if stale).
class AutoDiscoveryScreen extends ConsumerStatefulWidget {
  const AutoDiscoveryScreen({super.key});

  @override
  ConsumerState<AutoDiscoveryScreen> createState() => _AutoDiscoveryScreenState();
}

class _ProbedDevice {
  final BleDeviceCandidate candidate;
  final BleDeviceInspection? inspection;
  final String? probeError;
  final bool inspecting;

  const _ProbedDevice({
    required this.candidate,
    this.inspection,
    this.probeError,
    this.inspecting = false,
  });

  _ProbedDevice inspected(BleDeviceInspection? result, String? error) =>
      _ProbedDevice(candidate: candidate, inspection: result, probeError: error);
}

class _AutoDiscoveryScreenState extends ConsumerState<AutoDiscoveryScreen>
    with WidgetsBindingObserver {
  final BleDiscoveryService _ble = BleDiscoveryService();
  final DirectDeviceStore _store = DirectDeviceStore();
  final DirectMetricService _metrics = DirectMetricService();
  final Map<String, _ProbedDevice> _found = {};
  final Set<String> _adding = {};
  final Set<String> _reading = {};
  List<SavedDirectDevice> _saved = const [];
  bool _scanning = false;
  bool _probing = false;
  String? _message;
  DateTime? _lastScan;
  int _session = 0;
  int _inspectedCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshSaved();
      _discover();
    });
  }

  @override
  void dispose() {
    _session++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _scanning || _probing) return;
    _refreshSaved();
    if (_lastScan == null ||
        DateTime.now().difference(_lastScan!) > const Duration(minutes: 2)) {
      _discover();
    }
  }

  Future<void> _refreshSaved() async {
    final devices = await _store.load();
    if (mounted) setState(() => _saved = devices);
  }

  Future<void> _discover() async {
    if (_scanning || _probing) return;
    final session = ++_session;
    setState(() {
      _scanning = true;
      _probing = false;
      _inspectedCount = 0;
      _message = null;
      _found.clear();
    });
    try {
      // No UUID or manufacturer filter: unknown wearables stay discoverable.
      final nearby = await _ble.scan(duration: const Duration(seconds: 12));
      if (!mounted || session != _session) return;
      setState(() {
        _scanning = false;
        _lastScan = DateTime.now();
        for (final item in nearby) {
          if (item.id.isNotEmpty) {
            _found[item.id] = _ProbedDevice(candidate: item, inspecting: true);
          }
        }
        _probing = nearby.isNotEmpty;
        _message = nearby.isEmpty
            ? 'No BLE devices seen. Keep the wearable awake and near your phone.'
            : 'Found ${_found.length} devices. Inspecting GATT services automatically…';
      });

      // Inspect in small batches to avoid monopolizing Android Bluetooth.
      // Don't auto-pair or send proprietary writes during discovery.
      final priority = [..._found.values]
        ..sort((a, b) {
          if (a.candidate.hasKnownCapabilities !=
              b.candidate.hasKnownCapabilities) {
            return a.candidate.hasKnownCapabilities ? -1 : 1;
          }
          return b.candidate.rssi.compareTo(a.candidate.rssi);
        });
      final selected = priority.take(16).toList();
      for (var i = 0; i < selected.length; i += 2) {
        if (!mounted || session != _session) return;
        await Future.wait(selected.skip(i).take(2).map((entry) async {
          BleDeviceInspection? details;
          String? error;
          try {
            details = await _ble.inspect(entry.candidate);
          } catch (e) {
            error = e.toString();
          }
          if (!mounted || session != _session) return;
          setState(() {
            _found[entry.candidate.id] = entry.inspected(details, error);
            _inspectedCount++;
          });
          final verifiedDetails = details;
          if (verifiedDetails != null && verifiedDetails.protocolId != null &&
              _saved.any((device) =>
                  device.id == entry.candidate.id &&
                  device.protocolId == verifiedDetails.protocolId)) {
            // Enrich saved metadata without re-pairing or changing the user's
            // previously selected metric sources.
            try {
              await _store.refreshInspection(
                device: entry.candidate,
                inspection: verifiedDetails,
              );
            } catch (_) {
              // Failure to refresh metadata does not erase prior registration.
            }
          }
        }));
      }
      if (!mounted || session != _session) return;
      setState(() {
        _probing = false;
        for (final item in priority.skip(selected.length)) {
          _found[item.candidate.id] = item.inspected(
            null, 'Not probed automatically this pass. Tap Inspect.',
          );
        }
        _message = '${_found.length} nearby devices • '
            '$_inspectedCount GATT inspections completed. '
            'Unknown devices are shown; recognition is not proof of support.';
      });
      await _refreshSaved();
    } catch (e) {
      if (!mounted || session != _session) return;
      setState(() {
        _message = 'Automatic scan unavailable: $e';
        _scanning = false;
        _probing = false;
      });
    }
  }

  Future<void> _inspectOne(_ProbedDevice entry) async {
    final id = entry.candidate.id;
    if (_found[id]?.inspecting == true) return;
    setState(() {
      _found[id] = _ProbedDevice(candidate: entry.candidate, inspecting: true);
    });
    try {
      final inspection = await _ble.inspect(entry.candidate);
      if (!mounted) return;
      setState(() => _found[id] = entry.inspected(inspection, null));
      if (inspection.protocolId != null && _saved.any((saved) =>
          saved.id == id && saved.protocolId == inspection.protocolId)) {
        await _store.refreshInspection(
          device: entry.candidate,
          inspection: inspection,
        );
        await _refreshSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _found[id] = entry.inspected(null, e.toString()));
      }
    }
  }

  Future<void> _add(_ProbedDevice entry) async {
    final id = entry.candidate.id;
    if (_adding.contains(id)) return;
    setState(() => _adding.add(id));
    try {
      // Explicit user approval before any pairing or saved registration.
      final inspection = entry.inspection ?? await _ble.inspect(entry.candidate);
      final pair = await _ble.pair(entry.candidate);
      if (!pair.usable) throw StateError(pair.message);
      await _store.save(
        device: entry.candidate,
        inspection: inspection,
        pair: pair,
      );
      await _refreshSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${entry.candidate.name} saved in Salus.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add ${entry.candidate.name}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding.remove(id));
    }
  }

  Future<void> _read(SavedDirectDevice device) async {
    if (_reading.contains(device.id)) return;
    setState(() => _reading.add(device.id));
    try {
      final candidate = _found[device.id]?.candidate ?? BleDeviceCandidate(
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
        bondState: device.pairState,
      );
      final result = await _metrics.readAndStore(
        candidate, protocolId: device.protocolId,
      );
      if (!mounted) return;
      // Bring new direct samples into Salus without replacing manually chosen
      // metric sources or claiming Health Connect supplied BLE readings.
      final samples = await _metrics.loadSamples();
      final devices = await _store.load();
      if (!mounted) return;
      final app = ref.read(appStateProvider);
      final merged = _metrics.mergeIntoSnapshot(
        app.health,
        metricSources: app.metricSources,
        samples: samples,
        registeredDevices: devices,
      );
      ref.read(appStateProvider.notifier).setHealthSnapshot(merged);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Read failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _reading.remove(device.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedIds = _saved.map((d) => d.id).toSet();
    final nearby = [..._found.values]
      ..sort((a, b) {
        final ad = a.inspection?.capabilities.isNotEmpty == true ||
            a.candidate.hasKnownCapabilities;
        final bd = b.inspection?.capabilities.isNotEmpty == true ||
            b.candidate.hasKnownCapabilities;
        if (ad != bd) return ad ? -1 : 1;
        return b.candidate.rssi.compareTo(a.candidate.rssi);
      });
    return Scaffold(
      appBar: AppBar(title: const Text('Automatic device discovery'), actions: [
        IconButton(
          tooltip: 'Scan again',
          onPressed: _scanning || _probing ? null : _discover,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
        children: [
          const SalusSectionTitle(
            title: 'Nearby devices',
            eyebrow: 'Independent Bluetooth discovery',
          ),
          const SizedBox(height: 8),
          const Text(
            'Salus scans automatically, inspects readable Bluetooth services, '
            'and matches local drivers. No manufacturer companion app is needed '
            'for discovery. Pairing is never automatic.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          if (_scanning || _probing) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_scanning ? 'Scanning all nearby BLE advertisements…'
                : 'Inspecting GATT services ($_inspectedCount complete)…',
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
          ],
          if (_message != null) ...[
            Text(_message!, style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 12),
          ],
          if (_saved.isNotEmpty) ...[
            const Text('Saved in Salus', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 20,
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final device in _saved) ...[
              SalusPaper(child: Row(children: [
                const Icon(Icons.bluetooth_connected_rounded,
                    color: AppTheme.mint),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(device.name, style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text('${device.deviceKind} • ${device.protocolLabel ?? 'Unidentified protocol'}',
                        style: const TextStyle(color: AppTheme.textSecondary,
                            fontSize: 12)),
                  ],
                )),
                IconButton(
                  tooltip: device.protocolId == 'cpap-family'
                      ? 'Manage CPAP in advanced device controls'
                      : 'Read available health data',
                  onPressed: _reading.contains(device.id) ||
                          device.protocolId == 'cpap-family'
                      ? null : () => _read(device),
                  icon: _reading.contains(device.id)
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded),
                ),
              ])),
              const SizedBox(height: 8),
            ],
          ],
          if (nearby.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Found nearby (${nearby.length})', style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 20,
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            for (final item in nearby) ...[
              _NearbyResult(
                item: item,
                alreadySaved: savedIds.contains(item.candidate.id),
                adding: _adding.contains(item.candidate.id),
                onInspect: () => _inspectOne(item),
                onAdd: () => _add(item),
              ),
              const SizedBox(height: 9),
            ],
          ],
          if (nearby.isEmpty && !_scanning && !_probing)
            const SalusPaper(child: Text(
              'No nearby BLE device currently advertising. '
              'Some wearables advertise only in their pairing mode.',
              style: TextStyle(color: AppTheme.textSecondary))),
          const SizedBox(height: 18),
          SalusPaper(
            onTap: () => Navigator.of(context).pushNamed('/connections-advanced'),
            child: const Row(children: [
              Icon(Icons.tune_rounded, color: AppTheme.cyan),
              SizedBox(width: 12),
              Expanded(child: Text('Sources, permissions and advanced device controls',
                  style: TextStyle(color: AppTheme.textPrimary))),
              Icon(Icons.chevron_right_rounded),
            ]),
          ),
          const SizedBox(height: 12),
          const Text(
            'A discovered device is not necessarily supported. A service '
            'UUID or model name does not prove proprietary notifications or '
            'health-data decoding work. Salus shows unknown capabilities '
            'rather than inventing them.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _NearbyResult extends StatelessWidget {
  const _NearbyResult({required this.item, required this.alreadySaved,
    required this.adding, required this.onInspect, required this.onAdd});

  final _ProbedDevice item;
  final bool alreadySaved;
  final bool adding;
  final VoidCallback onInspect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final candidate = item.candidate;
    final details = item.inspection;
    final protocolId = details?.protocolId ?? candidate.protocolId;
    final kind = details?.deviceKind ?? candidate.deviceKind;
    final services = details?.services.map((s) => s.serviceUuid) ??
        candidate.advertisedServices;
    final decision = const SalusLocalDeviceDrivers().match(
      name: candidate.name,
      protocolId: protocolId,
      services: services,
      deviceKind: kind,
    );
    // A profile's list is a possibility, never an observed measurement.
    final standards = BleProtocolProfiles.analyze(services)
        .standardCapabilities;
    final capabilities = <String>{
      ...candidate.capabilities,
      ...?details?.capabilities,
    }.toList()..sort();
    final inspected = details != null;
    final headline = item.inspecting
        ? 'Reading GATT services…'
        : inspected
            ? 'Inspected • ${details.services.length} services'
            : item.probeError == null
                ? 'Advertised data only'
                : 'GATT inspection unavailable';
    return SalusPaper(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(kind.toLowerCase().contains('ring')
                  ? Icons.radio_button_unchecked_rounded
                  : kind.toLowerCase().contains('watch') ||
                    kind.toLowerCase().contains('band')
                      ? Icons.watch_rounded : Icons.bluetooth_rounded,
              color: AppTheme.cyan, size: 27),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(candidate.name, style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w800)),
              Text('$kind • $headline', style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
            ],
          )),
          Text('${candidate.rssi} dBm', style: const TextStyle(
            color: AppTheme.textMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 9),
        Text('Matched local profile: ${details?.protocolProfile ?? candidate.protocolProfile ?? 'Unknown'}',
            style: const TextStyle(color: AppTheme.textSecondary,
                fontSize: 12.5)),
        Text('Health reader: ${decision.status == SalusDriverStatus.ready ? 'Installed; not yet verified on this device' : decision.status == SalusDriverStatus.standardOnly ? 'Standard GATT reader' : 'No compatible decoder installed'}',
            style: const TextStyle(color: AppTheme.textSecondary,
                fontSize: 12)),
        Text('Direct notification writer: ${protocolId == 'ido-veryfit-family' ? 'Local IDO sender available; delivery unverified' : 'No matching installed driver'}',
            style: const TextStyle(color: AppTheme.textMuted,
                fontSize: 12)),
        if (standards.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Advertised/observed standard services: ${standards.join(', ')}',
              style: const TextStyle(color: AppTheme.textSecondary,
                  fontSize: 12)),
        ],
        if (capabilities.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text('Profile possibilities (not verified readings): ${capabilities.join(', ')}',
              style: const TextStyle(color: AppTheme.textMuted,
                  fontSize: 12)),
        ],
        if (item.probeError != null) ...[
          const SizedBox(height: 5),
          Text(item.probeError!, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.amber, fontSize: 12)),
        ],
        const SizedBox(height: 9),
        Row(children: [
          if (!item.inspecting)
            TextButton.icon(onPressed: onInspect,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Inspect')),
          const Spacer(),
          if (alreadySaved)
            const Text('Saved', style: TextStyle(color: AppTheme.mint,
                fontWeight: FontWeight.w700))
          else
            FilledButton.icon(
              onPressed: adding || item.inspecting ? null : onAdd,
              icon: adding
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
        ]),
        if (inspected && details.services.isNotEmpty)
          ExpansionTile(
            title: const Text('Observed Bluetooth services', style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 12.5)),
            tilePadding: EdgeInsets.zero,
            children: [for (final service in details.services)
              ListTile(
                dense: true,
                title: Text(service.serviceUuid, style: const TextStyle(
                    fontSize: 12, color: AppTheme.textPrimary)),
                subtitle: Text(service.characteristicDetails.join('\n'),
                    style: const TextStyle(fontSize: 11,
                        color: AppTheme.textSecondary)),
              ),
            ],
          ),
      ],
    ));
  }
}
