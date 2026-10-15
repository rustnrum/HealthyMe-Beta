import '../models/models.dart';
import 'source_name_service.dart';

/// Qualified HRV comes only from Health Connect RMSSD records.
class HrvSourceView {
  final String? sourceId;
  final String sourceLabel;
  final double? rmssdMs;
  final List<double> rmssdHistory;
  final DateTime? lastRmssdAt;
  const HrvSourceView({required this.sourceId, required this.sourceLabel,
    required this.rmssdMs, required this.rmssdHistory, required this.lastRmssdAt});
  bool get hasRmssd => rmssdMs != null;
  String get displayedValue => hasRmssd ? '${rmssdMs!.round()} ms' : '—';
  String get status => hasRmssd ? 'RMSSD · $sourceLabel' : 'No RMSSD records in Health Connect';
}

class HrvSourceService {
  const HrvSourceService._();
  static HrvSourceView resolve({required HealthSnapshot health,
      required String? selectedSource}) {
    final selected = selectedSource == 'Auto' ? null : selectedSource;
    final source = health.resolvedSources['HRV'];
    final matches = source != null && !source.startsWith('ble:') &&
      (selected == null || SourceNameService.sameProvider(selected, source));
    final valid = matches && health.hrvMs != null &&
      health.hrvMs!.isFinite && health.hrvMs! > 0 && health.hrvMs! <= 1500;
    return HrvSourceView(
      sourceId: valid ? source : selected,
      sourceLabel: valid ? (health.sourceLabels[source] ?? SourceNameService.friendly(source)) :
        selected == null ? 'Health Connect' : SourceNameService.friendly(selected),
      rmssdMs: valid ? health.hrvMs : null,
      rmssdHistory: valid ? health.hrv30.where((v) => v.isFinite && v > 0 && v <= 1500).toList() : const [],
      lastRmssdAt: valid ? health.freshness['HRV'] : null,
    );
  }
}
