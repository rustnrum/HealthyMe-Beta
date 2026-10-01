class SourceNameService {
  static String friendly(String source) {
    final lower = source.trim().toLowerCase();
    if (lower.isEmpty) return 'Health Connect';

    if (lower.contains('samsung') ||
        lower.contains('shealth') ||
        lower.contains('com.sec.android.app.shealth')) {
      return 'Samsung Health';
    }
    if (lower.contains('garmin')) return 'Garmin Connect';
    if (lower.contains('fitbit')) return 'Fitbit';
    if (lower.contains('withings')) return 'Withings Scale';
    if (lower.contains('google fit') || lower.contains('com.google.android.apps.fitness')) {
      return 'Google Fit';
    }
    if (lower.contains('health connect') ||
        lower.contains('healthconnect') ||
        lower.contains('healthdata') ||
        lower.contains('com.android.healthconnect')) {
      return 'Health Connect';
    }

    // Package IDs are useful internally but ugly and unreadable in the UI.
    if (lower.startsWith('com.') || lower.startsWith('org.') || lower.length > 38) {
      return 'Connected health source';
    }
    return source.trim();
  }

  static List<String> uniqueRawByFriendly(Iterable<String> sources) {
    final result = <String>[];
    final seen = <String>{};
    for (final source in sources) {
      final name = friendly(source);
      if (seen.add(name)) result.add(source);
    }
    return result;
  }

  static bool detected(Iterable<String> sources, String provider) {
    return sources.any((source) => friendly(source) == provider);
  }

  static bool sameProvider(String a, String b) => friendly(a) == friendly(b);

  static const Set<String> recognizedProviders = {
    'Samsung Health',
    'Garmin Connect',
    'Fitbit',
    'Withings Scale',
    'Google Fit',
  };

  static List<String> detectedFriendlyProviders(Iterable<String> sources) {
    final result = <String>[];
    final seen = <String>{};
    for (final source in sources) {
      final name = friendly(source);
      if (recognizedProviders.contains(name) && seen.add(name)) {
        result.add(name);
      }
    }
    result.sort();
    return result;
  }
}
