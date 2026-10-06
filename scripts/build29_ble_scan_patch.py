from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 29 BLE scan patch: {message}')


# ---------------------------------------------------------------------------
# Unknown BLE devices are ordinary Bluetooth devices, not health devices.
# ---------------------------------------------------------------------------
path = Path('lib/services/ble_discovery_service.dart')
text = path.read_text()
text = text.replace("this.deviceKind = 'Health device',", "this.deviceKind = 'Bluetooth device',")
text = text.replace(
    'Bluetooth scan/connect permission is required to use nearby health devices.',
    'Bluetooth scan/connect permission is required to use nearby Bluetooth devices.',
)
path.write_text(text)

path = Path('lib/services/ble_protocol_profiles.dart')
text = path.read_text()
old = """    if (capabilities.contains('Heart rate')) return 'Health sensor';
    return 'Bluetooth health device';
"""
new = """    if (capabilities.contains('Heart rate')) return 'Heart-rate sensor';
    return 'Bluetooth device';
"""
if new not in text:
    if old not in text:
        fail('unknown-device kind anchor missing')
    text = text.replace(old, new, 1)
path.write_text(text)


# ---------------------------------------------------------------------------
# Central health-candidate classifier used by the scan UI.
# ---------------------------------------------------------------------------
path = Path('lib/services/source_hub_service.dart')
text = path.read_text()
if 'SALUS_BUILD29_HEALTH_CANDIDATE' not in text:
    anchor = """  static String _normalizeMetric(String value) {
"""
    helper = """  // SALUS_BUILD29_HEALTH_CANDIDATE
  static bool isBluetoothHealthCandidate(HealthyDataSource source) {
    if (source.transport != SourceTransport.directBluetooth) return false;
    const healthMetrics = <String>{
      'Heart rate',
      'Resting heart rate',
      'HRV',
      'SpO2',
      'Respiratory rate',
      'Steps',
      'Sleep',
      'Sleep Stages',
      'Weight',
      'Body fat',
      'Body composition',
      'Blood pressure',
      'Glucose',
      'Temperature',
      'Cadence',
      'Cycling cadence',
      'Workout telemetry',
      'Workouts',
      'Therapy data',
      'Raw motion',
    };
    return source.metrics.any(healthMetrics.contains) ||
        source.note == 'Identified by Bluetooth protocol fingerprint';
  }

"""
    if anchor not in text:
        fail('source hub helper anchor missing')
    text = text.replace(anchor, helper + anchor, 1)
path.write_text(text)

# If a device advertises no usable name but inspection identifies a known
# protocol family, show that family instead of a generic Bluetooth label.
path = Path('lib/services/source_hub_service.dart')
text = path.read_text()
old = """      final rawName = device.name.trim();
      final unnamed = rawName.isEmpty || rawName == 'Unnamed BLE device';
      final label = unnamed
          ? (identifiedAsRing ? 'Smart ring' : 'Bluetooth device')
          : rawName;
"""
new = """      final rawName = device.name.trim();
      final unnamed = rawName.isEmpty || rawName == 'Unnamed BLE device';
      final profileLabel = inspection?.protocolProfile ?? device.protocolProfile;
      final label = unnamed
          ? (profileLabel ?? (identifiedAsRing ? 'Smart ring' : 'Bluetooth device'))
          : rawName;
"""
if new not in text:
    if old not in text:
        fail('source-hub unnamed protocol label anchor missing')
    text = text.replace(old, new, 1)
path.write_text(text)


# ---------------------------------------------------------------------------
# Scan -> automatic identification for likely health devices. Unknown devices
# stay visible under a separate collapsed section and are never described as
# health hardware until a health service/protocol is actually found.
# ---------------------------------------------------------------------------
path = Path('lib/screens/sources_screen.dart')
text = path.read_text()

# Add helpers before _scanBluetooth.
if 'SALUS_BUILD29_AUTO_IDENTIFY' not in text:
    anchor = """  Future<void> _scanBluetooth() async {
"""
    helpers = r'''  // SALUS_BUILD29_AUTO_IDENTIFY
  bool _looksLikeHealthDevice(BleDeviceCandidate device) {
    if (device.hasKnownCapabilities) return true;
    if (_savedDirectDevices.any((saved) => saved.id == device.id)) return true;

    final name = device.name.trim().toLowerCase();
    if (name.isEmpty || name == 'unnamed ble device') return false;
    const hints = <String>[
      'garmin',
      'vivoactive',
      'vívoactive',
      'venu',
      'fenix',
      'forerunner',
      'instinct',
      'ring',
      'colmi',
      'qring',
      'watch',
      'band',
      'amazfit',
      'xiaomi',
      'zepp',
      'fitcloud',
      'dafit',
      'da fit',
      'scale',
      'weight',
      'oximeter',
      'spo2',
      'blood pressure',
      'glucose',
      'cpap',
      'bipap',
      'airsense',
      'aircurve',
      'dreamstation',
    ];
    return hints.any((hint) => name.contains(hint));
  }

  Future<void> _autoIdentifyScannedDevices(
    List<BleDeviceCandidate> devices,
  ) async {
    final likely = devices.where(_looksLikeHealthDevice).take(12).toList();
    for (final device in likely) {
      if (!mounted) return;
      if (_bleInspections.containsKey(device.id)) continue;
      setState(() => _inspecting.add(device.id));
      try {
        final inspection = await _bleDiscovery.inspect(device);
        if (!mounted) return;
        setState(() => _bleInspections[device.id] = inspection);
        if (_savedDirectDevices.any((saved) => saved.id == device.id)) {
          await _directDeviceStore.refreshInspection(
            device: device,
            inspection: inspection,
          );
          await _loadSavedDirectDevices();
        }
      } catch (_) {
        // Keep the scan result. A device that does not answer GATT inspection
        // is not promoted to a health device just because it was nearby.
      } finally {
        if (mounted) setState(() => _inspecting.remove(device.id));
      }
    }
  }

'''
    if anchor not in text:
        fail('scan method anchor missing')
    text = text.replace(anchor, helpers + anchor, 1)

