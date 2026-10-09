import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
import '../services/garmin_battery_service.dart';
import '../services/watch_notification_service.dart';
import '../widgets/salus_widgets.dart';

class WatchDeviceScreen extends ConsumerStatefulWidget {
  const WatchDeviceScreen({super.key});
  @override
  ConsumerState<WatchDeviceScreen> createState() => _WatchDeviceScreenState();
}

class _WatchDeviceScreenState extends ConsumerState<WatchDeviceScreen>
    with WidgetsBindingObserver {
  final _store = DirectDeviceStore();
  final _metrics = DirectMetricService();
  final _notifications = WatchNotificationService();
  final _garminBattery = GarminBatteryService();
  SavedDirectDevice? _device;
  WatchNotificationState? _state;
  String? _requestedId;
  bool _argsLoaded = false;
  bool _loading = true;
  bool _busy = false;
  bool _checkingBattery = false;
  bool _testing = false;
  Timer? _statusRefresh;
  double? _battery;
  DateTime? _batteryAt;
  String? _batteryStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _statusRefresh = Timer.periodic(const Duration(seconds: 4), (_) => _reload());
  }

  @override
  void dispose() {
    _statusRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) _requestedId = args;
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) _reload();
  }

  Future<void> _load() async {
    final saved = await _store.load();
    final watches = saved.where((device) {
      final kind = device.deviceKind.toLowerCase();
      return kind.contains('watch') || kind.contains('band') ||
          (device.protocolId ?? '').contains('garmin') ||
          (device.protocolId ?? '').contains('veryfit');
    }).toList();
    SavedDirectDevice? selected;
    for (final device in watches) {
      if (device.id == _requestedId) selected = device;
    }
    selected ??= watches.isEmpty ? null : watches.first;
    final samples = await _metrics.loadSamples();
    final values = samples.where((sample) =>
        sample.deviceId == selected?.id && sample.metric == 'Battery').toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    String? status;
    if (selected != null && (selected.protocolId ?? '').contains('garmin')) {
      status = await _garminBattery.lastResult(selected.id);
    }
    if (!mounted) return;
    setState(() {
      _device = selected;
      _battery = values.isEmpty ? null : values.last.value;
      _batteryAt = values.isEmpty ? null : values.last.capturedAt;
      _batteryStatus = status;
      _loading = false;
    });
    await _reload();
  }

  Future<void> _reload() async {
    final device = _device;
    if (device == null) return;
    try {
      final state = await _notifications.load(
        deviceId: device.id,
        deviceName: device.name,
        protocolId: device.protocolId ?? '',
      );
      if (mounted) setState(() => _state = state);
    } catch (error) {
      _toast('Could not load notification settings: $error');
    }
  }

  Future<void> _checkGarminBattery() async {
    final device = _device;
    if (device == null || _checkingBattery) return;
    setState(() => _checkingBattery = true);
    try {
      final status = await _garminBattery.check(device.id, device.name);
      if (!mounted) return;
      setState(() => _batteryStatus = status);
      await _load();
    } catch (error) {
      _toast('Could not check watch battery: $error');
    } finally {
      if (mounted) setState(() => _checkingBattery = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setMaster(bool enabled) async {
    final device = _device;
    final state = _state;
    if (device == null || state == null || _busy) return;
    if (!state.canAttempt) {
      _toast('No installed direct notification driver supports this watch yet.');
      return;
    }
    if (enabled && !state.accessEnabled) {
      await _notifications.openNotificationAccess();
      return;
    }
    setState(() => _busy = true);
    try {
      await _notifications.setMaster(
        deviceId: device.id,
        deviceName: device.name,
        protocolId: device.protocolId ?? '',
        enabled: enabled,
      );
      await _reload();
    } catch (error) {
      _toast('Could not update notifications: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendTest() async {
    final device = _device;
    final state = _state;
    if (device == null || state == null || _testing || !state.masterEnabled) return;
    setState(() => _testing = true);
    try {
      final accepted = await _notifications.sendTest(deviceId: device.id);
      _toast(accepted
          ? 'Test queued. Check transport diagnostics for the Bluetooth result.'
          : 'Test unavailable. Enable notifications and Android access first.');
      await Future<void>.delayed(const Duration(seconds: 2));
      await _reload();
    } catch (error) {
      _toast('Could not start notification test: $error');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _changeApp(WatchNotificationApp app, bool value) async {
    final device = _device;
    if (device == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _notifications.setApp(
          deviceId: device.id, packageName: app.packageName, enabled: value);
      await _reload();
    } catch (error) {
      _toast('Could not save app selection: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeAllAccounts(WatchNotificationApp app, bool value) async {
    final device = _device;
    if (device == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _notifications.setAllAccounts(
          deviceId: device.id, packageName: app.packageName, enabled: value);
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeAccount(WatchNotificationApp app,
      WatchNotificationAccount account, bool value) async {
    final device = _device;
    if (device == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _notifications.setAccount(
        deviceId: device.id, packageName: app.packageName,
        account: account.name, enabled: value,
      );
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _when(DateTime? at) {
    if (at == null) return 'Never';
    final value = at.toLocal();
    return '${value.month}/${value.day} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    final state = _state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch settings'),
        actions: [IconButton(
          tooltip: 'Refresh notification status',
          icon: const Icon(Icons.refresh_rounded), onPressed: _load,
        )],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : device == null
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No watch connected yet. Add a watch from Connections.',
                      textAlign: TextAlign.center),
                ))
              : SalusPageBackground(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                    children: [
                      SalusPaper(glow: true, child: Row(children: [
                        const Icon(Icons.watch_rounded, size: 38, color: AppTheme.cyan),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(device.name, style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 21,
                                fontWeight: FontWeight.w800)),
                            Text(device.protocolLabel ?? device.deviceKind,
                                style: const TextStyle(color: AppTheme.textSecondary)),
                          ],
                        )),
                      ])),
                      const SizedBox(height: 12),
                      SalusPaper(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Watch charge', style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(_battery == null ? 'Battery: not available yet'
                              : 'Battery: ${_battery!.round()}% • last read ${_when(_batteryAt)}',
                              style: const TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          const Text('Battery charge is different from Garmin Body Battery.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          if (_batteryStatus != null) ...[
                            const SizedBox(height: 8),
                            Text(_batteryStatus!, style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                          if ((device.protocolId ?? '').contains('garmin')) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _checkingBattery ? null : _checkGarminBattery,
                              icon: const Icon(Icons.battery_std_rounded),
                              label: Text(_checkingBattery
                                  ? 'Checking…' : 'Check Garmin battery'),
                            ),
                          ],
                        ],
                      )),
                      const SizedBox(height: 12),
                      SalusPaper(padding: EdgeInsets.zero,
                        child: SwitchListTile.adaptive(
                          title: const Text('Phone notifications on this watch',
                              style: TextStyle(color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800)),
                          subtitle: Text(state == null
                              ? 'Loading notification settings…'
                              : !state.canAttempt
                                  ? 'No compatible local Bluetooth notification sender is installed for this device.'
                                  : !state.accessEnabled
                                      ? 'Enable Android notification access first.'
                                      : 'Direct local sender • ${state.enabledAppCount} apps allowed.',
                              style: const TextStyle(color: AppTheme.textSecondary,
                                  fontSize: 12.5)),
                          secondary: const Icon(Icons.notifications_active_outlined,
                              color: AppTheme.cyan),
                          value: state?.canAttempt == true && state?.masterEnabled == true,
                          onChanged: state == null || _busy ||
                                  !state.canAttempt
                              ? null : _setMaster,
                        ),
                      ),
                      if (state != null && !state.accessEnabled) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.settings_rounded),
                          onPressed: _notifications.openNotificationAccess,
                          label: const Text('Android notification access'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (state != null) SalusPaper(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Notification diagnostics', style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w900, fontSize: 17)),
                          const SizedBox(height: 9),
                          Text('Android access: ${state.accessEnabled ? 'On' : 'Off'}',
                              style: const TextStyle(color: AppTheme.textSecondary)),
                          Text('Direct protocol sender: ${state.deliverySupported ? ((device.protocolId ?? '') == 'garmin-family' ? 'Garmin GFDI installed (experimental)' : 'IDO / VeryFit installed') : 'Not installed'}',
                              style: const TextStyle(color: AppTheme.textSecondary)),
                          Text('Last notification seen: ${_when(state.lastObservedAt)}',
                              style: const TextStyle(color: AppTheme.textSecondary)),
                          Text('Last allowed for forwarding: ${_when(state.lastEligibleAt)}',
                              style: const TextStyle(color: AppTheme.textSecondary)),
                          if (state.lastEligibleApp.isNotEmpty)
                            Text('Last allowed app: ${state.lastEligibleApp}',
                                style: const TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 10),
                          Text('Bluetooth transport: ${state.transportStage}',
                              style: const TextStyle(color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700)),
                          if (state.transportDetails.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(state.transportDetails,
                                style: const TextStyle(color: AppTheme.textSecondary)),
                          ],
                          Text('Transport updated: ${_when(state.transportUpdatedAt)}',
                              style: const TextStyle(color: AppTheme.textSecondary)),
                          if (state.transportHistory.isNotEmpty)
                            ExpansionTile(
                              title: const Text('Bluetooth event history'),
                              tilePadding: EdgeInsets.zero,
                              children: [Text(state.transportHistory,
                                  style: const TextStyle(color: AppTheme.textSecondary,
                                      fontSize: 11))],
                            ),
                          const SizedBox(height: 7),
                          const Text('Allowed means the phone approved the alert. '
                              'It does not confirm the watch received it. '
                              'Garmin and IDO drivers send directly; delivery requires physical-watch validation. No companion apps.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5)),
                        ],
                      )),
                      if (state != null && device.protocolId == 'garmin-family') ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _testing || !state.masterEnabled ? null : _sendTest,
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: Text(_testing ? 'Testing…' : 'Send test notification'),
                        ),
                      ],
                      if (state != null && state.apps.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Apps', style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 19,
                            fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Text messages, Messenger, Gmail and other '
                            'observed apps can be enabled individually.',
                            style: TextStyle(color: AppTheme.textSecondary,
                                fontSize: 12.5)),
                        const SizedBox(height: 10),
                        for (final app in state.apps) ...[
                          SalusPaper(padding: EdgeInsets.zero, child: Column(children: [
                            SwitchListTile.adaptive(
                              title: Text(app.label, style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700)),
                              subtitle: Text(app.packageName,
                                  style: const TextStyle(
                                      color: AppTheme.textMuted, fontSize: 11)),
                              value: app.enabled,
                              onChanged: _busy ? null : (value) => _changeApp(app, value),
                            ),
                            if (app.isGmail && app.enabled) ...[
                              SwitchListTile.adaptive(
                                title: const Text('All Gmail accounts',
                                    style: TextStyle(color: AppTheme.textSecondary)),
                                value: app.allAccounts,
                                onChanged: _busy ? null :
                                    (value) => _changeAllAccounts(app, value),
                              ),
                              if (!app.allAccounts)
                                for (final account in app.accounts)
                                  SwitchListTile.adaptive(
                                    title: Text(account.name,
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12)),
                                    value: account.enabled,
                                    onChanged: _busy ? null : (value) =>
                                        _changeAccount(app, account, value),
                                  ),
                            ],
                          ])),
                          const SizedBox(height: 7),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }
}
