import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/ble_discovery_service.dart';
import '../services/cpap_pairing_service.dart';
import '../services/cpap_therapy_service.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../widgets/salus_widgets.dart';

class CpapScreenV38 extends StatefulWidget {
  const CpapScreenV38({super.key});

  @override
  State<CpapScreenV38> createState() => _CpapScreenV38State();
}

class _CpapScreenV38State extends State<CpapScreenV38> {
  final _store = DirectDeviceStore();
  final _direct = DirectMetricService();
  final _pairing = CpapPairingService();
  final _therapy = CpapTherapyService();
  final _passkey = TextEditingController();

  List<CpapNightSummary> _nights = const [];
  SavedDirectDevice? _selected;
  bool _loading = true;
  bool _syncing = false;
  bool _submitting = false;
  bool _hasSavedPairing = false;
  bool _argsLoaded = false;
  String? _requestedId;
  String _range = 'Last night';
  String _status = 'Ready to sync.';

  @override
  void dispose() {
    _passkey.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final argument = ModalRoute.of(context)?.settings.arguments;
    if (argument is String && argument.isNotEmpty) {
      _requestedId = argument;
    }
    _load();
  }

  Future<void> _load() async {
    final devices = (await _store.load())
        .where((item) => item.protocolId == 'cpap-family')
        .toList();

    SavedDirectDevice? selected;
    for (final device in devices) {
      if (device.id == _requestedId) {
        selected = device;
        break;
      }
    }
    selected ??= devices.isEmpty ? null : devices.first;

    final samples = await _direct.loadSamples();
    final nights = selected == null
        ? const <CpapNightSummary>[]
        : _therapy.nightsFromSamples(samples, deviceId: selected.id);
    final paired = selected == null
        ? false
        : await _pairing.hasSavedPairing(selected.id);

    if (!mounted) return;
    setState(() {
      _selected = selected;
      _nights = nights;
      _hasSavedPairing = paired;
      _loading = false;
    });
  }

