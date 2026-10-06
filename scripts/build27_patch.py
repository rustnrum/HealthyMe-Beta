from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 27 patch: {message}')


# Garmin was incorrectly called Smart ring whenever its potential capability
# list happened to look ring-like. Identity must come from protocol/kind.
path = Path('lib/services/source_hub_service.dart')
text = path.read_text()
if "protocolId == 'ring-uart-v1'" not in text:
    old = '''      final profile = inspection?.protocolProfile ?? device.protocolProfile;
      final identifiedAsRing = profile != null &&
          (capabilities.contains('Sleep') ||
              capabilities.contains('Steps')) &&
          (capabilities.contains('Heart rate') ||
              capabilities.contains('SpO2'));

      final rawName = device.name.trim();
      final label = identifiedAsRing
'''
    new = '''      final profile = inspection?.protocolProfile ?? device.protocolProfile;
      final protocolId = inspection?.protocolId ?? device.protocolId;
      final kind = inspection?.deviceKind ?? device.deviceKind;
      final identifiedAsRing =
          protocolId == 'ring-uart-v1' ||
          kind.toLowerCase().contains('ring');

      final rawName = device.name.trim();
      final label = identifiedAsRing
'''
    if old not in text:
        fail('source-hub ring identity anchor missing')
    text = text.replace(old, new, 1)
    path.write_text(text)

# Preserve a real advertised device name. Only unnamed rings get the generic
# Smart ring label.
path = Path('lib/services/source_hub_service.dart')
text = path.read_text()
old_label = '''      final rawName = device.name.trim();
      final label = identifiedAsRing
          ? 'Smart ring'
          : rawName.isEmpty || rawName == 'Unnamed BLE device'
              ? 'Bluetooth device'
              : rawName;
'''
new_label = '''      final rawName = device.name.trim();
      final unnamed = rawName.isEmpty || rawName == 'Unnamed BLE device';
      final label = unnamed
          ? (identifiedAsRing ? 'Smart ring' : 'Bluetooth device')
          : rawName;
'''
if new_label not in text:
    if old_label not in text:
        fail('source-hub label anchor missing')
    text = text.replace(old_label, new_label, 1)
    path.write_text(text)


# Once an inspection identifies a previously saved device, persist the better
# kind/protocol/capability information instead of leaving "Health sensor".
path = Path('lib/services/direct_device_store.dart')
text = path.read_text()
if 'Future<void> refreshInspection' not in text:
    anchor = '''  Future<void> remove(String id) async {
'''
    method = '''  Future<void> refreshInspection({
    required BleDeviceCandidate device,
    required BleDeviceInspection inspection,
  }) async {
    final devices = await load();
    SavedDirectDevice? existing;
    for (final item in devices) {
      if (item.id == device.id) {
        existing = item;
        break;
      }
    }
    if (existing == null) return;

    final next = SavedDirectDevice(
      id: existing.id,
      name: device.name,
      deviceKind: inspection.deviceKind,
      protocolId: inspection.protocolId,
      protocolLabel: inspection.protocolProfile,
      capabilities: inspection.capabilities,
      bonded: existing.bonded,
      pairState: existing.pairState,
      savedAt: existing.savedAt,
    );

    await _write([
      for (final item in devices)
        if (item.id != device.id) item,
      next,
    ]);
  }

'''
    if anchor not in text:
        fail('direct-device store remove anchor missing')
    text = text.replace(anchor, method + anchor, 1)
    path.write_text(text)


# Identify and Read data should refresh persisted device metadata.
path = Path('lib/screens/sources_screen.dart')
text = path.read_text()

old = '''      final inspection = await _bleDiscovery.inspect(device);
      if (!mounted) return;
      setState(() => _bleInspections[device.id] = inspection);
'''
new = '''      final inspection = await _bleDiscovery.inspect(device);
      if (!mounted) return;
      setState(() => _bleInspections[device.id] = inspection);
      if (_savedDirectDevices.any((saved) => saved.id == device.id)) {
        await _directDeviceStore.refreshInspection(
          device: device,
          inspection: inspection,
        );
        await _loadSavedDirectDevices();
      }
'''
if new not in text:
    if old not in text:
        fail('Sources inspect completion anchor missing')
    text = text.replace(old, new, 1)

old = '''    try {
      final result = await _directMetricService.readAndStore(device);
      final samples = await _directMetricService.loadSamples();
'''
new = '''    try {
      if (!_bleInspections.containsKey(device.id)) {
        try {
          final inspection = await _bleDiscovery.inspect(device);
          if (mounted) {
            setState(() => _bleInspections[device.id] = inspection);
          }
          if (_savedDirectDevices.any((saved) => saved.id == device.id)) {
            await _directDeviceStore.refreshInspection(
              device: device,
              inspection: inspection,
            );
            await _loadSavedDirectDevices();
          }
        } catch (_) {
          // The native reader independently identifies the full GATT service
          // family, so a UI inspection failure does not block the read.
        }
      }

      final result = await _directMetricService.readAndStore(device);
      final samples = await _directMetricService.loadSamples();
'''
if new not in text:
    if old not in text:
        fail('Sources direct-read anchor missing')
    text = text.replace(old, new, 1)

text = text.replace(
    "'Paired with Salus • ${device.bondState}'",
    "'Paired with Salus • ${device.bondState} • Read data to sync'",
)

path.write_text(text)

print('Salus build 27 device identity + protocol-read UI patch applied.')
