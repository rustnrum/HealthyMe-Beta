import 'direct_metric_service.dart';

/// Sleep-window timestamps actually transmitted by the same direct BLE source.
/// Distinct from a user's preferred bedtime or inferred time from total sleep.
class SleepWindow {
  final DateTime start;
  final DateTime end;
  const SleepWindow(this.start, this.end);
}

class SleepWindowService {
  const SleepWindowService._();

  /// Pair ring-detected wake timestamps with the closest earlier sleep start.
  /// Legacy duration-only records do not contain a verifiable start/end pair.
  static SleepWindow? latest(List<DirectMetricSample> samples, String sourceId,
      {DateTime? now}) {
    final time = now ?? DateTime.now();
    final entries = samples.where((s) =>
        s.sourceId == sourceId && s.value == 1.0 &&
        !s.capturedAt.isAfter(time) &&
        time.difference(s.capturedAt) <= const Duration(days: 35)).toList();
    final starts = entries.where((s) => s.metric == 'Sleep start').toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    final ends = entries.where((s) => s.metric == 'Sleep end').toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    for (final end in ends) {
      for (final start in starts) {
        final duration = end.capturedAt.difference(start.capturedAt);
        if (duration >= const Duration(minutes: 30) &&
            duration <= const Duration(hours: 20)) {
          return SleepWindow(start.capturedAt, end.capturedAt);
        }
      }
    }
    return null;
  }
}
