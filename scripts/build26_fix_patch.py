from pathlib import Path
import re


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 26 patch: {message}')


def replace_once(path_name: str, old: str, new: str, label: str) -> None:
    path = Path(path_name)
    if not path.exists():
        fail(f'missing {path_name} for {label}')
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        fail(f'anchor missing in {path_name} for {label}')
    path.write_text(text.replace(old, new, 1))


# --- Source hub: stale Health Connect ghosts + real direct transport -----------
path = Path('lib/services/source_hub_service.dart')
text = path.read_text()
if 'SALUS_BUILD26_ACTIVE_SOURCES' not in text:
    old = '''      result.add(
        HealthyDataSource(
          id: id,
          label: health.sourceLabels[id] ?? SourceNameService.friendly(id),
          transport: SourceTransport.healthConnect,
          metrics: metrics,
          recordCounts: recordCounts,
          selectable: metrics.isNotEmpty,
          lastSeen: health.sourceLastSeen[id],
        ),
      );
'''
    new = '''      // SALUS_BUILD26_ACTIVE_SOURCES
      // Do not keep historical provider names around after they have stopped
      // supplying readable records. Direct BLE sources are distinguished from
      // Health Connect origins by their stable ble: source id.
      if (metrics.isEmpty &&
          recordCounts.values.every((count) => count <= 0)) {
        continue;
      }
      final direct = id.startsWith('ble:');

      result.add(
        HealthyDataSource(
          id: id,
          label: health.sourceLabels[id] ?? SourceNameService.friendly(id),
          transport: direct
              ? SourceTransport.directBluetooth
              : SourceTransport.healthConnect,
          metrics: metrics,
          recordCounts: recordCounts,
          selectable: metrics.isNotEmpty,
          lastSeen: health.sourceLastSeen[id],
          note: direct ? 'Read directly from the paired device' : null,
        ),
      );
'''
    if old not in text:
        fail('source hub provider block changed unexpectedly')
    text = text.replace(old, new, 1)
    path.write_text(text)


# --- Garmin identity: the Vivoactive 6 advertises an accented name -------------
path = Path('lib/services/ble_protocol_profiles.dart')
text = path.read_text()
if "'vívoactive'," not in text:
    old = "        'vivoactive',\n"
    new = "        'vivoactive',\n        'vívoactive',\n"
    if old not in text:
        fail('Garmin vivoactive name hint missing')
    text = text.replace(old, new, 1)
    path.write_text(text)


# --- Health sync: stop permanently merging stale provider metadata -------------
path = Path('lib/state/health_sync_provider.dart')
text = path.read_text()
direct_import = "import '../services/direct_metric_service.dart';\n"
if direct_import not in text:
    anchor = "import '../services/health_connect_service.dart';\n"
    if anchor not in text:
        fail('health sync import anchor missing')
    text = text.replace(anchor, anchor + direct_import, 1)

