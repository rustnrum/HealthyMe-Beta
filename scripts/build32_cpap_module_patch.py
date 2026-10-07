from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 32 CPAP module patch: {message}')


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        fail(f'{label} anchor missing in {path}')
    path.write_text(text.replace(old, new, 1))


# ---------------------------------------------------------------------------
# Device identity: strong CPAP identity must win over generic UART services.
# Nordic UART is transport, not proof that a device is a QRing.
# ---------------------------------------------------------------------------
profiles = Path('lib/services/ble_protocol_profiles.dart')
text = profiles.read_text()
helper_anchor = """  static String normalizeUuid(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.length == 4) return '0000$value$bluetoothBaseSuffix';
    if (value.length == 8) return '$value$bluetoothBaseSuffix';
    return value;
  }

"""
helper_block = helper_anchor + """  static bool looksLikeCpapName(String name) {
    final value = name.trim().toLowerCase();
    const hints = <String>[
      'resmed',
      'airsense',
      'aircurve',
      'dreamstation',
      'cpap',
      'bipap',
      'bpap',
      'prisma',
      'luna g3',
    ];
    return hints.any(value.contains);
  }

  static bool looksLikeRingName(String name) {
    final value = name.trim().toLowerCase();
    const hints = <String>[
      'colmi',
      'qring',
      'yawell',
      'r02',
      'r03',
      'r06',
      'smart ring',
    ];
    return hints.any(value.contains);
  }

"""
if 'static bool looksLikeCpapName' not in text:
    if helper_anchor not in text:
        fail('BLE identity helper anchor missing')
    text = text.replace(helper_anchor, helper_block, 1)

old_match = """    BleProtocolProfile? matched;
    for (final profile in profiles) {
      if (profile.matches(name, services)) {
        matched = profile;
        break;
      }
    }

    return BleCapabilityReport(
"""
new_match = """    BleProtocolProfile? matched;
    final cpapProfile =
        profiles.firstWhere((profile) => profile.id == 'cpap-family');
    final ringProfile =
        profiles.firstWhere((profile) => profile.id == 'ring-uart-v1');

    final strongCpapIdentity = looksLikeCpapName(name) ||
        cpapProfile.anyServices.any(services.contains);
    final strongRingIdentity = looksLikeRingName(name) ||
        (services.contains(ringUartService) &&
            services.contains(ringBigDataService));

    if (strongCpapIdentity) {
      matched = cpapProfile;
    } else if (strongRingIdentity) {
      matched = ringProfile;
    } else {
      for (final profile in profiles) {
        if (profile.id == 'cpap-family' || profile.id == 'ring-uart-v1') {
          continue;
        }
        if (profile.matches(name, services)) {
          matched = profile;
          break;
        }
      }
    }

    return BleCapabilityReport(
"""
if 'final strongCpapIdentity = looksLikeCpapName(name)' not in text:
    if old_match not in text:
        fail('BLE prioritized matcher anchor missing')
    text = text.replace(old_match, new_match, 1)
profiles.write_text(text)


# ---------------------------------------------------------------------------
# Saved-device migration: a previously misclassified ResMed should repair
# itself when Build 32 loads it, even before the user removes/re-pairs it.
# ---------------------------------------------------------------------------
store = Path('lib/services/direct_device_store.dart')
text = store.read_text()
if "import 'ble_protocol_profiles.dart';" not in text:
    anchor = "import 'ble_discovery_service.dart';\n"
    if anchor not in text:
        fail('direct-device import anchor missing')
    text = text.replace(anchor, anchor + "import 'ble_protocol_profiles.dart';\n", 1)

old_factory = """  factory SavedDirectDevice.fromJson(Map<String, dynamic> json) =>
      SavedDirectDevice(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Bluetooth device',
        deviceKind: json['deviceKind']?.toString() ?? 'Bluetooth health device',
        protocolId: json['protocolId']?.toString(),
        protocolLabel: json['protocolLabel']?.toString(),
        capabilities: json['protocolId']?.toString() == 'cpap-family'
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
        bonded: json['bonded'] == true,
        pairState: json['pairState']?.toString() ?? 'direct',
        savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
"""
new_factory = """  factory SavedDirectDevice.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'Bluetooth device';
    final storedProtocol = json['protocolId']?.toString();
    final cpapIdentity = storedProtocol == 'cpap-family' ||
        BleProtocolProfiles.looksLikeCpapName(name);
    return SavedDirectDevice(
      id: json['id']?.toString() ?? '',
      name: name,
      deviceKind: cpapIdentity
          ? 'CPAP / respiratory'
          : json['deviceKind']?.toString() ?? 'Bluetooth health device',
      protocolId: cpapIdentity ? 'cpap-family' : storedProtocol,
      protocolLabel: cpapIdentity
          ? 'Respiratory / CPAP device'
          : json['protocolLabel']?.toString(),
      capabilities: cpapIdentity
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
      bonded: json['bonded'] == true,
      pairState: json['pairState']?.toString() ?? 'direct',
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
"""
if 'final cpapIdentity = storedProtocol == ' not in text:
    if old_factory not in text:
        fail('saved-device migration factory anchor missing')
    text = text.replace(old_factory, new_factory, 1)