  BleDeviceCandidate _candidate(SavedDirectDevice device) {
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

  Future<void> _sync() async {
    final device = _selected;
    if (device == null || _syncing) return;

    final paired = await _pairing.hasSavedPairing(device.id);
    if (!mounted) return;
    setState(() {
      _syncing = true;
      _hasSavedPairing = paired;
      _status = 'Syncing CPAP…';
      _passkey.clear();
    });

    try {
      final result = await _direct.readAndStore(
        _candidate(device),
        protocolId: 'cpap-family',
        duration: const Duration(seconds: 70),
      );
      final samples = await _direct.loadSamples();
      final nights =
          _therapy.nightsFromSamples(samples, deviceId: device.id);
      final nowPaired = await _pairing.hasSavedPairing(device.id);

      if (!mounted) return;
      setState(() {
        _nights = nights;
        _hasSavedPairing = nowPaired;
        _status = result.history.isNotEmpty
            ? '${_historyNightCount(result.history)} nights synced.'
            : result.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _hasSavedPairing
            ? 'CPAP sync could not reconnect. Your saved pairing was kept. Use Re-pair only if the device pairing has actually changed.'
            : 'CPAP pairing did not complete: $error';
      });
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  int _historyNightCount(List<DirectMetricSample> history) {
    final days = <String>{};
    for (final sample in history) {
      final d = sample.capturedAt.toLocal();
      days.add('${d.year}-${d.month}-${d.day}');
    }
    return days.length;
  }

  Future<void> _submitCode() async {
    final device = _selected;
    final code = _passkey.text.trim();
    if (device == null ||
        _submitting ||
        !DirectMetricService.isValidCpapPasskey(code)) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final accepted =
          await _direct.submitCpapPasskey(device.id, code);
      if (!mounted) return;
      setState(() {
        _status = accepted
            ? 'Pairing code sent. Finishing secure CPAP sync…'
            : 'The CPAP is not asking for a code yet. Wait for the 4-digit code on the device and try again.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resetPairing() async {
    final device = _selected;
    if (device == null || _syncing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Re-pair CPAP?'),
        content: const Text(
          'This clears Salus’s saved CPAP pairing. Use this only if normal reconnect no longer works or the CPAP pairing was reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Re-pair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final cleared = await _pairing.resetPairing(device.id);
    if (!mounted) return;
    setState(() {
      _hasSavedPairing = !cleared;
      _status = cleared
          ? 'Saved pairing cleared. Tap Sync CPAP, then enter the 4-digit code only when the device displays it.'
          : 'Could not clear the saved pairing.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final device = _selected;

    return Scaffold(
      appBar: AppBar(title: const Text('CPAP')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : device == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No CPAP is connected yet. Add it from Connections.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SalusPageBackground(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                    children: [
                      SalusPaper(
                        glow: true,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.air_rounded,
                              color: AppTheme.cyan,
                              size: 34,
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    device.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _hasSavedPairing
                                        ? 'Connected • saved secure pairing'
                                        : 'Connected • pairing required',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _syncing ? null : _sync,
                        icon: _syncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(
                          _syncing ? 'Syncing CPAP…' : 'Sync CPAP',
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _status,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      if (_syncing && !_hasSavedPairing) ...[
                        const SizedBox(height: 12),
                        SalusPaper(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '4-digit pairing code',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Enter this only when the CPAP displays a one-time code.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _passkey,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                decoration: const InputDecoration(
                                  hintText: '0000',
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: _submitting
                                    ? null
                                    : _submitCode,
                                child: Text(
                                  _submitting
                                      ? 'Sending…'
                                      : 'Send code',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _syncing ? null : _resetPairing,
                          child: const Text('Re-pair device'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'Last night',
                            label: Text('Last night'),
                          ),
                          ButtonSegment(
                            value: '7 days',
                            label: Text('7 days'),
                          ),
                          ButtonSegment(
                            value: '30 days',
                            label: Text('30 days'),
                          ),
                          ButtonSegment(
                            value: 'Insights',
                            label: Text('Insights'),
                          ),
                        ],
                        selected: {_range},
                        onSelectionChanged: (value) =>
                            setState(() => _range = value.first),
                        showSelectedIcon: false,
                      ),
                      const SizedBox(height: 12),
                      _rangeBody(),
                    ],
                  ),
                ),
    );
  }

  Widget _rangeBody() {
    if (_nights.isEmpty) {
      return const SalusPaper(
        child: Text(
          'No decoded CPAP therapy nights are stored yet.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    if (_range == 'Insights') {
      final insights = _therapy.buildInsights(_nights);
      return SalusPaper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Therapy insights',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final message in insights) ...[
              Text(
                '• $message',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
    }

    final days = _range == '7 days'
        ? 7
        : _range == '30 days'
            ? 30
            : 1;
    if (days == 1) return _nightCard(_nights.first);

    final summary = _therapy.summarize(_nights, days: days);
    return SalusPaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$days-day averages',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${summary.nightsWithData} night${summary.nightsWithData == 1 ? '' : 's'} with therapy data',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 13),
          _metricGrid(
            usage: summary.averageUsageMinutes,
            ahi: summary.averageAhi,
            leak: summary.averageLeakRate,
            pressure: summary.averageTherapyPressure,
          ),
        ],
      ),
    );
  }

  Widget _nightCard(CpapNightSummary night) {
    return SalusPaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dateLabel(night.date),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          _metricGrid(
            usage: night.usageMinutes,
            ahi: night.ahi,
            leak: night.leakRate,
            pressure: night.therapyPressure,
          ),
        ],
      ),
    );
  }

  Widget _metricGrid({
    required double? usage,
    required double? ahi,
    required double? leak,
    required double? pressure,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Usage',
                value: _usage(usage),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'AHI',
                value: ahi == null ? '—' : ahi.toStringAsFixed(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Leak',
                value: leak == null
                    ? '—'
                    : '${leak.toStringAsFixed(1)} L/min',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Typical pressure',
                value: pressure == null
                    ? '—'
                    : '${pressure.toStringAsFixed(1)} cmH₂O',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _usage(double? minutes) {
    if (minutes == null) return '—';
    final value = minutes.round();
    return '${value ~/ 60}h ${value % 60}m';
  }

  String _dateLabel(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