if 'SALUS_BUILD26_CURRENT_SOURCE_STATE' not in text:
    stale_anchor = '''    for (final metric in obsoleteRoutes) {
      routedSources.remove(metric);
      ref.read(appStateProvider.notifier).setMetricSource(metric, 'Auto');
    }

'''
    stale_insert = '''    for (final metric in obsoleteRoutes) {
      routedSources.remove(metric);
      ref.read(appStateProvider.notifier).setMetricSource(metric, 'Auto');
    }

    // Drop a manual Health Connect route that is no longer one of the current
    // providers for that metric. Direct BLE routes are retained because their
    // samples live in Salus rather than Health Connect.
    final stalePreviousRoutes = routedSources.entries.where((entry) {
      if (entry.value.startsWith('ble:')) return false;
      final choices = app.health.availableSources[entry.key] ?? const <String>[];
      return choices.isNotEmpty &&
          !choices.any(
            (source) => SourceNameService.sameProvider(source, entry.value),
          );
    }).map((entry) => entry.key).toList();
    for (final metric in stalePreviousRoutes) {
      routedSources.remove(metric);
      ref.read(appStateProvider.notifier).setMetricSource(metric, 'Auto');
    }

'''
    if stale_anchor not in text:
        fail('route sanitizer anchor missing')
    text = text.replace(stale_anchor, stale_insert, 1)

    text = text.replace(
        '    final snapshot = await _service.sync(\n',
        '    var snapshot = await _service.sync(\n',
        1,
    )

    start = text.find('    final previous = app.health;')
    end_line = '    ref.read(appStateProvider.notifier).setHealthSnapshot(merged);\n'
    end = text.find(end_line, start)
    if start < 0 or end < 0:
        fail('old Health Connect metadata merge block missing')
    end += len(end_line)
    replacement = '''    // SALUS_BUILD26_CURRENT_SOURCE_STATE
    // The old implementation unioned every provider ever seen into the next
    // snapshot. That is why removed QRing/Garmin app origins never disappeared.
    final directMetricService = DirectMetricService();
    final directSamples = await directMetricService.loadSamples();
    var merged = directMetricService.mergeIntoSnapshot(
      snapshot,
      metricSources: routedSources,
      samples: directSamples,
    );

    // If a provider vanished during this refresh, switch that metric back to
    // Automatic immediately and refresh once more so the visible value is not
    // left blank behind an obsolete manual route.
    final staleAfterRefresh = routedSources.entries.where((entry) {
      if (entry.value.startsWith('ble:')) return false;
      final choices = merged.availableSources[entry.key] ?? const <String>[];
      return !choices.any(
        (source) => SourceNameService.sameProvider(source, entry.value),
      );
    }).map((entry) => entry.key).toList();

    if (staleAfterRefresh.isNotEmpty) {
      for (final metric in staleAfterRefresh) {
        routedSources.remove(metric);
        ref.read(appStateProvider.notifier).setMetricSource(metric, 'Auto');
      }
      snapshot = await _service.sync(
        historicalAccess:
            historyOverride ?? app.health.historicalAccess,
        metricSources: routedSources,
      );
      merged = directMetricService.mergeIntoSnapshot(
        snapshot,
        metricSources: routedSources,
        samples: directSamples,
      );
    }

    ref.read(appStateProvider.notifier).setHealthSnapshot(merged);
'''
    text = text[:start] + replacement + text[end:]
    path.write_text(text)


# --- Sources screen: real direct read + accurate paired/read wording -----------
path = Path('lib/screens/sources_screen.dart')
text = path.read_text()
metric_import = "import '../services/direct_metric_service.dart';\n"
if metric_import not in text:
    anchor = "import '../services/direct_device_store.dart';\n"
    if anchor not in text:
        fail('Sources direct_device_store import missing')
    text = text.replace(anchor, anchor + metric_import, 1)

if 'final _directMetricService = DirectMetricService();' not in text:
    anchor = '  final _directDeviceStore = DirectDeviceStore();\n'
    if anchor not in text:
        fail('Sources direct device store field missing')
    text = text.replace(
        anchor,
        anchor +
        '  final _directMetricService = DirectMetricService();\n'
        '  final Set<String> _readingDirect = {};\n'
        '  final Map<String, String> _directReadSummary = {};\n',
        1,
    )

if 'Future<DirectMetricReadResult?> _readDirectMetrics(' not in text:
    anchor = '  Future<void> _scanBluetooth() async {\n'
    if anchor not in text:
        fail('Sources scan method anchor missing')
    method = '''  Future<DirectMetricReadResult?> _readDirectMetrics(
    BleDeviceCandidate device, {
    bool showSnackBar = true,
  }) async {
    if (_readingDirect.contains(device.id)) return null;
    setState(() => _readingDirect.add(device.id));

    try {
      final result = await _directMetricService.readAndStore(device);
      final samples = await _directMetricService.loadSamples();
      final app = ref.read(appStateProvider);
      final merged = _directMetricService.mergeIntoSnapshot(
        app.health,
        metricSources: app.metricSources,
        samples: samples,
      );
      ref.read(appStateProvider.notifier).setHealthSnapshot(merged);

      if (!mounted) return result;
      setState(() => _directReadSummary[device.id] = result.summary);
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
      return result;
    } catch (error) {
      if (!mounted) return null;
      final message = 'Could not read ${device.name}: $error';
      setState(() => _directReadSummary[device.id] = message);
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _readingDirect.remove(device.id));
    }
  }

'''
    text = text.replace(anchor, method + anchor, 1)

