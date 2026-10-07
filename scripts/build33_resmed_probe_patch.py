from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 33 ResMed probe patch: {message}')


# ---------------------------------------------------------------------------
# Direct metric bridge: CPAP now reaches the native ResMed read-only probe.
# Preserve the therapy-only helper as an identity/routing regression guard,
# but do not short-circuit the native reader anymore.
# ---------------------------------------------------------------------------
direct = Path('lib/services/direct_metric_service.dart')
text = direct.read_text()

old_result = """class DirectMetricReadResult {
  final Map<String, double> metrics;
  final String message;
  final String reader;

  const DirectMetricReadResult({
    required this.metrics,
    required this.message,
    this.reader = 'generic',
  });
"""
new_result = """class DirectMetricReadResult {
  final Map<String, double> metrics;
  final String message;
  final String reader;
  final List<String> observations;
  final Map<String, int> diagnostics;

  const DirectMetricReadResult({
    required this.metrics,
    required this.message,
    this.reader = 'generic',
    this.observations = const [],
    this.diagnostics = const {},
  });
"""
if 'final List<String> observations;' not in text:
    if old_result not in text:
        fail('DirectMetricReadResult anchor missing')
    text = text.replace(old_result, new_result, 1)

old_guard = """    final resolvedProtocolId = protocolId ?? device.protocolId;
    if (isTherapyOnlyProtocol(resolvedProtocolId)) {
      return const DirectMetricReadResult(
        metrics: {},
        message:
            'CPAP therapy sync is not enabled yet. Salus will not treat this machine as a heart-rate sensor. Expected therapy metrics: usage time, AHI, leak rate, therapy pressure, and mask on/off.',
        reader: 'cpap-pending',
      );
    }

    if (!Platform.isAndroid) {
"""
new_guard = """    final resolvedProtocolId = protocolId ?? device.protocolId;

    if (!Platform.isAndroid) {
"""
if 'CPAP therapy sync is not enabled yet' in text:
    if old_guard not in text:
        fail('CPAP short-circuit anchor missing')
    text = text.replace(old_guard, new_guard, 1)

parse_anchor = """    final reader = map['reader']?.toString() ?? 'generic';
    final message = map['message']?.toString() ??
        (metrics.isEmpty
            ? 'No readable direct-device metric was returned.'
            : 'Direct device data read successfully.');

    if (metrics.isNotEmpty) {
"""
parse_new = """    final reader = map['reader']?.toString() ?? 'generic';
    final message = map['message']?.toString() ??
        (metrics.isEmpty
            ? 'No readable direct-device metric was returned.'
            : 'Direct device data read successfully.');
    final observations = <String>[];
    final rawObservations = map['observations'];
    if (rawObservations is List) {
      for (final item in rawObservations.whereType<Map>()) {
        final label = item['label']?.toString() ?? '';
        final hex = item['hex']?.toString() ?? '';
        if (label.isNotEmpty && hex.isNotEmpty) {
          observations.add('$label = $hex');
        }
      }
    }
    final diagnostics = <String, int>{};
    final rawDiagnostics = map['diagnostics'];
    if (rawDiagnostics is Map) {
      for (final entry in rawDiagnostics.entries) {
        final value = entry.value;
        if (value is num) diagnostics[entry.key.toString()] = value.toInt();
      }
    }

    if (metrics.isNotEmpty) {
"""
if 'final observations = <String>[];' not in text:
    if parse_anchor not in text:
        fail('native observation parse anchor missing')
    text = text.replace(parse_anchor, parse_new, 1)

return_old = """    return DirectMetricReadResult(
      metrics: metrics,
      message: message,
      reader: reader,
    );
"""
return_new = """    return DirectMetricReadResult(
      metrics: metrics,
      message: message,
      reader: reader,
      observations: observations,
      diagnostics: diagnostics,
    );
"""
if 'observations: observations' not in text:
    if return_old not in text:
        fail('DirectMetricReadResult return anchor missing')
    text = text.replace(return_old, return_new, 1)
