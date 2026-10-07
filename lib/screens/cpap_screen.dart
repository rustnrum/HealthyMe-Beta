import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/ble_discovery_service.dart';
import '../services/ble_protocol_profiles.dart';
import '../services/cpap_therapy_service.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../state/app_state.dart';

class CpapScreen extends ConsumerStatefulWidget {
  const CpapScreen({super.key});

  @override
  ConsumerState<CpapScreen> createState() => _CpapScreenState();
}

class _CpapScreenState extends ConsumerState<CpapScreen> {
  final _store = DirectDeviceStore();
  final _direct = DirectMetricService();
  final _therapy = CpapTherapyService();
  final _passkeyController = TextEditingController();

  List<SavedDirectDevice> _devices = const [];
  List<DirectMetricSample> _samples = const [];
  String? _selectedId;
  String? _status;
  List<String> _probeObservations = const [];
  Map<String, int> _probeDiagnostics = const {};
  int _view = 0;
  bool _loading = true;
  bool _checking = false;
  bool _argsLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _passkeyController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final argument = ModalRoute.of(context)?.settings.arguments;
    if (argument is String && argument.isNotEmpty) {
      _selectedId = argument;
    }
  }

  bool _isCpap(SavedDirectDevice device) =>
      device.protocolId == 'cpap-family' ||
      device.deviceKind.toLowerCase().contains('cpap') ||
      device.deviceKind.toLowerCase().contains('respiratory') ||
      BleProtocolProfiles.looksLikeCpapName(device.name);

  Future<void> _load() async {
    final devices = (await _store.load()).where(_isCpap).toList();
    final samples = await _direct.loadSamples();
    if (!mounted) return;

    setState(() {
      _devices = devices;
      _samples = samples;
      _selectedId ??= devices.isEmpty ? null : devices.first.id;
      if (_selectedId != null &&
          !devices.any((device) => device.id == _selectedId)) {
        _selectedId = devices.isEmpty ? null : devices.first.id;
      }
      _loading = false;
    });

    final allSaved = await _store.load();
    if (!mounted) return;
    final app = ref.read(appStateProvider);
    final merged = _direct.mergeIntoSnapshot(
      app.health,
      metricSources: app.metricSources,
      samples: samples,
      registeredDevices: allSaved,
    );
    ref.read(appStateProvider.notifier).setHealthSnapshot(merged);
  }

  SavedDirectDevice? get _selected {
    for (final device in _devices) {
      if (device.id == _selectedId) return device;
    }
    return null;
  }

  List<CpapNightSummary> get _nights {
    final selected = _selected;
    if (selected == null) return const [];
    return _therapy.nightsFromSamples(
      _samples,
      deviceId: selected.id,
    );
  }

  Future<void> _checkForData() async {
    final device = _selected;
    if (device == null || _checking) return;
    setState(() {
      _checking = true;
      _status = null;
    });

    try {
      final result = await _direct.readAndStore(
        BleDeviceCandidate(
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
        ),
        protocolId: 'cpap-family',
        duration: const Duration(seconds: 24),
        cpapPasskey: _passkeyController.text.trim().isEmpty
            ? null
            : _passkeyController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _status = result.message;
        _probeObservations = result.observations;
        _probeDiagnostics = result.diagnostics;
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Could not check therapy data: $error');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final nights = _nights;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CPAP Therapy'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
              children: [
                _hero(selected),
                const SizedBox(height: 16),
                if (_devices.length > 1) ...[
                  _devicePicker(),
                  const SizedBox(height: 14),
                ],
                _viewPicker(),
                const SizedBox(height: 14),
                if (selected == null)
                  _emptyDevice()
                else if (_view == 0)
                  _lastNight(nights)
                else if (_view == 1)
                  _trendView(nights, 7)
                else if (_view == 2)
                  _trendView(nights, 30)
                else
                  _insights(nights),
                if (selected != null) ...[
                  const SizedBox(height: 14),
                  _providerCard(selected),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passkeyController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'ResMed 4-digit code',
                      helperText: 'First secure pairing only. Leave blank after Salus has paired.',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _checking ? null : _checkForData,
                      icon: _checking
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        _checking ? 'Syncing…' : 'Secure sync CPAP data',
                      ),
                    ),
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 9),
                    Text(
                      _status!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (_probeDiagnostics.isNotEmpty ||
                      _probeObservations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _probeCard(),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _probeCard() {
    final reads = _probeDiagnostics['readCount'] ?? 0;
    final notifications = _probeDiagnostics['notificationCount'] ?? 0;
    final subscriptions = _probeDiagnostics['subscriptionCount'] ?? 0;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bluetooth_connected_rounded,
                  color: AppTheme.cyan, size: 21),
              SizedBox(width: 8),
              Text(
                'ResMed session diagnostics',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$reads readable values • $subscriptions notification channels • '
            '$notifications live notifications',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Salus only sends secure-session and read-only Get requests. It does not change therapy settings.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11.8,
              height: 1.35,
            ),
          ),
          if (_probeObservations.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final observation in _probeObservations.take(12)) ...[
              SelectableText(
                observation,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10.8,
                  height: 1.35,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 5),
            ],
          ],
        ],
      ),
    );
  }

  Widget _hero(SavedDirectDevice? device) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.glassGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cyan.withValues(alpha: 0.10),
              border: Border.all(
                color: AppTheme.cyan.withValues(alpha: 0.26),
              ),
            ),
            child: const Icon(Icons.air_rounded, color: AppTheme.cyan, size: 28),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Therapy dashboard',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  device == null
                      ? 'Connect a CPAP to start building nightly therapy trends.'
                      : '${device.name} • secure read-only therapy sync',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13.2,
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

  Widget _devicePicker() {
    return _GlassCard(
      child: DropdownButtonFormField<String>(
        key: ValueKey(_selectedId),
        initialValue: _selectedId,
        decoration: const InputDecoration(labelText: 'CPAP device'),
        items: [
          for (final device in _devices)
            DropdownMenuItem(value: device.id, child: Text(device.name)),
        ],
        onChanged: (value) => setState(() => _selectedId = value),
      ),
    );
  }

  Widget _viewPicker() {
    const labels = ['Last night', '7 days', '30 days', 'Insights'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            ChoiceChip(
              label: Text(labels[index]),
              selected: _view == index,
              onSelected: (_) => setState(() => _view = index),
            ),
            if (index != labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _emptyDevice() {
    return const _GlassCard(
      child: Text(
        'No CPAP is registered with Salus yet. Add the device from Connections first.',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _lastNight(List<CpapNightSummary> nights) {
    if (nights.isEmpty) return _noTherapyData();
    final night = nights.first;
    return Column(
      children: [
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${night.date.month}/${night.date.day}/${night.date.year}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Usage',
                      value: _formatUsage(night.usageMinutes),
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _MetricTile(
                      label: 'AHI',
                      value: night.ahi == null
                          ? '—'
                          : night.ahi!.toStringAsFixed(1),
                      icon: Icons.show_chart_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Leak',
                      value: night.leakRate == null
                          ? '—'
                          : '${night.leakRate!.toStringAsFixed(1)} L/min',
                      icon: Icons.air_rounded,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _MetricTile(
                      label: 'Pressure',
                      value: night.therapyPressure == null
                          ? '—'
                          : '${night.therapyPressure!.toStringAsFixed(1)} cmH₂O',
                      icon: Icons.speed_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trendView(List<CpapNightSummary> nights, int days) {
    final summary = _therapy.summarize(nights, days: days);
    final today = DateTime.now();
    final cutoff = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    final window = nights.where((night) => !night.date.isBefore(cutoff)).toList();
    if (window.isEmpty) return _noTherapyData();

    return Column(
      children: [
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$days-day averages',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
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
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Usage',
                      value: _formatUsage(summary.averageUsageMinutes),
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _MetricTile(
                      label: 'AHI',
                      value: summary.averageAhi == null
                          ? '—'
                          : summary.averageAhi!.toStringAsFixed(1),
                      icon: Icons.show_chart_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Leak',
                      value: summary.averageLeakRate == null
                          ? '—'
                          : '${summary.averageLeakRate!.toStringAsFixed(1)} L/min',
                      icon: Icons.air_rounded,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _MetricTile(
                      label: 'Pressure',
                      value: summary.averageTherapyPressure == null
                          ? '—'
                          : '${summary.averageTherapyPressure!.toStringAsFixed(1)} cmH₂O',
                      icon: Icons.speed_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Usage trend',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _MiniBars(
                values: window.reversed
                    .map((night) => night.usageMinutes ?? 0)
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final night in window.take(10)) ...[
          _NightRow(night: night),
          const SizedBox(height: 7),
        ],
      ],
    );
  }

  Widget _insights(List<CpapNightSummary> nights) {
    final insights = _therapy.buildInsights(nights);
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Salus insights',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Suggestions are based on your own therapy trend. They are not pressure-setting instructions or a treatment plan.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 13),
          for (final insight in insights) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.mint,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13.2,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _providerCard(SavedDirectDevice device) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Therapy metric provider',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${device.name} • Salus Direct',
            style: const TextStyle(
              color: AppTheme.cyan,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: const [
              _ProviderChip('Usage time'),
              _ProviderChip('AHI'),
              _ProviderChip('Leak rate'),
              _ProviderChip('Therapy pressure'),
              _ProviderChip('Mask on/off'),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'CPAP therapy time is kept separate from Sleep and Sleep Stages. Salus will not pretend that mask-on time equals actual sleep.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.2,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noTherapyData() {
    return const _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waiting for decoded therapy data',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'The CPAP is registered as a therapy provider. Salus will populate this page only from real nightly values such as usage, AHI, leak and pressure. Bluetooth service discovery by itself is not a therapy result.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatUsage(double? minutes) {
    if (minutes == null) return '—';
    final total = minutes.round().clamp(0, 24 * 60).toInt();
    final hours = total ~/ 60;
    final mins = total % 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.cyan, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  final List<double> values;

  const _MiniBars({required this.values});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 1.0
        : values
            .reduce((a, b) => a > b ? a : b)
            .clamp(1.0, double.infinity)
            .toDouble();
    return SizedBox(
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final value in values) ...[
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor:
                      (value / maxValue).clamp(0.04, 1.0).toDouble(),
                  widthFactor: 0.60,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NightRow extends StatelessWidget {
  final CpapNightSummary night;

  const _NightRow({required this.night});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              '${night.date.month}/${night.date.day}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Usage ${_usage(night.usageMinutes)}  •  AHI ${night.ahi?.toStringAsFixed(1) ?? '—'}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _usage(double? minutes) {
    if (minutes == null) return '—';
    final total = minutes.round();
    return '${total ~/ 60}h ${total % 60}m';
  }
}

class _ProviderChip extends StatelessWidget {
  final String label;

  const _ProviderChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.mint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.20)),
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
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.88)),
      ),
      child: child,
    );
  }
}
