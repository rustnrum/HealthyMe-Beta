from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 23 direct-device patch: {message}')


def replace_once(path_name: str, old: str, new: str, label: str) -> None:
    path = Path(path_name)
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        fail(f'{path_name} anchor missing for {label}')
    path.write_text(text.replace(old, new, 1))


path = Path('lib/screens/sources_screen.dart')
if not path.exists():
    fail('sources_screen.dart missing')
text = path.read_text()

if (
    'class _SavedDirectDeviceRow extends StatelessWidget' in text
    and 'Use with Salus' in text
    and 'final _directDeviceStore = DirectDeviceStore();' in text
):
    print('Salus build 23 direct-device Sources UI already present.')
    raise SystemExit(0)

# Direct-device registry import.
import_anchor = "import '../services/ble_discovery_service.dart';\n"
import_line = "import '../services/direct_device_store.dart';\n"
if import_line not in text:
    if import_anchor not in text:
        fail('BLE import anchor missing')
    text = text.replace(import_anchor, import_anchor + import_line, 1)

# Persistent direct-device state.
old_fields = '''  final _bleDiscovery = BleDiscoveryService();
  List<BleDeviceCandidate> _bleDevices = const [];
  final Map<String, BleDeviceInspection> _bleInspections = {};
  final Set<String> _inspecting = {};
  bool _scanningBle = false;
  String? _bleError;
'''
new_fields = '''  final _bleDiscovery = BleDiscoveryService();
  final _directDeviceStore = DirectDeviceStore();
  List<BleDeviceCandidate> _bleDevices = const [];
  List<SavedDirectDevice> _savedDirectDevices = const [];
  final Map<String, BleDeviceInspection> _bleInspections = {};
  final Set<String> _inspecting = {};
  final Set<String> _pairing = {};
  bool _scanningBle = false;
  String? _bleError;
'''
if old_fields in text:
    text = text.replace(old_fields, new_fields, 1)
elif 'final _directDeviceStore = DirectDeviceStore();' not in text:
    fail('direct-device state field anchor missing')

# Load saved direct devices on screen creation.
old_init = '''  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
'''
new_init = '''  void initState() {
    super.initState();
    _loadSavedDirectDevices();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
'''
if old_init in text:
    text = text.replace(old_init, new_init, 1)
elif '_loadSavedDirectDevices();' not in text:
    fail('initState anchor missing')

# Add save/pair/remove operations immediately before BLE scan.
scan_anchor = '''  Future<void> _scanBluetooth() async {
'''
methods = '''  Future<void> _loadSavedDirectDevices() async {
    final devices = await _directDeviceStore.load();
    if (!mounted) return;
    setState(() => _savedDirectDevices = devices);
  }

  Future<void> _useWithSalus(BleDeviceCandidate device) async {
    if (_pairing.contains(device.id)) return;
    setState(() => _pairing.add(device.id));

    try {
      final pair = await _bleDiscovery.pair(device);
      BleDeviceInspection? inspection = _bleInspections[device.id];
      try {
        final resolvedInspection =
            inspection ?? await _bleDiscovery.inspect(device);
        inspection = resolvedInspection;
        if (mounted) {
          setState(() => _bleInspections[device.id] = resolvedInspection);
        }
      } catch (_) {
        // Some devices expose services only after protocol-specific
        // authentication. Saving the device still lets Salus retry later.
      }

      await _directDeviceStore.save(
        device: device,
        inspection: inspection,
        pair: pair,
      );
      await _loadSavedDirectDevices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pair.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save ${device.name}: $error')),
      );
    } finally {
      if (mounted) setState(() => _pairing.remove(device.id));
    }
  }

  Future<void> _removeSavedDirectDevice(String id) async {
    await _directDeviceStore.remove(id);
    await _loadSavedDirectDevices();
  }

'''
if methods not in text:
    if scan_anchor not in text:
        fail('scanBluetooth method anchor missing')
    text = text.replace(scan_anchor, methods + scan_anchor, 1)

# Reframe Bluetooth as direct device pairing rather than identification only.
text = text.replace(
    "          const HmSectionHeader(title: 'Nearby devices'),",
    "          const HmSectionHeader(title: 'Pair direct devices'),",
    1,
)
old_explainer = '''          const Text(
            'Bluetooth is used to identify devices and capabilities. A device is '
            'not selectable as a metric source until Salus can actually read '
            'that metric from it.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          _bluetoothCard(bluetoothSources),
'''
new_explainer = '''          const Text(
            'Salus can scan, inspect, pair and remember Bluetooth health devices '
            'without their vendor app. Known protocol families and standard BLE '
            'health services are identified automatically; metric readers are '
            'enabled only when Salus can actually decode that device.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (_savedDirectDevices.isNotEmpty) ...[
            const SizedBox(height: 10),
            _savedDirectDevicesCard(),
          ],
          const SizedBox(height: 10),
          _bluetoothCard(bluetoothSources),
'''
if old_explainer in text:
    text = text.replace(old_explainer, new_explainer, 1)
elif 'Salus can scan, inspect, pair and remember Bluetooth health devices' not in text:
    fail('Bluetooth explainer anchor missing')