direct.write_text(text)


# ---------------------------------------------------------------------------
# CPAP dashboard: surface connection/read/notification evidence immediately.
# Raw values are intentionally labeled as probe data, never therapy metrics.
# ---------------------------------------------------------------------------
cpap = Path('lib/screens/cpap_screen.dart')
text = cpap.read_text()

state_old = """  String? _selectedId;
  String? _status;
  int _view = 0;
"""
state_new = """  String? _selectedId;
  String? _status;
  List<String> _probeObservations = const [];
  Map<String, int> _probeDiagnostics = const {};
  int _view = 0;
"""
if 'List<String> _probeObservations' not in text:
    if state_old not in text:
        fail('CPAP probe state anchor missing')
    text = text.replace(state_old, state_new, 1)

start_old = """    setState(() {
      _checking = true;
      _status = null;
    });
"""
start_new = """    setState(() {
      _checking = true;
      _status = null;
      _probeObservations = const [];
      _probeDiagnostics = const {};
    });
"""
if '_probeObservations = const [];' not in text:
    if start_old not in text:
        fail('CPAP probe reset anchor missing')
    text = text.replace(start_old, start_new, 1)

call_old = """          bondState: device.bonded ? 'bonded' : device.pairState,
        ),
      );
      if (!mounted) return;
      setState(() => _status = result.message);
"""
call_new = """          bondState: device.bonded ? 'bonded' : device.pairState,
        ),
        protocolId: 'cpap-family',
        duration: const Duration(seconds: 20),
      );
      if (!mounted) return;
      setState(() {
        _status = result.message;
        _probeObservations = result.observations;
        _probeDiagnostics = result.diagnostics;
      });
"""
if "duration: const Duration(seconds: 20)" not in text:
    if call_old not in text:
        fail('CPAP read call anchor missing')
    text = text.replace(call_old, call_new, 1)

text = text.replace(
    "_checking ? 'Checking…' : 'Check for therapy data'",
    "_checking ? 'Listening…' : 'Probe live CPAP data'",
)
text = text.replace(
    "'${device.name} • direct therapy provider'",
    "'${device.name} • ResMed read-only probe'",
)

status_old = """                  if (_status != null) ...[
                    const SizedBox(height: 9),
                    Text(
                      _status!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
"""
status_new = """                  if (_status != null) ...[
                    const SizedBox(height: 9),
                    Text(
                      _status!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (_probeDiagnostics.isNotEmpty ||
                      _probeObservations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _probeCard(),
                  ],
"""
if '_probeCard(),' not in text:
    if status_old not in text:
        fail('CPAP probe card insertion anchor missing')
    text = text.replace(status_old, status_new, 1)

method_anchor = """  Widget _hero(SavedDirectDevice? device) {
"""
method_block = """  Widget _probeCard() {
    final reads = _probeDiagnostics['readCount'] ?? 0;
    final notifications = _probeDiagnostics['notificationCount'] ?? 0;
    final subscriptions = _probeDiagnostics['subscriptionCount'] ?? 0;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bluetooth_connected_rounded,
                  color: AppTheme.cyan, size: 21),
              SizedBox(width: 8),
              Text(
                'Live ResMed probe',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$reads readable values • $subscriptions notification channels • '
            '$notifications live notifications',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Raw BLE observations are diagnostic only until Salus maps them to verified therapy fields.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11.8,
              height: 1.35,
            ),
          ),
          if (_probeObservations.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final observation in _probeObservations.take(12)) ...[
              SelectableText(
                observation,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10.8,
                  height: 1.35,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 5),
            ],
          ],
        ],
      ),
    );
  }

""" + method_anchor
if 'Widget _probeCard()' not in text:
    if method_anchor not in text:
        fail('CPAP probe method anchor missing')
    text = text.replace(method_anchor, method_block, 1)

cpap.write_text(text)

print('Salus build 33 ResMed read-only probe patch applied.')