save_anchor = """  }) async {
    final devices = await load();
    final next = SavedDirectDevice(
      id: device.id,
      name: device.name,
      deviceKind: inspection?.deviceKind ?? device.deviceKind,
      protocolId: inspection?.protocolId ?? device.protocolId,
      protocolLabel: inspection?.protocolProfile ?? device.protocolProfile,
      capabilities: inspection?.capabilities ?? device.capabilities,
"""
save_new = """  }) async {
    final devices = await load();
    final cpapIdentity = BleProtocolProfiles.looksLikeCpapName(device.name) ||
        inspection?.protocolId == 'cpap-family' ||
        device.protocolId == 'cpap-family';
    final next = SavedDirectDevice(
      id: device.id,
      name: device.name,
      deviceKind: cpapIdentity
          ? 'CPAP / respiratory'
          : inspection?.deviceKind ?? device.deviceKind,
      protocolId: cpapIdentity
          ? 'cpap-family'
          : inspection?.protocolId ?? device.protocolId,
      protocolLabel: cpapIdentity
          ? 'Respiratory / CPAP device'
          : inspection?.protocolProfile ?? device.protocolProfile,
      capabilities: cpapIdentity
          ? const [
              'Usage time',
              'AHI',
              'Leak rate',
              'Therapy pressure',
              'Mask on/off',
            ]
          : inspection?.capabilities ?? device.capabilities,
"""
if 'final cpapIdentity = BleProtocolProfiles.looksLikeCpapName(device.name)' not in text:
    if save_anchor not in text:
        fail('saved-device save normalization anchor missing')
    text = text.replace(save_anchor, save_new, 1)

refresh_anchor = """    if (existing == null) return;

    final next = SavedDirectDevice(
      id: existing.id,
      name: device.name,
      deviceKind: inspection.deviceKind,
      protocolId: inspection.protocolId,
      protocolLabel: inspection.protocolProfile,
      capabilities: inspection.capabilities,
"""
refresh_new = """    if (existing == null) return;

    final cpapIdentity = BleProtocolProfiles.looksLikeCpapName(device.name) ||
        inspection.protocolId == 'cpap-family' ||
        existing.protocolId == 'cpap-family';
    final next = SavedDirectDevice(
      id: existing.id,
      name: device.name,
      deviceKind:
          cpapIdentity ? 'CPAP / respiratory' : inspection.deviceKind,
      protocolId: cpapIdentity ? 'cpap-family' : inspection.protocolId,
      protocolLabel: cpapIdentity
          ? 'Respiratory / CPAP device'
          : inspection.protocolProfile,
      capabilities: cpapIdentity
          ? const [
              'Usage time',
              'AHI',
              'Leak rate',
              'Therapy pressure',
              'Mask on/off',
            ]
          : inspection.capabilities,
"""
if 'existing.protocolId == ' not in text:
    if refresh_anchor not in text:
        fail('saved-device refresh normalization anchor missing')
    text = text.replace(refresh_anchor, refresh_new, 1)
store.write_text(text)


# ---------------------------------------------------------------------------
# Register saved direct devices as providers before they have readable records.
# They are visible providers, but SourceHub keeps them unselectable until data
# exists so choosing a source can never manufacture a value.
# ---------------------------------------------------------------------------
direct = Path('lib/services/direct_metric_service.dart')
text = direct.read_text()
if "import 'direct_device_store.dart';" not in text:
    anchor = "import 'ble_discovery_service.dart';\n"
    if anchor not in text:
        fail('direct metric import anchor missing')
    text = text.replace(anchor, anchor + "import 'direct_device_store.dart';\n", 1)