# After pairing/saving, immediately attempt a real standard-metric read.
old = '''      await _directDeviceStore.save(
        device: device,
        inspection: inspection,
        pair: pair,
      );
      await _loadSavedDirectDevices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pair.message)),
      );
'''
new = '''      await _directDeviceStore.save(
        device: device,
        inspection: inspection,
        pair: pair,
      );
      await _loadSavedDirectDevices();
      final directRead = await _readDirectMetrics(
        device,
        showSnackBar: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(directRead?.message ?? pair.message)),
      );
'''
if new not in text:
    if old not in text:
        fail('Sources save/pair completion block missing')
    text = text.replace(old, new, 1)

# Pass reader state into each BLE row.
old = '''                onUse: () => _useWithSalus(
                  _bleDevices.firstWhere(
                    (device) => source.id == 'ble:${device.id}',
                  ),
                ),
              ),
'''
new = '''                onUse: () => _useWithSalus(
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
'''
if new not in text:
    if old not in text:
        fail('BLE row call anchor missing')
    text = text.replace(old, new, 1)

# Truthful wording: bonding/saving is pairing, not proof of a health-data reader.
text = text.replace(
    "'${device.deviceKind} • ${device.bonded ? 'Android bonded' : 'Direct GATT'}'",
    "'${device.deviceKind} • ${device.bonded ? 'Android paired' : 'Direct GATT saved'}'",
)

# Replace only the BLE row class; preserve diagnostics below it.
start = text.find('class _BleSourceRow extends StatelessWidget {')
end = text.find('IconData _deviceIcon(String kind) {', start)
if start < 0 or end < 0:
    fail('BLE row class markers missing')
new_class = r'''class _BleSourceRow extends StatelessWidget {
  final HealthyDataSource source;
  final BleDeviceCandidate device;
  final BleDeviceInspection? inspection;
  final bool inspecting;
  final bool saved;
  final bool pairing;
  final bool reading;
  final String? readSummary;
  final VoidCallback onInspect;
  final VoidCallback onUse;
  final VoidCallback onRead;

  const _BleSourceRow({
    required this.source,
    required this.device,
    required this.inspection,
    required this.inspecting,
    required this.saved,
    required this.pairing,
    required this.reading,
    required this.readSummary,
    required this.onInspect,
    required this.onUse,
    required this.onRead,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: saved ? AppTheme.mint : AppTheme.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _deviceIcon(kind),
                  color: saved ? AppTheme.mint : AppTheme.blue,
                  size: 25,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.label,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        protocol == null ? kind : '$kind • $protocol',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        saved
                            ? 'Paired with Salus • ${device.bondState}'
                            : inspection == null
                                ? 'Detected nearby • ${device.bondState}'
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
            if (capabilities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Detected/potential: ${capabilities.join(' • ')}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.mint,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (readSummary != null) ...[
              const SizedBox(height: 7),
              Text(
                readSummary!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                OutlinedButton(
                  onPressed: inspecting ? null : onInspect,
                  child: Text(
                    inspecting
                        ? 'Identifying…'
                        : inspection == null
                            ? 'Identify'
                            : 'Identify again',
                  ),
                ),
                if (!saved)
                  FilledButton.tonalIcon(
                    onPressed: pairing ? null : onUse,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: Text(pairing ? 'Pairing…' : 'Pair'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: reading ? null : onRead,
                    icon: const Icon(Icons.sensors_rounded, size: 18),
                    label: Text(reading ? 'Reading…' : 'Read data'),
                  ),
              ],
            ),
            if (inspection != null)
              ExpansionTile(
                dense: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
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
                  if (protocol != null)
                    _DiagnosticText('Protocol family', protocol),
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
      ),
    );
  }
}

'''
text = text[:start] + new_class + text[end:]

# Give the horizontal hardware cards enough vertical space.
text = text.replace('            height: 154,', '            height: 170,')
path.write_text(text)


# --- Device-type card layout overflow ------------------------------------------
path = Path('lib/widgets/salus_widgets.dart')
text = path.read_text()
text = text.replace(
    'Center(child: Image.asset(asset, width: 86, height: 76, fit: BoxFit.contain, filterQuality: FilterQuality.high)),',
    'Center(child: Image.asset(asset, width: 82, height: 66, fit: BoxFit.contain, filterQuality: FilterQuality.high)),',
)
text = text.replace(
    "Text(subtitle, maxLines: 2, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.25)),",
    "Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.18)),",
)
path.write_text(text)

print('Salus build 26 stale-source, direct-read and Bluetooth layout fixes applied.')
