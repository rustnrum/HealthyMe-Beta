import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/direct_metric_service.dart';
import '../services/spo2_history_service.dart';
import '../services/source_name_service.dart';
import '../state/app_state.dart';

/// Stored measurements only. Never invent earlier readings or blend sources.
class SpO2HistoryScreen extends ConsumerStatefulWidget {
  const SpO2HistoryScreen({super.key});
  @override
  ConsumerState<SpO2HistoryScreen> createState() => _SpO2HistoryScreenState();
}

class _SpO2HistoryScreenState extends ConsumerState<SpO2HistoryScreen> {
  late Future<SpO2HistoryResult> _future;
  String _range = '7 days';
  String? _sourceId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SpO2HistoryResult> _load() =>
      const SpO2HistoryService().load(
        healthConnectAuthorized: ref.read(appStateProvider).health.authorized,
      );

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(appStateProvider).metricSources['SpO2'];
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('SpO₂ history'), actions: [
        IconButton(
          tooltip: 'Refresh stored readings',
          onPressed: () => setState(() =>
              _future = _load()),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ]),
      body: FutureBuilder<SpO2HistoryResult>(
        future: _future,
        builder: (context, snapshot) {
          final all = snapshot.data?.readings ?? const <DirectMetricSample>[];
          final sources = <String, String>{};
          for (final s in all) {
            sources[s.sourceId] = s.deviceName;
          }
          final selected = _sourceId ??
              ((configured != null && configured != 'Auto')
                  ? sources.keys.where((source) =>
                      SourceNameService.sameProvider(source, configured))
                      .firstOrNull ?? configured
                  : all.isEmpty ? null : all.last.sourceId);
          final days = _range == '24 hours' ? 1 : _range == '7 days' ? 7 : 30;
          final cutoff = DateTime.now().subtract(Duration(days: days));
          final filtered = all.where((s) =>
              s.sourceId == selected && !s.capturedAt.isBefore(cutoff))
              .toList();
          final latest = filtered.isEmpty ? null : filtered.last;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            children: [
              const Text('Recorded blood oxygen', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 21,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              const Text(
                'Actual direct-device and Health Connect readings only. One source at a time; no invented history.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              if (snapshot.data?.warning != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(snapshot.data!.warning!,
                      style: const TextStyle(color: AppTheme.amber)),
                ),
              if (sources.isNotEmpty) DropdownButtonFormField<String>(
                initialValue: sources.containsKey(selected) ? selected : null,
                decoration: const InputDecoration(labelText: 'Measurement source'),
                dropdownColor: AppTheme.surface,
                items: [
                  for (final e in sources.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value,
                        overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (id) => setState(() => _sourceId = id),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, children: [
                for (final range in const ['24 hours', '7 days', '30 days'])
                  ChoiceChip(
                    label: Text(range),
                    selected: _range == range,
                    onSelected: (_) => setState(() => _range = range),
                  ),
              ]),
              const SizedBox(height: 14),
              if (snapshot.hasError)
                const Text('Could not load recorded SpO₂ history.',
                    style: TextStyle(color: AppTheme.textSecondary))
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (latest == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('No recorded SpO₂ history for this source and period. '
                      'Readings appear here only after a supported provider supplies them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              else ...[
                Text('${latest.value.toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppTheme.textPrimary,
                        fontSize: 38, fontWeight: FontWeight.bold)),
                Text('Latest: ${_time(latest.capturedAt)} • ${latest.deviceName}',
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 14),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: CustomPaint(
                    painter: _SpO2Painter(filtered),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${filtered.length} stored readings in this period',
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                for (final s in filtered.reversed.take(80))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.water_drop_outlined,
                        color: AppTheme.purple),
                    title: Text('${s.value.toStringAsFixed(0)}%',
                        style: const TextStyle(color: AppTheme.textPrimary)),
                    subtitle: Text(_time(s.capturedAt),
                        style: const TextStyle(color: AppTheme.textSecondary)),
                    trailing: Text(s.deviceName,
                        style: const TextStyle(color: AppTheme.textSecondary)),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _time(DateTime d) => '${d.month}/${d.day}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

class _SpO2Painter extends CustomPainter {
  const _SpO2Painter(this.values);
  final List<DirectMetricSample> values;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()..color = const Color(0x607F8691)..strokeWidth = 1;
    final line = Paint()
      ..color = AppTheme.purple
      ..strokeWidth = 2.3
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = AppTheme.purple;
    const left = 33.0;
    const bottom = 20.0;
    final w = size.width - left - 8;
    final h = size.height - bottom - 8;
    if (w <= 0 || h <= 0 || values.isEmpty) return;
    final low = math.max(0.0, values.map((s) => s.value).reduce(math.min) - 3);
    final high = math.min(100.0,
        math.max(low + 5.0, values.map((s) => s.value).reduce(math.max) + 3));
    for (var i = 0; i <= 4; i++) {
      final y = 5 + i * h / 4;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), axis);
      final label = (high - (high - low) * i / 4).round().toString();
      final text = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(left - text.width - 6, y - text.height / 2));
    }
    final first = values.first.capturedAt.millisecondsSinceEpoch.toDouble();
    final last = values.last.capturedAt.millisecondsSinceEpoch.toDouble();
    final span = math.max(1.0, last - first);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final s = values[i];
      final x = left + ((s.capturedAt.millisecondsSinceEpoch - first) / span) * w;
      final y = 5 + (high - s.value) / (high - low) * h;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 2.4, dot);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _SpO2Painter oldDelegate) =>
      oldDelegate.values != values;
}