for old, new in [
    ("        'Active calories' => ' kcal',\n", "        'Active calories' => ' kcal',\n        'Usage time' => ' min',\n        'AHI' => ' events/hour',\n        'Leak rate' => ' L/min',\n        'Therapy pressure' => ' cmH₂O',\n"),
    ("        'Active calories' => 'kcal',\n", "        'Active calories' => 'kcal',\n        'Usage time' => 'min',\n        'AHI' => 'events/hour',\n        'Leak rate' => 'L/min',\n        'Therapy pressure' => 'cmH₂O',\n        'Mask on/off' => 'state',\n"),
]:
    if new not in text:
        if old not in text:
            fail('direct metric CPAP unit anchor missing')
        text = text.replace(old, new, 1)

preferred_anchor = """      'Respiratory rate',
      'Battery',
"""
preferred_new = """      'Respiratory rate',
      'Usage time',
      'AHI',
      'Leak rate',
      'Therapy pressure',
      'Battery',
"""
if "      'Usage time',\n      'AHI',\n      'Leak rate'," not in text.split('String get summary', 1)[1].split('];', 1)[0]:
    if preferred_anchor not in text:
        fail('direct metric summary preference anchor missing')
    text = text.replace(preferred_anchor, preferred_new, 1)

signature_old = """  HealthSnapshot mergeIntoSnapshot(
    HealthSnapshot base, {
    required Map<String, String> metricSources,
    required List<DirectMetricSample> samples,
  }) {
"""
signature_new = """  HealthSnapshot mergeIntoSnapshot(
    HealthSnapshot base, {
    required Map<String, String> metricSources,
    required List<DirectMetricSample> samples,
    List<SavedDirectDevice> registeredDevices = const [],
  }) {
"""
if 'List<SavedDirectDevice> registeredDevices = const []' not in text:
    if signature_old not in text:
        fail('direct provider registry signature anchor missing')
    text = text.replace(signature_old, signature_new, 1)

registry_anchor = """    final freshness = <String, DateTime>{...base.freshness};

    final direct = samples
"""
registry_new = """    final freshness = <String, DateTime>{...base.freshness};

    for (final device in registeredDevices) {
      final sourceId = 'ble:${device.id}';
      detected.add(sourceId);
      labels[sourceId] = device.name;

      final providerMetrics = device.protocolId == 'cpap-family'
          ? const [
              'Usage time',
              'AHI',
              'Leak rate',
              'Therapy pressure',
              'Mask on/off',
            ]
          : device.capabilities;
      for (final rawMetric in providerMetrics) {
        final metric = rawMetric == 'SpO₂' ? 'SpO2' : rawMetric;
        if (metric.isEmpty ||
            metric == 'Raw motion' ||
            metric == 'Battery' ||
            metric == 'Device information') {
          continue;
        }
        final sourceList =
            available.putIfAbsent(metric, () => <String>[]);
        if (!sourceList.contains(sourceId)) sourceList.add(sourceId);
        final metricCounts =
            counts.putIfAbsent(metric, () => <String, int>{});
        metricCounts.putIfAbsent(sourceId, () => 0);
      }
    }

    final direct = samples
"""
if "for (final device in registeredDevices)" not in text:
    if registry_anchor not in text:
        fail('direct provider registry insertion anchor missing')
    text = text.replace(registry_anchor, registry_new, 1)
direct.write_text(text)


# ---------------------------------------------------------------------------
# SourceHub: registered direct hardware is visible as a provider, but becomes a
# selectable metric route only after actual records exist.
# ---------------------------------------------------------------------------
hub = Path('lib/services/source_hub_service.dart')
text = hub.read_text()
old = """          selectable: metrics.isNotEmpty,
          lastSeen: health.sourceLastSeen[id],
          note: direct ? 'Read directly from the paired device' : null,
"""
new = """          selectable: metrics.isNotEmpty &&
              (!direct || recordCounts.values.any((count) => count > 0)),
          lastSeen: health.sourceLastSeen[id],
          note: direct
              ? recordCounts.values.any((count) => count > 0)
                  ? 'Read directly from the paired device'
                  : 'Registered direct provider • waiting for readable data'
              : null,
"""
if 'Registered direct provider • waiting for readable data' not in text:
    if old not in text:
        fail('SourceHub provider-selectability anchor missing')
    text = text.replace(old, new, 1)
hub.write_text(text)


