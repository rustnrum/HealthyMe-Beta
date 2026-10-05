class SourceNameService {
  static const String healthConnectAggregateKey =
      '__health_connect_steps_aggregate__';

  static String key({
    required String sourceId,
    required String sourceName,
  }) {
    final id = sourceId.trim();
    if (id.isNotEmpty) return id;
    return sourceName.trim();
  }

  static String displayFor({
    required String sourceId,
    required String sourceName,
  }) {
    final name = sourceName.trim();
    if (name.isNotEmpty && !_looksLikePackageId(name)) {
      return friendly(name);
    }
    final id = sourceId.trim();
    if (id.isNotEmpty) return friendly(id);
    return friendly(name);
  }

  static bool isTransportOnly(String source) {
    final lower = source.trim().toLowerCase();
    if (lower.isEmpty) return true;
    return lower == healthConnectAggregateKey ||
        lower == 'health connect' ||
        lower == 'healthconnect' ||
        lower.contains('health connect aggregate') ||
        lower == 'com.android.healthconnect' ||
        lower == 'com.google.android.apps.healthdata';
  }

  static String transportLabel(String source) {
    if (isTransportOnly(source)) return 'Health Connect transport';
    return 'via Health Connect';
  }

  static String friendly(String source) {
    final raw = source.trim();
    final lower = raw.toLowerCase();
    if (lower.isEmpty) return 'Connected source';

    if (lower == healthConnectAggregateKey ||
        lower.contains('health connect aggregate')) {
      return 'Health Connect';
    }

    // Display-only identity mappings. Routing behavior never depends on these
    // brands; the source key and metric availability do.
    if (lower.contains('com.app.cq.ring') ||
        lower == 'qring' ||
        lower.contains('qring')) {
      return 'QRing';
    }
    if (lower.contains('com.xs.imoni') ||
        lower == 'imoni' ||
        lower.contains('imoni')) {
      return 'iMoni';
    }
    // Health Connect's 2026 on-device Steps source uses an app-scoped
    // synthetic package name. It is a real source, not the HC transport.
    if (lower == 'android' || lower.startsWith('com.android.healthconnect.phone.')) {
      return 'Your phone';
    }
    if (lower == 'health connect' ||
        lower == 'healthconnect' ||
        lower == 'com.android.healthconnect' ||
        lower == 'com.google.android.apps.healthdata') {
      return 'Health Connect';
    }
    if (lower.contains('samsung') ||
        lower.contains('shealth') ||
        lower.contains('com.sec.android.app.shealth')) {
      return 'Samsung Health';
    }
    if (lower.contains('garmin')) return 'Garmin Connect';
    if (lower.contains('fitbit')) return 'Fitbit';
    if (lower.contains('withings')) return 'Withings';
    if (lower.contains('google fit') ||
        lower.contains('com.google.android.apps.fitness')) {
      return 'Google Fit';
    }
    if (lower.contains('polar')) return 'Polar';
    if (lower.contains('oura')) return 'Oura';
    if (lower.contains('whoop')) return 'WHOOP';
    if (lower.contains('zepp')) return 'Zepp';

    if (_looksLikePackageId(raw)) {
      return _packageBrand(raw);
    }

    return raw;
  }

  static bool _looksLikePackageId(String value) {
    final lower = value.toLowerCase();
    return (lower.startsWith('com.') ||
            lower.startsWith('org.') ||
            lower.startsWith('net.') ||
            lower.startsWith('io.') ||
            lower.startsWith('co.') ||
            lower.startsWith('fi.')) &&
        value.contains('.');
  }

  static String _packageBrand(String value) {
    final parts = value
        .split('.')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    const ignored = {
      'com',
      'org',
      'net',
      'io',
      'co',
      'fi',
      'android',
      'app',
      'apps',
      'mobile',
      'health',
      'fitness',
      'client',
      'phone',
      'wear',
    };
    for (final part in parts) {
      final lower = part.toLowerCase();
      if (!ignored.contains(lower) && lower.length > 2) {
        return _prettyToken(part);
      }
    }
    return 'Connected source';
  }

  static String _prettyToken(String value) {
    var text = value
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .trim();
    if (text.isEmpty) return 'Connected source';
    text = text.toLowerCase();
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  static List<String> uniqueRawByFriendly(Iterable<String> sources) {
    final result = <String>[];
    final seen = <String>{};
    for (final source in sources) {
      if (isTransportOnly(source)) continue;
      final name = friendly(source);
      if (seen.add(name)) result.add(source);
    }
    return result;
  }

  static bool detected(Iterable<String> sources, String provider) {
    return sources.any((source) => friendly(source) == provider);
  }

  static bool sameProvider(String a, String b) {
    if (a.trim().isEmpty || b.trim().isEmpty) return false;
    if (a.trim() == b.trim()) return true;
    return friendly(a) == friendly(b);
  }

  static bool pointMatches({
    required String selected,
    required String sourceId,
    required String sourceName,
  }) {
    return sameProvider(selected, sourceId) ||
        sameProvider(selected, sourceName);
  }
}