# Replace scan body with scan + auto-identify.
old = r'''    try {
      final devices = await _bleDiscovery.scan();
      if (!mounted) return;
      setState(() => _bleDevices = devices);
    } catch (error) {
'''
new = r'''    try {
      final devices = await _bleDiscovery.scan();
      if (!mounted) return;
      setState(() => _bleDevices = devices);
      await _autoIdentifyScannedDevices(devices);
    } catch (error) {
'''
if new not in text:
    if old not in text:
        fail('scan result anchor missing')
    text = text.replace(old, new, 1)

# More accurate button copy while scan + identify runs.
text = text.replace(
    "_scanningBle ? 'Scanning for 8 seconds…' : 'Scan for devices',",
    "_scanningBle ? 'Scanning & identifying…' : 'Scan for devices',",
)

# Split the scan list into actual health candidates and other Bluetooth devices.
old = r'''  Widget _bluetoothCard(List<HealthyDataSource> sources) {
    return CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
'''
new = r'''  Widget _bluetoothCard(List<HealthyDataSource> sources) {
    final healthSources = sources
        .where(SourceHubService.isBluetoothHealthCandidate)
        .toList();
    final otherSources = sources
        .where((source) => !SourceHubService.isBluetoothHealthCandidate(source))
        .toList();

    return CommandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
'''
if new not in text:
    if old not in text:
        fail('Bluetooth card start anchor missing')
    text = text.replace(old, new, 1)

# Empty-state should be based on raw scan sources, not healthSources.
# Replace the main device loop and add a collapsed other-device section.
old = r'''          if (sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final source in sources.take(20))
              _BleSourceRow(
                source: source,
                device: _bleDevices.firstWhere(
                  (device) => source.id == 'ble:${device.id}',
                ),
                inspection: _bleInspections[
                  source.id.replaceFirst('ble:', '')
                ],
                inspecting: _inspecting.contains(
                  source.id.replaceFirst('ble:', ''),
                ),
                onInspect: () => _inspectBluetooth(
                  _bleDevices.firstWhere(
                    (device) => source.id == 'ble:${device.id}',
                  ),
                ),
                saved: _savedDirectDevices.any(
                  (saved) => saved.id == source.id.replaceFirst('ble:', ''),
                ),
                pairing: _pairing.contains(
                  source.id.replaceFirst('ble:', ''),
                ),
                onUse: () => _useWithSalus(
                  _bleDevices.firstWhere(
                    (device) => source.id == 'ble:${device.id}',
                  ),
                ),
                reading: _readingDirect.contains(
                  source.id.replaceFirst('ble:', ''),
                ),
                readSummary: _directReadSummary[
                  source.id.replaceFirst('ble:', '')
                ],
                onRead: () => _readDirectMetrics(
                  _bleDevices.firstWhere(
                    (device) => source.id == 'ble:${device.id}',
                  ),
                ),
              ),
          ],
'''
new = r'''          if (healthSources.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Health devices',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            for (final source in healthSources.take(20))
              _BleSourceRow(
                source: source,
                device: _bleDevices.firstWhere(
                  (device) => source.id == 'ble:${device.id}',
                ),
                inspection: _bleInspections[
                  source.id.replaceFirst('ble:', '')
                ],
                inspecting: _inspecting.contains(
                  source.id.replaceFirst('ble:', ''),
                ),
                onInspect: () => _inspectBluetooth(
                  _bleDevices.firstWhere(
                    (device) => source.id == 'ble:${device.id}',
                  ),
                ),
                saved: _savedDirectDevices.any(
                  (saved) => saved.id == source.id.replaceFirst('ble:', ''),
                ),
                pairing: _pairing.contains(
                  source.id.replaceFirst('ble:', ''),
                ),
                onUse: () => _useWithSalus(
                  _bleDevices.firstWhere(
                    (device) => source.id == 'ble:${device.id}',
                  ),
                ),
                reading: _readingDirect.contains(
                  source.id.replaceFirst('ble:', ''),
                ),
                readSummary: _directReadSummary[
                  source.id.replaceFirst('ble:', '')
                ],
                onRead: () => _readDirectMetrics(
                  _bleDevices.firstWhere(
                    (device) => source.id == 'ble:${device.id}',
                  ),
                ),
                healthCandidate: true,
              ),
          ],
          if (otherSources.isNotEmpty) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Other Bluetooth devices (${otherSources.length})',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'Nearby devices not identified as health hardware',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11.5,
                ),
              ),
              children: [
                for (final source in otherSources.take(20))
                  _BleSourceRow(
                    source: source,
                    device: _bleDevices.firstWhere(
                      (device) => source.id == 'ble:${device.id}',
                    ),
                    inspection: _bleInspections[
                      source.id.replaceFirst('ble:', '')
                    ],
                    inspecting: _inspecting.contains(
                      source.id.replaceFirst('ble:', ''),
                    ),
                    onInspect: () => _inspectBluetooth(
                      _bleDevices.firstWhere(
                        (device) => source.id == 'ble:${device.id}',
                      ),
                    ),
                    saved: _savedDirectDevices.any(
                      (saved) => saved.id == source.id.replaceFirst('ble:', ''),
                    ),
                    pairing: _pairing.contains(
                      source.id.replaceFirst('ble:', ''),
                    ),
                    onUse: () => _useWithSalus(
                      _bleDevices.firstWhere(
                        (device) => source.id == 'ble:${device.id}',
                      ),
                    ),
                    reading: _readingDirect.contains(
                      source.id.replaceFirst('ble:', ''),
                    ),
                    readSummary: _directReadSummary[
                      source.id.replaceFirst('ble:', '')
                    ],
                    onRead: () => _readDirectMetrics(
                      _bleDevices.firstWhere(
                        (device) => source.id == 'ble:${device.id}',
                      ),
                    ),
                    healthCandidate: false,
                  ),
              ],
            ),
          ],
'''
if new not in text:
    if old not in text:
        fail('Bluetooth source loop anchor missing')
    text = text.replace(old, new, 1)