# ---------------------------------------------------------------------------
# Connections: provider registration occurs on load; CPAP opens its own module.
# ---------------------------------------------------------------------------
connections = Path('lib/screens/connections_screen.dart')
text = connections.read_text()
load_old = """  Future<void> _loadSaved() async {
    final values = await _store.load();
    if (!mounted) return;
    setState(() => _saved = values);
  }
"""
load_new = """  Future<void> _loadSaved() async {
    final values = await _store.load();
    final samples = await _direct.loadSamples();
    if (!mounted) return;
    setState(() => _saved = values);
    final app = ref.read(appStateProvider);
    final merged = _direct.mergeIntoSnapshot(
      app.health,
      metricSources: app.metricSources,
      samples: samples,
      registeredDevices: values,
    );
    ref.read(appStateProvider.notifier).setHealthSnapshot(merged);
  }
"""
if 'registeredDevices: values' not in text:
    if load_old not in text:
        fail('Connections provider-registration anchor missing')
    text = text.replace(load_old, load_new, 1)

sync_merge_old = """      final merged = _direct.mergeIntoSnapshot(
        app.health,
        metricSources: app.metricSources,
        samples: samples,
      );
"""
sync_merge_new = """      final merged = _direct.mergeIntoSnapshot(
        app.health,
        metricSources: app.metricSources,
        samples: samples,
        registeredDevices: _saved,
      );
"""
if 'registeredDevices: _saved' not in text:
    if sync_merge_old not in text:
        fail('Connections sync merge anchor missing')
    text = text.replace(sync_merge_old, sync_merge_new, 1)

call_old = """                metrics: _displayMetrics(device.capabilities),
                onSync: () => _syncSaved(device),
                onRemove: () => _remove(device),
"""
call_new = """                metrics: _displayMetrics(device.capabilities),
                onSync: () => _syncSaved(device),
                onOpenTherapy: () => Navigator.of(context).pushNamed(
                  '/cpap',
                  arguments: device.id,
                ),
                onRemove: () => _remove(device),
"""
if "arguments: device.id" not in text:
    if call_old not in text:
        fail('Connections CPAP navigation call anchor missing')
    text = text.replace(call_old, call_new, 1)

field_old = """  final List<String> metrics;
  final VoidCallback onSync;
  final VoidCallback onRemove;

  const _SavedDeviceCard({
"""
field_new = """  final List<String> metrics;
  final VoidCallback onSync;
  final VoidCallback onOpenTherapy;
  final VoidCallback onRemove;

  const _SavedDeviceCard({
"""
if 'final VoidCallback onOpenTherapy;' not in text:
    if field_old not in text:
        fail('Connections CPAP callback field anchor missing')
    text = text.replace(field_old, field_new, 1)

ctor_old = """    required this.metrics,
    required this.onSync,
    required this.onRemove,
  });
"""
ctor_new = """    required this.metrics,
    required this.onSync,
    required this.onOpenTherapy,
    required this.onRemove,
  });
"""
if 'required this.onOpenTherapy' not in text:
    if ctor_old not in text:
        fail('Connections CPAP callback constructor anchor missing')
    text = text.replace(ctor_old, ctor_new, 1)

text = text.replace(
    "? 'Connected • CPAP therapy sync pending'",
    "? 'Connected • therapy provider registered'",
)
text = text.replace(
    "'Salus recognizes this as a CPAP. It will not use the wearable heart-rate reader for this device.'",
    "'Registered as the provider for CPAP therapy metrics. Nightly values remain separate from Sleep and Sleep Stages.'",
)
button_old = """            child: OutlinedButton.icon(
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
"""
button_new = """            child: OutlinedButton.icon(
              onPressed: therapyPending
                  ? onOpenTherapy
                  : syncing
                      ? null
                      : onSync,
              icon: therapyPending
                  ? const Icon(Icons.insights_rounded, size: 18)
                  : syncing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                therapyPending
                    ? 'Open CPAP dashboard'
                    : syncing
                        ? 'Syncing…'
                        : 'Sync now',
              ),
            ),
"""
if "? 'Open CPAP dashboard'" not in text:
    if button_old not in text:
        fail('Connections CPAP dashboard button anchor missing')
    text = text.replace(button_old, button_new, 1)

loop_old = """  Future<void> _syncAll() async {
    for (final device in _saved) {
      await _syncSaved(device, showMessage: false);
    }
"""
loop_new = """  Future<void> _syncAll() async {
    for (final device in _saved.where(
      (device) => device.protocolId != 'cpap-family',
    )) {
      await _syncSaved(device, showMessage: false);
    }
"""
if "device.protocolId != 'cpap-family'" not in text:
    if loop_old not in text:
        fail('Connections sync-all CPAP skip anchor missing')
    text = text.replace(loop_old, loop_new, 1)
