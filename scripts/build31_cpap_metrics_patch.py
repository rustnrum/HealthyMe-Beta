from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 31 CPAP metrics patch: {message}')


# Correct the CPAP capability model. Do not advertise wearable metrics.
profiles = Path('lib/services/ble_protocol_profiles.dart')
text = profiles.read_text()
old = """      capabilities: ['Therapy data'],
      note:
          'Respiratory-device candidate. Salus can pair/inspect Bluetooth now; therapy-data decoding depends on the machine protocol or local file format.',
"""
new = """      capabilities: [
        'Usage time',
        'AHI',
        'Leak rate',
        'Therapy pressure',
        'Mask on/off',
      ],
      note:
          'Respiratory-device candidate. Salus identifies CPAP therapy metrics separately from wearable metrics. Direct therapy-session decoding is not enabled yet.',
"""
if new not in text:
    if old not in text:
        fail('CPAP capability anchor missing')
    text = text.replace(old, new, 1)
profiles.write_text(text)


# Prevent a recognized CPAP from falling through to the generic HR reader.
service = Path('lib/services/direct_metric_service.dart')
text = service.read_text()
anchor = """  Future<DirectMetricReadResult> readAndStore(
    BleDeviceCandidate device, {
    String? protocolId,
    Duration duration = const Duration(seconds: 14),
  }) async {
    if (!Platform.isAndroid) {
"""
replacement = """  static bool isTherapyOnlyProtocol(String? protocolId) =>
      protocolId == 'cpap-family';

  Future<DirectMetricReadResult> readAndStore(
    BleDeviceCandidate device, {
    String? protocolId,
    Duration duration = const Duration(seconds: 14),
  }) async {
    final resolvedProtocolId = protocolId ?? device.protocolId;
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
if 'static bool isTherapyOnlyProtocol' not in text:
    if anchor not in text:
        fail('direct metric CPAP guard anchor missing')
    text = text.replace(anchor, replacement, 1)

old_arg = """        'protocolId': protocolId ?? device.protocolId,
"""
new_arg = """        'protocolId': resolvedProtocolId,
"""
if new_arg not in text:
    if old_arg not in text:
        fail('resolved protocol argument anchor missing')
    text = text.replace(old_arg, new_arg, 1)
service.write_text(text)


# Migrate already-saved CPAP devices to the therapy metrics immediately.
store = Path('lib/services/direct_device_store.dart')
text = store.read_text()
old = """        capabilities:
            (json['capabilities'] as List<dynamic>? ?? const <dynamic>[])
                .map((value) => value.toString())
                .toList(),
"""
new = """        capabilities: json['protocolId']?.toString() == 'cpap-family'
            ? const [
                'Usage time',
                'AHI',
                'Leak rate',
                'Therapy pressure',
                'Mask on/off',
              ]
            : (json['capabilities'] as List<dynamic>? ?? const <dynamic>[])
                .map((value) => value.toString())
                .toList(),
"""
if new not in text:
    if old not in text:
        fail('saved-device capability migration anchor missing')
    text = text.replace(old, new, 1)
store.write_text(text)


# Keep the health-hardware classifier aware of CPAP metric names.
hub = Path('lib/services/source_hub_service.dart')
text = hub.read_text()
anchor = """      'Therapy data',
      'Raw motion',
"""
replacement = """      'Therapy data',
      'Usage time',
      'AHI',
      'Leak rate',
      'Therapy pressure',
      'Mask on/off',
      'Raw motion',