# Add saved-device card before scan results card.
bluetooth_card_anchor = '''  Widget _bluetoothCard(List<HealthyDataSource> sources) {
'''
saved_card = '''  Widget _savedDirectDevicesCard() {
    return CommandCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 8, 0, 3),
            child: Text(
              'Saved direct devices',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (var i = 0; i < _savedDirectDevices.length; i++) ...[
            _SavedDirectDeviceRow(
              device: _savedDirectDevices[i],
              onRemove: () => _removeSavedDirectDevice(
                _savedDirectDevices[i].id,
              ),
            ),
            if (i != _savedDirectDevices.length - 1)
              const Divider(height: 1),
          ],
        ],
      ),
    );
  }

'''
if saved_card not in text:
    if bluetooth_card_anchor not in text:
        fail('bluetoothCard anchor missing')
    text = text.replace(bluetooth_card_anchor, saved_card + bluetooth_card_anchor, 1)

# Extend BLE result rows with direct-save/pair state.
old_row_tail = '''                onInspect: () => _inspectBluetooth(
                  _bleDevices.firstWhere(
                    (device) => source.id == 'ble:${device.id}',
                  ),
                ),
              ),
'''
new_row_tail = '''                onInspect: () => _inspectBluetooth(
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
              ),
'''
if old_row_tail in text:
    text = text.replace(old_row_tail, new_row_tail, 1)
elif 'saved: _savedDirectDevices.any(' not in text:
    fail('BLE result row constructor anchor missing')

# Replace BLE result presentation and add saved-device presentation.
class_start = text.find('class _BleSourceRow extends StatelessWidget {')
class_end = text.find('class _DiagnosticText extends StatelessWidget {', class_start)
if class_start < 0 or class_end < 0:
    fail('BLE source row class markers missing')
new_classes = r'''class _SavedDirectDeviceRow extends StatelessWidget {
  final SavedDirectDevice device;
  final VoidCallback onRemove;

  const _SavedDirectDeviceRow({
    required this.device,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_deviceIcon(device.deviceKind), color: AppTheme.mint, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.deviceKind} • ${device.bonded ? 'Android bonded' : 'Direct GATT'}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (device.protocolLabel != null)
                  Text(
                    device.protocolLabel!,
                    style: const TextStyle(
                      color: AppTheme.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (device.capabilities.isNotEmpty)
                  Text(
                    device.capabilities.join(' • '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onRemove, child: const Text('Remove')),
        ],
      ),
    );
  }
}

class _BleSourceRow extends StatelessWidget {
  final HealthyDataSource source;
  final BleDeviceCandidate device;
  final BleDeviceInspection? inspection;
  final bool inspecting;
  final bool saved;
  final bool pairing;
  final VoidCallback onInspect;
  final VoidCallback onUse;

  const _BleSourceRow({
    required this.source,
    required this.device,
    required this.inspection,
    required this.inspecting,
    required this.saved,
    required this.pairing,
    required this.onInspect,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final capabilities = source.metrics;
    final protocol = inspection?.protocolProfile ?? device.protocolProfile;
    final kind = inspection?.deviceKind ?? device.deviceKind;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: saved ? AppTheme.mint : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_deviceIcon(kind), color: saved ? AppTheme.mint : AppTheme.blue),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.label,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        protocol == null ? kind : '$kind • $protocol',
                        style: const TextStyle(
                          color: AppTheme.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        inspection == null
                            ? 'Detected nearby • Android ${device.bondState}'
                            : source.note ?? 'Bluetooth services identified',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (capabilities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Detected/potential: ${capabilities.join(' • ')}',
                style: const TextStyle(
                  color: AppTheme.mint,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: inspecting ? null : onInspect,
                  child: Text(
                    inspecting
                        ? 'Identifying…'
                        : inspection == null
                            ? 'Identify'
                            : 'Identify again',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: saved || pairing ? null : onUse,
                  icon: Icon(saved ? Icons.check_rounded : Icons.link_rounded, size: 18),
                  label: Text(
                    saved
                        ? 'Saved to Salus'
                        : pairing
                            ? 'Pairing…'
                            : 'Use with Salus',
                  ),
                ),
              ],
            ),
          ),
          if (inspection != null)
            ExpansionTile(
              dense: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: const Text(
                'Advanced diagnostics',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              children: [
                _DiagnosticText('Address', device.id),
                _DiagnosticText('Device class', kind),
                _DiagnosticText('Android bond', device.bondState),
                _DiagnosticText('Signal', '${device.rssi} dBm'),
                if (protocol != null) _DiagnosticText('Protocol family', protocol),
                if (device.advertisedServices.isNotEmpty)
                  _DiagnosticText(
                    'Advertised services',
                    device.advertisedServices.join(', '),
                  ),
                if (device.manufacturerDataHex.isNotEmpty)
                  _DiagnosticText(
                    'Manufacturer bytes',
                    device.manufacturerDataHex,
                  ),
                for (final service in inspection!.services)
                  _DiagnosticText(
                    service.serviceUuid,
                    service.characteristicDetails.join('\n'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

IconData _deviceIcon(String kind) {
  final value = kind.toLowerCase();
  if (value.contains('ring')) return Icons.circle_outlined;
  if (value.contains('scale')) return Icons.monitor_weight_outlined;
  if (value.contains('cpap') || value.contains('respiratory')) return Icons.air_rounded;
  if (value.contains('watch') || value.contains('band')) return Icons.watch_outlined;
  if (value.contains('blood pressure')) return Icons.favorite_border_rounded;
  return Icons.bluetooth_rounded;
}

'''
text = text[:class_start] + new_classes + text[class_end:]

path.write_text(text)
print('Salus build 23 direct-device Sources UI applied.')