# Add healthCandidate to BLE row.
old = r'''  final VoidCallback onRead;

  const _BleSourceRow({
'''
new = r'''  final VoidCallback onRead;
  final bool healthCandidate;

  const _BleSourceRow({
'''
if new not in text:
    if old not in text:
        fail('BLE row field anchor missing')
    text = text.replace(old, new, 1)

old = r'''    required this.onRead,
  });
'''
new = r'''    required this.onRead,
    this.healthCandidate = true,
  });
'''
if new not in text:
    if old not in text:
        fail('BLE row constructor anchor missing')
    text = text.replace(old, new, 1)

# Unknown devices should not offer Pair until Identify proves health relevance.
old = r'''                if (!saved)
                  FilledButton.tonalIcon(
                    onPressed: pairing ? null : onUse,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: Text(pairing ? 'Pairing…' : 'Pair'),
                  )
                else
                  FilledButton.tonalIcon(
'''
new = r'''                if (!saved && healthCandidate)
                  FilledButton.tonalIcon(
                    onPressed: pairing ? null : onUse,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: Text(pairing ? 'Pairing…' : 'Pair'),
                  )
                else if (saved)
                  FilledButton.tonalIcon(
'''
if new not in text:
    if old not in text:
        fail('BLE row Pair action anchor missing')
    text = text.replace(old, new, 1)

# Unknown nearby hardware gets neutral explanatory copy.
old = r'''                        saved
                            ? 'Paired with Salus • ${device.bondState} • Read data to sync'
                            : inspection == null
                                ? 'Detected nearby • ${device.bondState}'
                                : source.note ?? 'Bluetooth services identified',
'''
new = r'''                        saved
                            ? 'Paired with Salus • ${device.bondState} • Read data to sync'
                            : !healthCandidate
                                ? 'Nearby Bluetooth device • not identified as health hardware'
                                : inspection == null
                                    ? 'Detected nearby • ${device.bondState}'
                                    : source.note ?? 'Health services identified',
'''
if new not in text:
    if old not in text:
        fail('BLE row status copy anchor missing')
    text = text.replace(old, new, 1)

path.write_text(text)


# ---------------------------------------------------------------------------
# Build 27 intentionally changed named ring behavior. Update the old regression
# expectation so CI checks the behavior the user actually requested.
# ---------------------------------------------------------------------------
path = Path('test/source_hub_service_test.dart')
text = path.read_text()
old = "expect(sources.single.label, 'Smart ring');"
new = "expect(sources.single.label, 'R02_TEST');"
if new not in text:
    if old not in text:
        fail('stale Smart ring test anchor missing')
    text = text.replace(old, new, 1)
path.write_text(text)

# The generic standard-HR device is now described precisely as a heart-rate
# sensor instead of the vague "Health sensor". Keep the original manufacturer-
# independent behavior test, but update its expected label.
path = Path('test/ble_protocol_profiles_test.dart')
text = path.read_text()
old = "expect(report.deviceKind, 'Health sensor');"
new = "expect(report.deviceKind, 'Heart-rate sensor');"
if new not in text:
    if old not in text:
        fail('stale standard-HR device-kind test anchor missing')
    text = text.replace(old, new, 1)
path.write_text(text)

print('Salus build 29 Bluetooth scan classification + auto-identify patch applied.')