connections.write_text(text)


# ---------------------------------------------------------------------------
# Debug screen: expose CPAP therapy metrics in the metric registry and preserve
# provider registration whenever direct samples are merged.
# ---------------------------------------------------------------------------
sources = Path('lib/screens/sources_screen.dart')
text = sources.read_text()
metrics_old = """    'Workouts',
  ];
"""
metrics_new = """    'Workouts',
    'Usage time',
    'AHI',
    'Leak rate',
    'Therapy pressure',
    'Mask on/off',
  ];
"""
if "    'Usage time',\n    'AHI'," not in text.split('static const metrics', 1)[1].split('];', 1)[0]:
    if metrics_old not in text:
        fail('debug metric registry anchor missing')
    text = text.replace(metrics_old, metrics_new, 1)

load_saved_old = """  Future<void> _loadSavedDirectDevices() async {
    final devices = await _directDeviceStore.load();
    if (!mounted) return;
    setState(() => _savedDirectDevices = devices);
  }
"""
load_saved_new = """  Future<void> _loadSavedDirectDevices() async {
    final devices = await _directDeviceStore.load();
    final samples = await _directMetricService.loadSamples();
    if (!mounted) return;
    setState(() => _savedDirectDevices = devices);
    final app = ref.read(appStateProvider);
    final merged = _directMetricService.mergeIntoSnapshot(
      app.health,
      metricSources: app.metricSources,
      samples: samples,
      registeredDevices: devices,
    );
    ref.read(appStateProvider.notifier).setHealthSnapshot(merged);
  }
"""
if 'registeredDevices: devices' not in text:
    if load_saved_old not in text:
        fail('debug provider-registration anchor missing')
    text = text.replace(load_saved_old, load_saved_new, 1)

read_merge_old = """      final merged = _directMetricService.mergeIntoSnapshot(
        app.health,
        metricSources: app.metricSources,
        samples: samples,
      );
"""
read_merge_new = """      final merged = _directMetricService.mergeIntoSnapshot(
        app.health,
        metricSources: app.metricSources,
        samples: samples,
        registeredDevices: _savedDirectDevices,
      );
"""
if 'registeredDevices: _savedDirectDevices' not in text:
    if read_merge_old not in text:
        fail('debug direct merge anchor missing')
    text = text.replace(read_merge_old, read_merge_new, 1)
sources.write_text(text)


# ---------------------------------------------------------------------------
# App route and Health landing-page entry point.
# ---------------------------------------------------------------------------
app = Path('lib/app.dart')
text = app.read_text()
if "import 'screens/cpap_screen.dart';" not in text:
    anchor = "import 'screens/connections_screen.dart';\n"
    if anchor not in text:
        fail('app CPAP import anchor missing')
    text = text.replace(anchor, anchor + "import 'screens/cpap_screen.dart';\n", 1)
if "'/cpap': (_) => const CpapScreen()," not in text:
    anchor = "        '/coach': (_) => const AiCoachScreen(),\n"
    if anchor not in text:
        fail('app CPAP route anchor missing')
    text = text.replace(
        anchor,
        "        '/cpap': (_) => const CpapScreen(),\n" + anchor,
        1,
    )
app.write_text(text)

health_home = Path('lib/screens/health/health_home_screen.dart')
text = health_home.read_text()
therapy_entry = """        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/cpap'),
          child: SalusPaper(child: Row(children: [
            Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x2262E8F2)), child: const Icon(Icons.air_rounded, color: AppTheme.cyan, size: 25)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CPAP Therapy', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 3),
              Text('Nightly therapy, 7/30-day trends and Salus insights from your CPAP provider.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.2, height: 1.35)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          ])),
        ),
        const SizedBox(height: 11),
"""
if "Text('CPAP Therapy'" not in text:
    anchor = """        const SizedBox(height: 11),
        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.science_outlined, color: AppTheme.mint, size: 28), SizedBox(width: 10), Text('Bloodwork', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700))]),
"""
    if anchor not in text:
        fail('Health home CPAP entry anchor missing')
    text = text.replace(
        anchor,
        "        const SizedBox(height: 11),\n" + therapy_entry +
        "        SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n"
        "          const Row(children: [Icon(Icons.science_outlined, color: AppTheme.mint, size: 28), SizedBox(width: 10), Text('Bloodwork', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700))]),\n",
        1,
    )
health_home.write_text(text)

print('Salus build 32 CPAP identity/provider/dashboard patch applied.')
