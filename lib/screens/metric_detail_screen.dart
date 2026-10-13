import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/direct_metric_service.dart';
import '../services/hrv_source_service.dart';
import '../services/metric_history_service.dart';
import '../services/source_name_service.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';

/// Dedicated, provider-separated trend page for a single measured metric.
class MetricDetailScreen extends ConsumerStatefulWidget {
  final String metric;
  const MetricDetailScreen({super.key, required this.metric});

  @override
  ConsumerState<MetricDetailScreen> createState() => _MetricDetailScreenState();
}

class _MetricDetailScreenState extends ConsumerState<MetricDetailScreen> {
  late Future<MetricHistoryResult> _future;
  String _range = '7 days';
  String? _selectedSource;
  String? _refreshStatus;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MetricHistoryResult> _load() => const MetricHistoryService().load(
        widget.metric,
        healthConnectAuthorized: ref.read(appStateProvider).health.authorized,
      );

  Future<void> _syncAndLoad() async {
    final source=ref.read(appStateProvider).metricSources[widget.metric];
    String? result;
    if(widget.metric=='HRV' && source != null && source.startsWith('ble:')) {
      result=await ref.read(healthSyncProvider.notifier).refreshSelectedHrv();
    } else {
      await ref.read(healthSyncProvider.notifier).sync(forceDirect:true);
    }
    if(!mounted)return;
    setState(() { _refreshStatus=result; _future=_load(); });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final configured = app.metricSources[widget.metric];
    final unit = MetricHistoryService.unitFor(widget.metric);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(MetricHistoryService.labelFor(widget.metric)),
        actions: [
          IconButton(
            tooltip: 'Reload measured history',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _syncAndLoad,
          ),
        ],
      ),
      body: FutureBuilder<MetricHistoryResult>(
        future: _future,
        builder: (context, snapshot) {
          final all = snapshot.data?.readings ?? const <DirectMetricSample>[];
          final ringHistory = snapshot.data?.ringHrvProxy ?? const <DirectMetricSample>[];
          final hrvView = HrvSourceService.resolve(
            health: app.health, selectedSource: configured,
            directSamples: ringHistory);
          final selectedRingHistory = hrvView.indexHistory;

          final sources = <String, String>{};
          for (final sample in all) {
            sources[sample.sourceId] = sample.deviceName;
          }
          final preferred = configured != null && configured != 'Auto'
              ? sources.keys.where((id) =>
                  SourceNameService.sameProvider(id, configured)).firstOrNull
              : null;
          // A manually selected source is authoritative, including if it has
          // no history. Never substitute a different provider silently.
          final selected = _selectedSource ??
              (configured != null && configured != 'Auto'
                  ? preferred ?? configured
                  : (all.isEmpty ? null : all.last.sourceId));
          final windowDays = _range == '24 hours' ? 1 : _range == '7 days' ? 7 : 30;
          final cutoff = DateTime.now().subtract(Duration(days: windowDays));
          final filtered = all.where((sample) =>
              sample.sourceId == selected &&
              !sample.capturedAt.isBefore(cutoff)).toList();
          final last = filtered.isEmpty ? null : filtered.last;
          final average = filtered.isEmpty
              ? null
              : filtered.map((e) => e.value).reduce((a, b) => a + b) /
                  filtered.length;
          final minimum = filtered.isEmpty
              ? null
              : filtered.map((e) => e.value).reduce(math.min);
          final maximum = filtered.isEmpty
              ? null
              : filtered.map((e) => e.value).reduce(math.max);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              if (_refreshStatus != null) ...[
                Text(_refreshStatus!, style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
              ],
              Text(MetricHistoryService.labelFor(widget.metric),
                  style: const TextStyle(color: AppTheme.textPrimary,
                      fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('Actual measurements only. History stays separated by device or provider.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 18),
              if (snapshot.data?.warning != null) ...[
                Text(snapshot.data!.warning!,
                    style: const TextStyle(color: AppTheme.amber)),
                const SizedBox(height: 10),
              ],
              if (widget.metric == 'HRV') ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Ring HRV firmware history', style: TextStyle(
                        color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text('${selectedRingHistory.length} saved index readings from the selected ring',
                        style: const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 7),
                    const Text('These are real device-reported firmware index values, not verified RMSSD in milliseconds. They cannot count toward the Recovery HRV baseline.',
                        style: TextStyle(color: AppTheme.amber, fontSize: 12)),
                    if (selectedRingHistory.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      Text('Last index: ${selectedRingHistory.last.value.round()} • ${_time(selectedRingHistory.last.capturedAt)}',
                          style: const TextStyle(color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      SizedBox(height: 180, child: CustomPaint(
                        painter: _MetricChartPainter(selectedRingHistory),
                        child: const SizedBox.expand())),
                    ] else ...[
                      const SizedBox(height: 7),
                      const Text('No ring-index records have been imported into Salus from this source. QRing may have its own separate history. Tap Refresh to request a new Bluetooth read.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                    TextButton.icon(onPressed: _syncAndLoad,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh ring history')),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              if (widget.metric == 'HRV' && sources.isEmpty && ringHistory.isEmpty) ...[
                const Text('No validated HRV available yet',
                    style: TextStyle(color: AppTheme.amber,
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                    'The selected device has not supplied verified RMSSD HRV '
                    'readings through Salus. Ring firmware-index records are '
                    'shown separately when available and cannot substitute '
                    'for a verified HRV baseline in Recovery. Recovery will exclude them.',
                    style: TextStyle(color: AppTheme.textSecondary,
                        fontSize: 12.5)),
                const SizedBox(height: 15),
              ],
              if (widget.metric == 'HRV' &&
                  snapshot.data?.excludedGarminHrv.isNotEmpty == true) ...[
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Unverified old Garmin HRV samples',
                      style: TextStyle(color: AppTheme.textSecondary,
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Preserved, not included in Recovery or charts',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  children: [
                    for (final entry in snapshot.data!.excludedGarminHrv.reversed.take(20))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('${entry.value.toStringAsFixed(1)} ms · '
                              '${_time(entry.capturedAt)} · ${entry.deviceName}',
                              style: const TextStyle(color: AppTheme.textMuted,
                                  fontSize: 12)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (sources.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: sources.containsKey(selected) ? selected : null,
                  isExpanded: true,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(labelText: 'Data source'),
                  items: [
                    for (final entry in sources.entries)
                      DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) => setState(() => _selectedSource = id),
                ),
              const SizedBox(height: 14),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (final range in const ['24 hours', '7 days', '30 days'])
                  ChoiceChip(
                    label: Text(range),
                    selected: _range == range,
                    onSelected: (_) => setState(() => _range = range),
                  ),
              ]),
              const SizedBox(height: 18),
              if (snapshot.hasError)
                const Text('Could not load recorded history.',
                    style: TextStyle(color: AppTheme.textSecondary))
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator()))
              else if (last == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 44),
                  child: Text(
                    configured != null && configured != 'Auto'
                        ? 'No recorded ${widget.metric} readings from the selected provider in this period. Change your metric source in Connections, or choose another available source above.'
                        : 'No recorded ${widget.metric} readings in this period. There is no estimated or invented history.',
                    style: const TextStyle(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_value(last.value), style: const TextStyle(
                      fontSize: 42, color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900)),
                  const SizedBox(width: 7),
                  Padding(padding: const EdgeInsets.only(bottom: 7),
                    child: Text(unit, style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16))),
                ]),
                const SizedBox(height: 3),
                Text(last.sourceId.startsWith('ble:') &&
                        (widget.metric == 'Resting heart rate' || widget.metric == 'Steps')
                    ? '${widget.metric == 'Steps' ? 'Observed daily steps' : 'Daily resting HR'} • last synced ${_time(last.capturedAt)} • ${last.deviceName}'
                    : 'Latest • ${_time(last.capturedAt)} • ${last.deviceName}',
                    style: const TextStyle(color: AppTheme.textSecondary,
                        fontSize: 12.5)),
                const SizedBox(height: 20),
                Container(
                  height: 248,
                  padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: CustomPaint(painter: _MetricChartPainter(filtered),
                      child: const SizedBox.expand()),
                ),
                const SizedBox(height: 10),
                Text('${filtered.length} recorded reading${filtered.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                Row(children: [
                  _stat('Average', average, unit),
                  const SizedBox(width: 8),
                  _stat('Lowest', minimum, unit),
                  const SizedBox(width: 8),
                  _stat('Highest', maximum, unit),
                ]),
                const SizedBox(height: 18),
                const Text('Recorded measurements', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 18,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final sample in filtered.reversed.take(60))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${_value(sample.value)} $unit',
                        style: const TextStyle(color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700)),
                    subtitle: Text(sample.sourceId.startsWith('ble:') &&
                            (widget.metric == 'Resting heart rate' || widget.metric == 'Steps')
                        ? 'Daily value • last synced ${_time(sample.capturedAt)}'
                        : _time(sample.capturedAt),
                        style: const TextStyle(color: AppTheme.textSecondary)),
                    trailing: SizedBox(width: 100,
                        child: Text(sample.deviceName,
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11))),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String name, double? value, String unit) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
        decoration: BoxDecoration(color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(name, style: const TextStyle(color: AppTheme.textSecondary,
              fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value == null ? '—' : '${_value(value)} $unit',
              style: const TextStyle(color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800))),
        ]),
      ));

  String _value(double number) => number == number.roundToDouble()
      ? number.toStringAsFixed(0)
      : number.toStringAsFixed(1);

  String _time(DateTime d) => '${d.month}/${d.day}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _MetricChartPainter extends CustomPainter {
  final List<DirectMetricSample> points;
  const _MetricChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width < 80 || size.height < 80) return;
    const left = 49.0;
    const right = 10.0;
    const top = 10.0;
    const bottom = 30.0;
    final plotWidth = math.max(1.0, size.width - left - right);
    final plotHeight = math.max(1.0, size.height - top - bottom);
    final values = points.map((e) => e.value).toList();
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final padding = math.max((high - low) * 0.15, math.max(high.abs() * .03, 1));
    final minY = math.max(0.0, low - padding);
    final maxY = high + padding;
    final start = points.first.capturedAt.millisecondsSinceEpoch;
    final end = points.last.capturedAt.millisecondsSinceEpoch;
    final duration = math.max(1, end - start);
    final textStyle = TextStyle(color: Colors.white.withValues(alpha: 0.72),
        fontSize: 10);
    void label(String text, Offset location) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, location);
    }
    for (var tick = 0; tick <= 4; tick++) {
      final y = top + plotHeight * tick / 4;
      final value = maxY - (maxY - minY) * tick / 4;
      canvas.drawLine(Offset(left, y), Offset(left + plotWidth, y),
          Paint()..color = Colors.white.withValues(alpha: .13)..strokeWidth = 1);
      label(value.toStringAsFixed(value < 10 ? 1 : 0), Offset(2, y - 7));
    }
    final x0 = points.length == 1 ? left + plotWidth / 2 : left;
    Offset pointAt(int i) {
      final sample = points[i];
      final x = points.length == 1 ? x0 : left + plotWidth *
          (sample.capturedAt.millisecondsSinceEpoch - start) / duration;
      final y = top + plotHeight * (maxY - sample.value) / (maxY - minY);
      return Offset(x, y);
    }
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final p = pointAt(i);
      if (i == 0) {line.moveTo(p.dx, p.dy);} else {line.lineTo(p.dx, p.dy);}
    }
    final accent = const Color(0xFF67D4C4);
    canvas.drawPath(line, Paint()..color = accent..strokeWidth = 2.4
        ..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < points.length; i++) {
      if (points.length > 80 && i % 5 != 0 && i != points.length - 1) continue;
      canvas.drawCircle(pointAt(i), 2.7, Paint()..color = accent);
    }
    String shortDate(DateTime d) => '${d.month}/${d.day}';
    label(shortDate(points.first.capturedAt),
        Offset(left, size.height - 19));
    if (points.length > 1) {
      label(shortDate(points.last.capturedAt),
          Offset(size.width - 45, size.height - 19));
    }
  }

  @override
  bool shouldRepaint(covariant _MetricChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
