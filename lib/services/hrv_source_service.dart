import '../models/models.dart';
import 'direct_metric_service.dart';
import 'source_name_service.dart';

/// Unified provider resolver for the HRV shown by Salus screens.
///
/// Qualified HRV is a timestamped RMSSD stream in milliseconds supplied via
/// Health Connect or a validated direct provider. COLMI command-57 is a
/// different, proprietary firmware index and is never substituted for RMSSD.
/// The same manual/automatic source rule applies to every supported provider.
class HrvSourceView {
  final String? sourceId;
  final String sourceLabel;
  final double? rmssdMs;
  final List<double> rmssdHistory;
  final List<DirectMetricSample> indexHistory;
  final DateTime? lastRmssdAt;

  const HrvSourceView({
    required this.sourceId,
    required this.sourceLabel,
    required this.rmssdMs,
    required this.rmssdHistory,
    required this.indexHistory,
    required this.lastRmssdAt,
  });

  bool get hasRmssd => rmssdMs != null;
  bool get hasIndex => indexHistory.isNotEmpty;
  DirectMetricSample? get latestIndex => hasIndex ? indexHistory.last : null;
  String get displayedValue => hasRmssd
      ? '${rmssdMs!.round()} ms'
      : hasIndex ? '${latestIndex!.value.round()} index' : '—';
  String get status => hasRmssd
      ? 'RMSSD · ${sourceLabel}'
      : hasIndex
          ? 'Firmware HRV index · not RMSSD · ${sourceLabel}'
          : 'No HRV records from the selected source';
}

class HrvSourceService {
  const HrvSourceService._();

  static bool _selectedMatches(String? selected, String source) =>
      selected == null || selected == 'Auto' ||
      SourceNameService.sameProvider(selected, source);

  /// Stable source choice, no manufacturer-specific branching.
  /// Auto prefers an existing verified HRV series, then displays any observed
  /// proprietary index separately, choosing its most recent provider.
  static HrvSourceView resolve({
    required HealthSnapshot health,
    required String? selectedSource,
    required List<DirectMetricSample> directSamples,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final configured = selectedSource == 'Auto' ? null : selectedSource;
    final resolved = health.resolvedSources['HRV'];
    final validRmssd = health.hrvMs != null &&
        health.hrvMs!.isFinite && health.hrvMs! > 0 &&
        health.hrvMs! <= 1500 && resolved != null &&
        _selectedMatches(configured, resolved);
    final samples = directSamples.where((s) =>
        s.metric == 'Ring HRV proxy' &&
        s.sourceId.isNotEmpty && s.value.isFinite &&
        s.value > 0 && s.value < 255 &&
        !s.capturedAt.isAfter(clock) &&
        !s.capturedAt.isBefore(clock.subtract(const Duration(days: 30))) &&
        _selectedMatches(configured, s.sourceId)).toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

    String? indexSource;
    if (samples.isNotEmpty) {
      // Explicit selection is authoritative; Auto chooses the newest observed
      // index provider only when standard RMSSD isn't already available.
      indexSource = configured ?? samples.last.sourceId;
    }
    final selectedIndexSource = indexSource;
    final indexHistory = selectedIndexSource == null ? <DirectMetricSample>[] :
        samples.where((s) => SourceNameService.sameProvider(s.sourceId, selectedIndexSource)).toList();
    final provider = validRmssd ? resolved : indexSource ?? configured;
    final label = provider == null ? 'Not selected' :
        health.sourceLabels[provider] ?? SourceNameService.friendly(provider);
    return HrvSourceView(
      sourceId: provider,
      sourceLabel: label,
      rmssdMs: validRmssd ? health.hrvMs : null,
      rmssdHistory: validRmssd ? health.hrv30.where((v) =>
          v.isFinite && v > 0 && v <= 1500).toList() : const [],
      indexHistory: indexHistory,
      lastRmssdAt: validRmssd ? health.freshness['HRV'] : null,
    );
  }
}
