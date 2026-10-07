class DeviceCategoryService {
  const DeviceCategoryService._();

  static String category({
    required String deviceKind,
    String? protocolId,
    String name = '',
  }) {
    final kind = deviceKind.trim().toLowerCase();
    final protocol = (protocolId ?? '').trim().toLowerCase();
    final tokens = _tokens(name);

    if (protocol == 'cpap-family' ||
        kind.contains('cpap') ||
        kind.contains('respiratory')) {
      return 'CPAP';
    }
    if (kind == 'ring' ||
        tokens.contains('qring') ||
        tokens.contains('colmi') ||
        tokens.contains('yawell')) {
      return 'Ring';
    }
    if (kind.contains('scale') ||
        kind.contains('weight') ||
        protocol.contains('scale')) {
      return 'Scale';
    }
    if (kind.contains('watch') ||
        kind.contains('band') ||
        protocol.contains('garmin') ||
        protocol.contains('veryfit') ||
        _hasIdw(tokens)) {
      return 'Watch';
    }
    return 'Other';
  }

  static Set<String> _tokens(String value) => value
      .trim()
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9áéíóúüñ]+'))
      .where((token) => token.isNotEmpty)
      .toSet();

  static bool _hasIdw(Set<String> tokens) =>
      tokens.any((token) => RegExp(r'^idw[0-9]+$').hasMatch(token));
}
