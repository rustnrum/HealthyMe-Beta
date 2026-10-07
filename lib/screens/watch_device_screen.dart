import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../services/ble_discovery_service.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../widgets/salus_widgets.dart';

class WatchDeviceScreen extends StatefulWidget {
  const WatchDeviceScreen({super.key});

  @override
  State<WatchDeviceScreen> createState() => _WatchDeviceScreenState();
}

class _WatchDeviceScreenState extends State<WatchDeviceScreen> {
  static const _channel =
      MethodChannel('com.rustnrum.healthyme/source_discovery');
  static const _categories = <String, String>{
    'calls': 'Calls',
    'messages': 'Text messages',
    'calendar': 'Calendar',
    'apps': 'Other app notifications',
    'meals': 'Salus meal reminders',
    'workouts': 'Workout reminders',
    'recovery': 'Recovery / check-in reminders',
  };

  final _store = DirectDeviceStore();
  final _direct = DirectMetricService();

  SavedDirectDevice? _device;
  Map<String, bool> _settings = const {};
  double? _battery;
  bool _loading = true;
  bool _syncing = false;
  bool _argsLoaded = false;
  String? _deviceId;
  String? _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && arg.isNotEmpty) _deviceId = arg;
    _load();
  }

  String _prefKey(String id, String category) =>
      'salus_watch_notify_v1::$id::$category';

  Future<void> _load() async {
    final devices = await _store.load();
    SavedDirectDevice? device;
    for (final item in devices) {
      if (item.id == _deviceId) {
        device = item;
        break;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final settings = <String, bool>{
      for (final entry in _categories.entries)
        entry.key:
            prefs.getBool(_prefKey(device?.id ?? _deviceId ?? '', entry.key)) ??
                false,
    };

    final samples = await _direct.loadSamples();
    final batterySamples = samples
        .where(
          (sample) =>
              sample.deviceId == (device?.id ?? _deviceId) &&
              sample.metric == 'Battery',
        )
        .toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

    if (!mounted) return;
    setState(() {
      _device = device;
      _settings = settings;
      _battery = batterySamples.isEmpty
          ? null
          : batterySamples.last.value.clamp(0.0, 100.0).toDouble();
      _loading = false;
    });
  }

  Future<void> _setCategory(String category, bool value) async {
    final device = _device;
    if (device == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey(device.id, category), value);
    if (!mounted) return;
    setState(() => _settings = {..._settings, category: value});
  }

  Future<void> _openNotificationAccess() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('openNotificationAccess');
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Could not open notification access: $error');
    }
  }

  BleDeviceCandidate _candidate(SavedDirectDevice device) => BleDeviceCandidate(
        id: device.id,
        name: device.name,
        rssi: -127,
        advertisedServices: const [],
        capabilities: device.capabilities,
        protocolProfile: device.protocolLabel,
        protocolId: device.protocolId,
        protocolNote: null,
        deviceKind: device.deviceKind,
        manufacturerDataHex: '',
        bondState: device.bonded ? 'bonded' : device.pairState,
      );

  Future<void> _sync() async {
    final device = _device;
    if (device == null || _syncing) return;
    setState(() {
      _syncing = true;
      _status = null;
    });
    try {
      final result = await _direct.readAndStore(
        _candidate(device),
        protocolId: device.protocolId,
        duration: const Duration(seconds: 22),
      );
      if (!mounted) return;
      setState(() => _status = result.summary);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Could not sync ${device.name}: $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    return Scaffold(
      appBar: AppBar(title: Text(device?.name ?? 'Watch')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : device == null
              ? const Center(
                  child: Text('Watch is no longer connected to Salus.'),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
                  children: [
                    SalusPaper(
                      glow: true,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.watch_outlined,
                            color: AppTheme.cyan,
                            size: 34,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  device.protocolLabel ?? device.deviceKind,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_battery != null)
                            _BatteryBadge(value: _battery!),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _syncing ? null : _sync,
                        icon: _syncing
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(_syncing ? 'Syncing…' : 'Sync watch now'),
                      ),
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _status!,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    const SalusSectionTitle(
                      title: 'Notifications',
                      eyebrow: 'Choose what can reach the watch',
                    ),
                    const SizedBox(height: 8),
                    SalusPaper(
                      child: Column(
                        children: [
                          for (final entry in _categories.entries) ...[
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(entry.value),
                              value: _settings[entry.key] ?? false,
                              onChanged: (value) =>
                                  _setCategory(entry.key, value),
                            ),
                            if (entry.key != _categories.keys.last)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _openNotificationAccess,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Android notification access'),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Phone notification mirroring requires Android notification access. '
                      'Salus keeps each category preference separate for this watch.',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11.8,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _BatteryBadge extends StatelessWidget {
  final double value;

  const _BatteryBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.mint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.battery_charging_full_rounded,
            color: AppTheme.mint,
            size: 17,
          ),
          const SizedBox(width: 5),
          Text(
            '${value.round()}%',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
