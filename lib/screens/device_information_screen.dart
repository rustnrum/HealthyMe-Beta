import 'package:flutter/material.dart';

import '../services/ble_device_information_service.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';

/// Read-only capability evidence. A protocol's advertised metric is NOT
/// equivalent to a successfully decoded reading from this physical device.
class DeviceInformationScreen extends StatefulWidget {
  final SavedDirectDevice device;

  const DeviceInformationScreen({super.key, required this.device});

  @override
  State<DeviceInformationScreen> createState() => _DeviceInformationScreenState();
}

class _DeviceInformationScreenState extends State<DeviceInformationScreen> {
  final _infoService = BleDeviceInformationService();
  final _metricService = DirectMetricService();
  BleDeviceInformation? _info;
  List<DirectMetricSample> _observed = const [];
  List<DirectMetricSample> _ringHrvHistory = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await _infoService.load(widget.device.id);
    final samples = await _metricService.loadSamples();
    if (!mounted) return;
    final byMetric = <String, DirectMetricSample>{};
    for (final sample in samples.where((x) => x.deviceId == widget.device.id)) {
      final old = byMetric[sample.metric];
      if (old == null || sample.capturedAt.isAfter(old.capturedAt)) {
        byMetric[sample.metric] = sample;
      }
    }
    final sorted = byMetric.values.toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    final ringHrv = samples.where((s) =>
        s.deviceId == widget.device.id && s.metric == 'Ring HRV proxy').toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    setState(() {
      _info = cached;
      _observed = sorted;
      _ringHrvHistory = ringHrv;
    });
    if (cached == null) await _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final latest = await _infoService.refresh(widget.device);
      if (!mounted) return;
      setState(() => _info = latest);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(DateTime at) =>
      '${at.month}/${at.day}/${at.year} '
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';

  bool _isExperimental(String name) =>
      name == 'Ring HRV proxy' ||
      name == 'Unverified Garmin short HRV';

  Widget _section(String title, Widget child) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );

  Widget _pair(String key, String? value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 115, child: Text(key, style: const TextStyle(
            fontSize: 13, color: Colors.white70))),
          Expanded(child: Text(value == null || value.isEmpty
              ? 'Not exposed / not read' : value, style: const TextStyle(fontSize: 13))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final protocolMetrics = widget.device.capabilities
        .where((x) => x != 'Raw motion' && x != 'Device information')
        .toList();
    final proven = _observed.where((x) => !_isExperimental(x.metric)).toList();
    final experimental = _observed.where((x) => _isExperimental(x.metric)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Device information')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.device.name, style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 24)),
          const SizedBox(height: 6),
          Text(widget.device.protocolLabel ?? widget.device.deviceKind,
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : _refresh,
            icon: _loading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bluetooth_searching),
            label: Text(_loading ? 'Reading Bluetooth information…'
                : 'Refresh device information'),
          ),
          const SizedBox(height: 8),
          const Text('Read-only Bluetooth service inspection. No pairing, '
              'firmware changes or device settings are written.',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
          ),
          const SizedBox(height: 16),
          _section('Device identity and firmware', Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              _pair('Manufacturer', info?.manufacturer),
              _pair('Model', info?.model),
              _pair('Hardware', info?.hardware),
              _pair('Firmware', info?.firmware),
              _pair('Software', info?.values['software']),
              _pair('Last checked', info == null ? null : _date(info.checkedAt)),
              if (info?.status == 'service-not-exposed')
                const Padding(padding: EdgeInsets.only(top: 6), child: Text(
                  'This device did not expose the standard Bluetooth Device '
                  'Information service. Its firmware cannot be inferred from its name.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                )),
              if (info != null && info.status != 'complete' &&
                  info.status != 'service-not-exposed')
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(
                  'Last probe: ${info.status}. Previously saved fields may be shown.',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                )),
            ],
          )),
          _section('Measurements received from this device',
            proven.isEmpty
                ? const Text('No successful metric readings stored yet. '
                    'A supported protocol does not prove that a metric works.',
                    style: TextStyle(color: Colors.white70))
                : Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: proven.take(20).map((sample) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline,
                            color: Colors.tealAccent, size: 17),
                        const SizedBox(width: 8),
                        Expanded(child: Text(sample.metric)),
                        Text(_date(sample.capturedAt),
                            style: const TextStyle(fontSize: 11,
                                color: Colors.white70)),
                      ]),
                    )).toList()),
          ),
          if (experimental.isNotEmpty)
            _section('Unverified measurements', Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final sample in experimental)
                  Text('${sample.metric} — diagnostic estimate only',
                    style: const TextStyle(color: Colors.orangeAccent)),
                const SizedBox(height: 7),
                const Text('These are not validated overnight HRV values '
                    'and must not be treated as medical measurements.',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            )),
          if (widget.device.protocolId == 'ring-uart-v1')
            _section('Ring HRV firmware proxy history', Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Experimental firmware values. NOT validated RMSSD, '
                    'milliseconds, AFib detection or a Recovery input.',
                    style: TextStyle(fontSize: 12, color: Colors.orangeAccent)),
                const SizedBox(height: 10),
                if (_ringHrvHistory.isEmpty)
                  const Text('No timed HRV proxy buckets received yet. '
                      'Sync the ring in Connections, then reopen this screen.'),
                for (final sample in _ringHrvHistory.take(24))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('${_date(sample.capturedAt)}  •  '
                        '${sample.value.toStringAsFixed(0)} (firmware proxy)'),
                  ),
              ],
            )),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('A received measurement confirms data transport, not '
                'medical accuracy. Metric quality is evaluated separately.',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ),
          _section('Protocol-advertised capabilities', Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('These are possibilities suggested by the device '
                  'profile, not proof the specific firmware supports them.',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 9),
              if (protocolMetrics.isEmpty)
                const Text('No recognized protocol capabilities.')
              else
                Wrap(spacing: 6, runSpacing: 7, children: protocolMetrics
                    .map((m) => Chip(label: Text(m))).toList()),
            ],
          )),
          _section('Observed Bluetooth services',
            info == null || info.serviceUuids.isEmpty
                ? const Text('No service inventory collected yet.',
                    style: TextStyle(color: Colors.white70))
                : Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: info.serviceUuids.map((uuid) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SelectableText(uuid, style: const TextStyle(
                          fontSize: 11.5, color: Colors.white70)),
                    )).toList()),
          ),
          if (info != null && info.firmwareHistory.isNotEmpty)
            _section('Firmware revision changes', Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: info.firmwareHistory.reversed
                  .map((x) => Padding(padding: const EdgeInsets.only(bottom: 6),
                      child: Text(x, style: const TextStyle(fontSize: 12))))
                  .toList(),
            )),
          if (info != null && info.notes.isNotEmpty)
            _section('Diagnostic notes', Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: info.notes.map((x) => Text('• $x',
                  style: const TextStyle(fontSize: 12))).toList(),
            )),
        ],
      ),
    );
  }
}