"""
if "'Usage time'," not in text:
    if anchor not in text:
        fail('source-hub therapy metric anchor missing')
    text = text.replace(anchor, replacement, 1)
hub.write_text(text)


# Normal Connections page: CPAP is connected, but no fake Sync-now action.
connections = Path('lib/screens/connections_screen.dart')
text = connections.read_text()
old = """  Widget build(BuildContext context) {
    final visible = metrics.take(5).toList();
    final remaining = metrics.length - visible.length;

    return _GlassCard(
"""
new = """  Widget build(BuildContext context) {
    final therapyPending = device.protocolId == 'cpap-family';
    final displayMetrics = therapyPending
        ? const [
            'Usage time',
            'AHI',
            'Leak rate',
            'Therapy pressure',
            'Mask on/off',
          ]
        : metrics;
    final visible = displayMetrics.take(5).toList();
    final remaining = displayMetrics.length - visible.length;

    return _GlassCard(
"""
if "final therapyPending = device.protocolId == 'cpap-family';" not in text:
    if old not in text:
        fail('Connections CPAP display anchor missing')
    text = text.replace(old, new, 1)

old = """                    Text(
                      _status(lastSeen),
                      style: const TextStyle(
"""
new = """                    Text(
                      therapyPending
                          ? 'Connected • CPAP therapy sync pending'
                          : _status(lastSeen),
                      style: const TextStyle(
"""
if 'Connected • CPAP therapy sync pending' not in text:
    if old not in text:
        fail('Connections CPAP status anchor missing')
    text = text.replace(old, new, 1)

old = """          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: syncing ? null : onSync,
              icon: syncing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(syncing ? 'Syncing…' : 'Sync now'),
            ),
          ),
"""
new = """          if (therapyPending) ...[
            const SizedBox(height: 10),
            const Text(
              'Salus recognizes this as a CPAP. It will not use the wearable heart-rate reader for this device.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.2,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: therapyPending || syncing ? null : onSync,
              icon: therapyPending
                  ? const Icon(Icons.air_rounded, size: 18)
                  : syncing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                therapyPending
                    ? 'Therapy sync pending'
                    : syncing
                        ? 'Syncing…'
                        : 'Sync now',
              ),
            ),
          ),
"""
if "? 'Therapy sync pending'" not in text:
    if old not in text:
        fail('Connections CPAP sync-button anchor missing')
    text = text.replace(old, new, 1)
connections.write_text(text)


# Debug page: show the real CPAP state and remove Read-data/HR behavior.
sources = Path('lib/screens/sources_screen.dart')
text = sources.read_text()
old = """    final capabilities = source.metrics;
    final protocol = inspection?.protocolProfile ?? device.protocolProfile;
    final kind = inspection?.deviceKind ?? device.deviceKind;

    return Container(
"""
new = """    final capabilities = source.metrics;
    final protocol = inspection?.protocolProfile ?? device.protocolProfile;
    final protocolId = inspection?.protocolId ?? device.protocolId;
    final kind = inspection?.deviceKind ?? device.deviceKind;
    final isCpap = protocolId == 'cpap-family';

    return Container(
"""
if "final isCpap = protocolId == 'cpap-family';" not in text:
    if old not in text:
        fail('debug CPAP protocol anchor missing')
    text = text.replace(old, new, 1)

old = """                        saved
                            ? 'Paired with Salus • ${device.bondState} • Read data to sync'
                            : !healthCandidate
"""
new = """                        saved
                            ? isCpap
                                ? 'Paired with Salus • CPAP therapy reader pending'
                                : 'Paired with Salus • ${device.bondState} • Read data to sync'
                            : !healthCandidate
"""
if 'Paired with Salus • CPAP therapy reader pending' not in text:
    if old not in text:
        fail('debug CPAP status anchor missing')
    text = text.replace(old, new, 1)

old = """                else if (saved)
                  FilledButton.tonalIcon(
                    onPressed: reading ? null : onRead,
                    icon: const Icon(Icons.sensors_rounded, size: 18),
                    label: Text(reading ? 'Reading…' : 'Read data'),
                  ),
"""
new = """                else if (saved && isCpap)
                  FilledButton.tonalIcon(
                    onPressed: null,
                    icon: Icon(Icons.air_rounded, size: 18),
                    label: Text('Therapy sync pending'),
                  )
                else if (saved)
                  FilledButton.tonalIcon(
                    onPressed: reading ? null : onRead,
                    icon: const Icon(Icons.sensors_rounded, size: 18),
                    label: Text(reading ? 'Reading…' : 'Read data'),
                  ),
"""
if 'else if (saved && isCpap)' not in text:
    if old not in text:
        fail('debug CPAP read-button anchor missing')
    text = text.replace(old, new, 1)
sources.write_text(text)


# Regression tests.
ble_test = Path('test/ble_protocol_profiles_test.dart')
text = ble_test.read_text()
old = """    expect(report.deviceKind, 'CPAP / respiratory');
    expect(report.allCapabilities, contains('Therapy data'));
"""
new = """    expect(report.deviceKind, 'CPAP / respiratory');
    expect(report.allCapabilities, contains('Usage time'));
    expect(report.allCapabilities, contains('AHI'));
    expect(report.allCapabilities, contains('Leak rate'));
    expect(report.allCapabilities, contains('Therapy pressure'));
    expect(report.allCapabilities, isNot(contains('Heart rate')));
"""
if new not in text:
    if old not in text:
        fail('CPAP profile regression test anchor missing')
    text = text.replace(old, new, 1)
ble_test.write_text(text)

metric_test = Path('test/direct_metric_service_test.dart')
text = metric_test.read_text()
if 'CPAP protocol never falls through to wearable metric reader' not in text:
    closing = text.rfind('\n}')
    if closing < 0:
        fail('direct metric test closing brace missing')
    block = """

  test('CPAP protocol never falls through to wearable metric reader', () {
    expect(DirectMetricService.isTherapyOnlyProtocol('cpap-family'), isTrue);
    expect(DirectMetricService.isTherapyOnlyProtocol('garmin-family'), isFalse);
    expect(DirectMetricService.isTherapyOnlyProtocol(null), isFalse);
  });
"""
    text = text[:closing] + block + text[closing:]
metric_test.write_text(text)

print('Salus build 31 CPAP metrics/read-routing patch applied.')
