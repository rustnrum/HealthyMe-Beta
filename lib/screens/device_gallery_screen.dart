import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../services/local_device_driver.dart';
import '../widgets/device_battery_indicator.dart';
import '../widgets/device_image.dart';
import '../widgets/salus_widgets.dart';

class _DeviceGalleryData {
  final List<SavedDirectDevice> devices;
  final List<DirectMetricSample> samples;
  const _DeviceGalleryData(this.devices, this.samples);
}

class DeviceGalleryScreen extends StatefulWidget {
  const DeviceGalleryScreen({super.key});
  @override
  State<DeviceGalleryScreen> createState() => _DeviceGalleryScreenState();
}

class _DeviceGalleryScreenState extends State<DeviceGalleryScreen> {
  late Future<_DeviceGalleryData> _future;

  @override
  void initState() { super.initState(); _future = _load(); }

  Future<_DeviceGalleryData> _load() async => _DeviceGalleryData(
    await DirectDeviceStore().load(), await DirectMetricService().loadSamples());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My devices'), actions: [
      IconButton(onPressed: () => setState(() => _future = _load()),
        tooltip: 'Refresh local device list', icon: const Icon(Icons.refresh_rounded)),
    ]),
    body: FutureBuilder<_DeviceGalleryData>(future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
          const SalusSectionTitle(title: 'Connected equipment', eyebrow: 'Local drivers'),
          const SizedBox(height: 6),
          const Text('Recognizing a device is not proof that all proprietary metrics or notifications work. Drivers report what is actually supported.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 14),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (snapshot.hasError)
            const Text('Unable to load saved devices.',
                style: TextStyle(color: AppTheme.textSecondary))
          else if (data == null || data.devices.isEmpty)
            SalusPaper(onTap: () => Navigator.of(context).pushNamed('/sources'),
              child: const Row(children: [
                Icon(Icons.bluetooth_searching_rounded, color: AppTheme.cyan),
                SizedBox(width: 10),
                Expanded(child: Text('No saved devices. Tap to scan and connect.',
                  style: TextStyle(color: AppTheme.textPrimary))),
                Icon(Icons.chevron_right_rounded),
              ]))
          else
            for (final device in data.devices) ...[
              _deviceCard(context, device, data.samples),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 16),
          SalusPaper(onTap: () => Navigator.of(context).pushNamed('/sources'),
            child: const Row(children: [
              Icon(Icons.bluetooth_searching_rounded, color: AppTheme.mint),
              SizedBox(width: 12),
              Expanded(child: Text('Scan, inspect or configure devices',
                style: TextStyle(color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700))),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ])),
        ]);
      }),
  );

  Widget _deviceCard(BuildContext context, SavedDirectDevice device,
      List<DirectMetricSample> samples) {
    final decision = const SalusLocalDeviceDrivers().match(
      name: device.name, protocolId: device.protocolId,
      deviceKind: device.deviceKind);
    final batteries = samples.where((sample) =>
        sample.deviceId == device.id && sample.metric == 'Battery').toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    final battery = batteries.isEmpty ? null : batteries.last.value;
    final kind = device.deviceKind.toLowerCase();
    return SalusPaper(onTap: () {
      if (kind.contains('watch') || kind.contains('band')) {
        Navigator.of(context).pushNamed('/watch-device', arguments: device.id);
      } else if (device.protocolId == 'cpap-family') {
        Navigator.of(context).pushNamed('/cpap', arguments: device.id);
      } else {
        Navigator.of(context).pushNamed('/sources');
      }
    }, child: Row(children: [
      DeviceImage(deviceKind: device.deviceKind, size: 76),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(device.name, style: const TextStyle(color: AppTheme.textPrimary,
            fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(device.deviceKind, style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 12.5)),
        const SizedBox(height: 4),
        Text(switch (decision.status) {
          SalusDriverStatus.ready => 'Local protocol reader installed',
          SalusDriverStatus.standardOnly => 'Standard Bluetooth reader',
          SalusDriverStatus.recognizedOnly => 'Identified • reader not installed',
          SalusDriverStatus.unknown => 'Unknown device • inspect services',
        }, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
        if (battery != null) ...[
          const SizedBox(height: 7),
          SalusDeviceBatteryIndicator(deviceKind: device.deviceKind,
              percentage: battery),
        ],
      ])),
      const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
    ]));
  }
}
