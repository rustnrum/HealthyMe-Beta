import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../services/ble_discovery_service.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import 'command_card.dart';

/// Displays only genuine, device-sourced Garmin Body Battery readings.
/// This is NOT an input to Salus Recovery: both scores reuse sleep/HRV factors.
class GarminBodyBatteryPanel extends StatefulWidget {
  // Public pure helpers used by the Recovery UI and its regression tests.
  static List<DirectMetricSample> validHistory(
    List<DirectMetricSample> samples,
    String? deviceId, {
    DateTime? now,
  }) => _GarminBodyBatteryPanelState.validHistory(samples, deviceId, now: now);

  static String comparison({
    required int? recovery,
    required int confidence,
    required double? bodyBattery,
    required bool fresh,
  }) => _GarminBodyBatteryPanelState.comparison(
    recovery: recovery,
    confidence: confidence,
    bodyBattery: bodyBattery,
    fresh: fresh,
  );

  final int? recoveryScore;
  final int recoveryConfidence;

  const GarminBodyBatteryPanel({
    super.key,
    required this.recoveryScore,
    required this.recoveryConfidence,
  });

  @override
  State<GarminBodyBatteryPanel> createState() => _GarminBodyBatteryPanelState();
}

class _GarminBodyBatteryPanelState extends State<GarminBodyBatteryPanel> {
  final _direct = const DirectMetricService();
  final _devices = DirectDeviceStore();
  List<SavedDirectDevice> _watches = const [];
  List<DirectMetricSample> _samples = const [];
  String? _watchId;
  int? _probeStatus;
  DateTime? _probeTime;
  String? _error;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final devices = (await _devices.load())
          .where((d) => d.protocolId == 'garmin-family').toList();
      final samples = await _direct.loadSamples();
      final selected = devices.any((d) => d.id == _watchId)
          ? _watchId : (devices.isEmpty ? null : devices.first.id);
      int? status;
      DateTime? attempt;
      if (selected != null) {
        final prefs = await SharedPreferences.getInstance();
        status = prefs.getInt('salus_garmin_body_battery_status_$selected');
        final timestamp = prefs.getString('salus_garmin_body_battery_attempt_$selected');
        attempt = timestamp == null ? null : DateTime.tryParse(timestamp);
      }
      if (!mounted) return;
      setState(() {
        _watches = devices;
        _samples = samples;
        _watchId = selected;
        _probeStatus = status;
        _probeTime = attempt;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not read saved Garmin history: $error';
      });
    }
  }

  Future<void> _sync() async {
    if (_syncing || _watchId == null) return;
    final matches = _watches.where((d) => d.id == _watchId).toList();
    if (matches.isEmpty) return;
    final device = matches.first;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      await _direct.readAndStore(BleDeviceCandidate(
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
      ), protocolId: device.protocolId);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Garmin sync failed: $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  static List<DirectMetricSample> validHistory(
    List<DirectMetricSample> samples,
    String? deviceId, {
    DateTime? now,
  }) {
    if (deviceId == null) return const [];
    final clock = now ?? DateTime.now();
    final filtered = samples.where((s) =>
        s.deviceId == deviceId && s.metric == 'Body battery' &&
        s.value.isFinite && s.value >= 1 && s.value <= 100 &&
        s.capturedAt.isBefore(clock.add(const Duration(minutes: 2))) &&
        s.capturedAt.isAfter(clock.subtract(const Duration(days: 30)))).toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return filtered;
  }

  static String comparison({
    required int? recovery,
    required int confidence,
    required double? bodyBattery,
    required bool fresh,
  }) {
    if (bodyBattery == null) return 'Waiting for a real Garmin reading.';
    if (!fresh) return 'Body Battery is stale; comparison paused.';
    if (recovery == null) return 'Salus Recovery is unavailable; no comparison yet.';
    final gap = (recovery - bodyBattery).abs().round();
    final relation = recovery > bodyBattery
        ? 'Salus Recovery is higher'
        : recovery < bodyBattery ? 'Garmin Body Battery is higher' : 'Scores are equal';
    final note = confidence < 60 ? ' Salus confidence is limited.' : '';
    return '$relation • ${gap == 0 ? '0' : gap} point${gap == 1 ? '' : 's'} apart.$note';
  }

  String _when(DateTime? date) {
    if (date == null) return 'Never';
    final d = date.toLocal();
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${d.month}/${d.day} $hour:${d.minute.toString().padLeft(2, '0')} '
        '${d.hour < 12 ? 'AM' : 'PM'}';
  }

  String _probeLabel() => switch (_probeStatus) {
    1 => 'Request sent; registration pending',
    2 => 'Service registered; no Body Battery value returned',
    3 => 'Watch rejected Body Battery service registration',
    4 => 'Body Battery service did not respond',
    5 => 'Valid Body Battery value received',
    0 => 'No Body Battery request completed',
    _ => 'No service diagnostics recorded yet',
  };

  @override
  Widget build(BuildContext context) {
    final history = validHistory(_samples, _watchId);
    final latest = history.isEmpty ? null : history.last;
    final fresh = latest != null &&
        DateTime.now().difference(latest.capturedAt) < const Duration(hours: 24);
    final chartItems = history.where((s) => s.capturedAt.isAfter(
      DateTime.now().subtract(const Duration(days: 7)))).toList();

    return CommandCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.battery_charging_full_rounded, color: AppTheme.cyan),
          const SizedBox(width: 8),
          const Expanded(child: Text('Garmin Body Battery',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary))),
          Text(latest == null ? '—' : '${latest.value.round()}/100',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary)),
        ]),
        const SizedBox(height: 5),
        const Text('Garmin-reported energy estimate • separate from Salus Recovery',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        if (_loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ] else if (_watches.isEmpty) ...[
          const SizedBox(height: 12),
          const Text('No Garmin watch is registered. Add one in Connections to '
              'look for Body Battery readings.',
              style: TextStyle(color: AppTheme.textSecondary)),
        ] else ...[
          if (_watches.length > 1) ...[
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _watchId,
              isExpanded: true,
              items: _watches.map((d) => DropdownMenuItem<String>(
                value: d.id, child: Text(d.name))).toList(),
              onChanged: _syncing ? null : (id) {
                setState(() => _watchId = id);
                _load();
              },
            ),
          ],
          const SizedBox(height: 12),
          Text(latest == null
                ? 'No genuine Body Battery measurements received yet.'
                : '${fresh ? 'Last reading' : 'Last reading (stale)'} • ${_when(latest.capturedAt)}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 14),
          if (chartItems.isEmpty)
            Container(
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(12)),
              child: const Text('No readings for the past 7 days',
                style: TextStyle(color: AppTheme.textMuted)))
          else ...[
            SizedBox(height: 125, width: double.infinity,
                child: CustomPaint(painter: _BodyBatteryChart(chartItems))),
            const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('7 days ago', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              Text('Today', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ]),
          ],
          const SizedBox(height: 13),
          Text(comparison(
              recovery: widget.recoveryScore,
              confidence: widget.recoveryConfidence,
              bodyBattery: latest?.value,
              fresh: fresh),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('These scores use different methods; a gap does not prove either is wrong.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
          const SizedBox(height: 12),
          Text('Bluetooth: ${_probeLabel()}${_probeTime == null ? '' : ' • ${_when(_probeTime)}'}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: AppTheme.rose, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            label: Text(_syncing ? 'Syncing Garmin…' : 'Sync Garmin Body Battery'),
          ),
          const SizedBox(height: 4),
          const Text('This read may temporarily compete with an active Garmin Bluetooth session. '
              'No watch configuration or notification settings are changed.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ]),
    );
  }
}

class _BodyBatteryChart extends CustomPainter {
  final List<DirectMetricSample> samples;
  _BodyBatteryChart(this.samples);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    const insetX = 6.0;
    const insetY = 8.0;
    final w = math.max(1.0, size.width - insetX * 2);
    final h = math.max(1.0, size.height - insetY * 2);
    final origin = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    const span = 7 * 24 * 60 * 60 * 1000;
    final gridPaint = Paint()..color = AppTheme.textMuted.withValues(alpha: 0.23)
      ..strokeWidth = 1;
    for (final value in [0, 50, 100]) {
      final y = insetY + h * (1 - value / 100);
      canvas.drawLine(Offset(insetX, y), Offset(insetX + w, y), gridPaint);
    }
    final points = samples.map((s) {
      final x = insetX + w * ((s.capturedAt.millisecondsSinceEpoch - origin) / span).clamp(0.0, 1.0);
      final y = insetY + h * (1 - s.value / 100);
      return Offset(x, y);
    }).toList();
    final ink = Paint()..color = AppTheme.cyan..strokeWidth = 2.5
      ..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round;
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final pt in points.skip(1)) { path.lineTo(pt.dx, pt.dy); }
      canvas.drawPath(path, ink);
    }
    final dot = Paint()..color = AppTheme.cyan;
    canvas.drawCircle(points.last, 3.5, dot);
  }

  @override
  bool shouldRepaint(covariant _BodyBatteryChart oldDelegate) =>
      oldDelegate.samples != samples;
}
