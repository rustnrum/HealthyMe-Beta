import 'direct_metric_service.dart';

class CpapNightSummary {
  final DateTime date;
  final String sourceName;
  final double? usageMinutes;
  final double? ahi;
  final double? leakRate;
  final double? therapyPressure;
  final bool? maskOn;

  const CpapNightSummary({
    required this.date,
    required this.sourceName,
    this.usageMinutes,
    this.ahi,
    this.leakRate,
    this.therapyPressure,
    this.maskOn,
  });

  bool get hasTherapyData =>
      usageMinutes != null ||
      ahi != null ||
      leakRate != null ||
      therapyPressure != null ||
      maskOn != null;
}

class CpapTrendSummary {
  final int requestedDays;
  final int nightsWithData;
  final double? averageUsageMinutes;
  final double? averageAhi;
  final double? averageLeakRate;
  final double? averageTherapyPressure;

  const CpapTrendSummary({
    required this.requestedDays,
    required this.nightsWithData,
    this.averageUsageMinutes,
    this.averageAhi,
    this.averageLeakRate,
    this.averageTherapyPressure,
  });
}

class CpapTherapyService {
  static const therapyMetrics = <String>{
    'Usage time',
    'AHI',
    'Leak rate',
    'Therapy pressure',
    'Mask on/off',
  };

  List<CpapNightSummary> nightsFromSamples(
    Iterable<DirectMetricSample> samples, {
    required String deviceId,
  }) {
    final matching = samples
        .where(
          (sample) =>
              sample.deviceId == deviceId &&
              therapyMetrics.contains(sample.metric),
        )
        .toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

    final grouped = <String, List<DirectMetricSample>>{};
    for (final sample in matching) {
      final local = sample.capturedAt.toLocal();
      final key =
          '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <DirectMetricSample>[]).add(sample);
    }

    final nights = <CpapNightSummary>[];
    for (final entry in grouped.entries) {
      final values = entry.value;
      if (values.isEmpty) continue;
      final latestByMetric = <String, DirectMetricSample>{};
      for (final sample in values) {
        latestByMetric[sample.metric] = sample;
      }
      double? value(String metric) => latestByMetric[metric]?.value;
      final date = values.last.capturedAt.toLocal();
      final mask = value('Mask on/off');
      nights.add(
        CpapNightSummary(
          date: DateTime(date.year, date.month, date.day),
          sourceName: values.last.deviceName,
          usageMinutes: value('Usage time'),
          ahi: value('AHI'),
          leakRate: value('Leak rate'),
          therapyPressure: value('Therapy pressure'),
          maskOn: mask == null ? null : mask >= 0.5,
        ),
      );
    }

    nights.sort((a, b) => b.date.compareTo(a.date));
    return nights.where((night) => night.hasTherapyData).toList();
  }

  CpapTrendSummary summarize(
    List<CpapNightSummary> nights, {
    required int days,
    DateTime? now,
  }) {
    final today = now?.toLocal() ?? DateTime.now();
    final cutoff = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    final window = nights
        .where((night) => !night.date.isBefore(cutoff))
        .toList();

    double? averageOf(double? Function(CpapNightSummary night) pick) {
      final values = window.map(pick).whereType<double>().toList();
      if (values.isEmpty) return null;
      return values.reduce((a, b) => a + b) / values.length;
    }

    return CpapTrendSummary(
      requestedDays: days,
      nightsWithData: window.length,
      averageUsageMinutes: averageOf((night) => night.usageMinutes),
      averageAhi: averageOf((night) => night.ahi),
      averageLeakRate: averageOf((night) => night.leakRate),
      averageTherapyPressure:
          averageOf((night) => night.therapyPressure),
    );
  }

  List<String> buildInsights(List<CpapNightSummary> nights) {
    if (nights.isEmpty) {
      return const [
        'Salus recognizes the CPAP as a therapy provider, but no decoded nightly therapy sessions are stored yet.',
        'Suggestions will appear only after real CPAP values are available. Salus will not invent sleep or therapy results from a Bluetooth connection alone.',
      ];
    }

    final ordered = [...nights]..sort((a, b) => b.date.compareTo(a.date));
    if (ordered.length < 3) {
      return const [
        'A few more therapy nights are needed before Salus can compare your recent pattern with your own baseline.',
      ];
    }

    final recent = ordered.take(3).toList();
    final prior = ordered.skip(3).take(7).toList();
    final messages = <String>[];

    double? avg(
      List<CpapNightSummary> values,
      double? Function(CpapNightSummary night) pick,
    ) {
      final numbers = values.map(pick).whereType<double>().toList();
      if (numbers.isEmpty) return null;
      return numbers.reduce((a, b) => a + b) / numbers.length;
    }

    final recentUsage = avg(recent, (night) => night.usageMinutes);
    final priorUsage = avg(prior, (night) => night.usageMinutes);
    if (recentUsage != null && priorUsage != null) {
      final change = recentUsage - priorUsage;
      if (change <= -45) {
        messages.add(
          'Your recent CPAP use is down by about ${change.abs().round()} minutes per night compared with your earlier baseline. Check what changed in your bedtime or mask routine.',
        );
      } else if (change >= 45) {
        messages.add(
          'Your recent CPAP use is up by about ${change.round()} minutes per night compared with your earlier baseline.',
        );
      }
    }

    final recentLeak = avg(recent, (night) => night.leakRate);
    final priorLeak = avg(prior, (night) => night.leakRate);
    if (recentLeak != null && priorLeak != null && priorLeak > 0) {
      final change = recentLeak - priorLeak;
      if (change > 2 && recentLeak > priorLeak * 1.25) {
        messages.add(
          'Mask leak is running higher than your recent baseline. Check the mask seal, cushion position, and whether anything about your setup changed.',
        );
      }
    }

    final recentAhi = avg(recent, (night) => night.ahi);
    final priorAhi = avg(prior, (night) => night.ahi);
    if (recentAhi != null && priorAhi != null) {
      final change = recentAhi - priorAhi;
      if (change > 1 && recentAhi > priorAhi * 1.25) {
        messages.add(
          'Events per hour are trending above your recent baseline. Salus will keep watching the pattern; if it persists, it may be worth discussing with your sleep clinician.',
        );
      }
    }

    if (messages.isEmpty) {
      messages.add(
        'Your recent CPAP therapy pattern is fairly steady compared with the nights Salus has stored so far.',
      );
    }

    messages.add(
      'Salus can suggest checks and highlight trends, but it will not tell you to change therapy pressure or mode on its own.',
    );
    return messages;
  }
}
