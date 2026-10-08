import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/direct_device_store.dart';
import '../services/direct_metric_service.dart';
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
  final _direct = DirectMetricService();
  final _notifications = WatchNotificationService();
  SavedDirectDevice? _device;
  WatchNotificationState? _state;
  double? _battery;
  bool _loading = true;
  bool _saving = false;
  bool _argsLoaded = false;
  String? _requestedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final argument = ModalRoute.of(context)?.settings.arguments;
    if (argument is String && argument.isNotEmpty) _requestedId = argument;
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _device != null) {
      _reloadNotificationState();
    }
  }

  Future<void> _load() async {
    final devices = await _store.load();
    final watches = devices.where((device) {
      final kind = device.deviceKind.toLowerCase();
      final protocol = device.protocolId ?? '';
      return kind.contains('watch') || kind.contains('band') ||
          protocol.contains('garmin') || protocol.contains('veryfit');
    }).toList();
    SavedDirectDevice? selected;
    for (final device in watches) {
      if (device.id == _requestedId) {
        selected = device;
        break;
      }
    }
    selected ??= watches.isEmpty ? null : watches.first;
    final samples = await _direct.loadSamples();
    double? battery;
    if (selected != null) {
      final selectedId = selected.id;
      final values = samples.where((sample) =>
          sample.deviceId == selectedId && sample.metric == 'Battery').toList()
        ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
      if (values.isNotEmpty) battery = values.last.value;
    }
    if (!mounted) return;
    setState(() {
      _device = selected;
      _battery = battery;
      _loading = false;
    });
    await _reloadNotificationState();
  }

  Future<void> _reloadNotificationState() async {
    final device = _device;
    if (device == null) return;
    try {
      final state = await _notifications.load(
        deviceId: device.id,
        protocolId: device.protocolId ?? '',
        deviceName: device.name,
      );
      if (mounted) setState(() => _state = state);
    } catch (error) {
      if (mounted) _show('Could not read notification settings: $error');
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _setMaster(bool value) async {
    final device = _device;
    final state = _state;
    if (device == null || state == null || _saving) return;
    if (!state.deliverySupported) {
      _show('Salus does not have a verified notification sender for this watch protocol.');
      return;
    }
    if (value && !state.accessEnabled) {
      await _notifications.openNotificationAccess();
      return;
    }
    setState(() => _saving = true);
    try {
      await _notifications.setMaster(
        deviceId: device.id,
        protocolId: device.protocolId ?? '',
        deviceName: device.name,
        enabled: value,
      );
      await _reloadNotificationState();
    } catch (error) {
      if (mounted) _show('Could not save notification setting: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setApp(WatchNotificationApp app, bool value) async {
    final device = _device;
    if (device == null || _saving) return;
    setState(() => _saving = true);
    try {
      await _notifications.setApp(
        deviceId: device.id,
        packageName: app.packageName,
        enabled: value,
      );
      await _reloadNotificationState();
    } catch (error) {
      if (mounted) _show('Could not save app filter: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setAllAccounts(WatchNotificationApp app, bool value) async {
    final device = _device;
    if (device == null || _saving) return;
    setState(() => _saving = true);
    try {
      await _notifications.setAllAccounts(
        deviceId: device.id,
        packageName: app.packageName,
        enabled: value,
      );
      await _reloadNotificationState();
    } catch (error) {
      if (mounted) _show('Could not save Gmail filter: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setAccount(WatchNotificationApp app,
      WatchNotificationAccount account, bool value) async {
    final device = _device;
    if (device == null || _saving) return;
    setState(() => _saving = true);
    try {
      await _notifications.setAccount(
        deviceId: device.id,
        packageName: app.packageName,
        account: account.name,
        enabled: value,
      );
      await _reloadNotificationState();
    } catch (error) {
      if (mounted) _show('Could not save Gmail account: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    final state = _state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch settings'),
        actions: [
          IconButton(
            tooltip: 'Refresh notification status',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reloadNotificationState,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : device == null
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No watch is connected yet. Add one from Connections.',
                    textAlign: TextAlign.center,
                  ),
                ))
              : SalusPageBackground(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                    children: [
                      _WatchHero(device: device, battery: _battery),
                      const SizedBox(height: 14),
                      SalusPaper(
                        padding: EdgeInsets.zero,
                        child: SwitchListTile.adaptive(
                          value: state?.masterEnabled ?? false,
                          onChanged: state == null || _saving ||
                                  (!state.deliverySupported && !state.masterEnabled)
                              ? null
                              : _setMaster,
                          title: const Text('Phone notifications on this watch',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800)),
                          subtitle: Text(
                            state == null
                                ? 'Checking settings…'
                                : !state.deliverySupported
                                    ? 'Not supported by the current Salus driver for this watch. App filters alone cannot deliver alerts.'
                                    : !state.accessEnabled
                                        ? 'First enable Android notification access, then return and switch notifications on.'
                                        : state.masterEnabled
                                            ? '${state.enabledAppCount} app${state.enabledAppCount == 1 ? '' : 's'} allowed. Toggle any app below to mute it.'
                                            : 'Off. Switching on opts into the apps listed below; you can turn them off individually.',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12.2,
                                height: 1.35),
                          ),
                          secondary: const Icon(
                              Icons.notifications_active_outlined,
                              color: AppTheme.cyan),
                        ),
                      ),
                      if (state != null && !state.accessEnabled) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _notifications.openNotificationAccess,
                          icon: const Icon(Icons.settings_rounded),
                          label: const Text('Android notification access'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (state != null) SalusPaper(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notification diagnostics',
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 10),
                            Text('Android access: ${state.accessEnabled ? 'On' : 'Off'}',
                                style: const TextStyle(color: AppTheme.textSecondary)),
                            Text('Direct protocol sender: ${state.deliverySupported ? 'Available (IDO / VeryFit)' : 'Not available'}',
                                style: const TextStyle(color: AppTheme.textSecondary)),
                            Text('Last notification seen: ${_when(state.lastObservedAt)}',
                                style: const TextStyle(color: AppTheme.textSecondary)),
                            Text('Last allowed for forwarding: ${_when(state.lastEligibleAt)}',
                                style: const TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(height: 8),
                            const Text(
                              'Allowed means the phone saw and approved an alert. It does not confirm the watch received it. Watch delivery requires a supported Bluetooth protocol and connection.',
                              style: TextStyle(color: AppTheme.textMuted,
                                  fontSize: 12, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      if (state != null && state.apps.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const Text('Apps', style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        const Text('Text messages, Messenger, Gmail, and other installed or observed apps can be selected individually.',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12.5)),
                        const SizedBox(height: 10),
                        for (final app in state.apps) ...[
                          _AppCard(
                            app: app,
                            busy: _saving,
                            onChanged: (value) => _setApp(app, value),
                            onAllAccountsChanged: app.isGmail
                                ? (value) => _setAllAccounts(app, value) : null,
                            onAccountChanged: app.isGmail
                                ? (account, value) => _setAccount(app, account, value)
                                : null,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }

  String _when(DateTime? date) {
    if (date == null) return 'Never';
    final local = date.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _WatchHero extends StatelessWidget {
  final SavedDirectDevice device;
  final double? battery;

  const _WatchHero({required this.device, required this.battery});

  @override
  Widget build(BuildContext context) => SalusPaper(
    glow: true,
    child: Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: AppTheme.cyan.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.25)),
        ),
        child: const Icon(Icons.watch_outlined,
            color: AppTheme.cyan, size: 28),
      ),
      const SizedBox(width: 13),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(device.name, style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text([
            device.protocolLabel ?? device.deviceKind,
            if (battery != null) 'Battery ${battery!.round()}%',
          ].join(' • '), style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12.5)),
        ],
      )),
    ]),
  );
}

class _AppCard extends StatelessWidget {
  final WatchNotificationApp app;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final ValueChanged<bool>? onAllAccountsChanged;
  final void Function(WatchNotificationAccount account, bool enabled)?
      onAccountChanged;

  const _AppCard({
    required this.app,
    required this.busy,
    required this.onChanged,
    this.onAllAccountsChanged,
    this.onAccountChanged,
  });

  @override
  Widget build(BuildContext context) => SalusPaper(
    padding: EdgeInsets.zero,
    child: Column(children: [
      SwitchListTile.adaptive(
        value: app.enabled,
        onChanged: busy ? null : onChanged,
        title: Text(app.label, style: const TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        subtitle: Text(
          app.isGmail && app.accounts.isNotEmpty
              ? '${app.accounts.length} Gmail accounts found'
              : app.enabled ? 'Allowed on watch' : 'Muted on watch',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        secondary: Icon(_iconFor(app.packageName), color: AppTheme.textSecondary),
      ),
      if (app.isGmail && app.enabled) ...[
        const Divider(height: 1),
        ExpansionTile(
          title: const Text('Gmail accounts'),
          subtitle: Text(app.allAccounts
              ? 'All accounts allowed' : 'Choose individual accounts'),
          children: [
            SwitchListTile.adaptive(
              value: app.allAccounts,
              onChanged: busy ? null : onAllAccountsChanged,
              title: const Text('All Gmail accounts'),
            ),
            if (app.accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text('Accounts appear after Salus observes a Gmail notification. No Gmail mailbox access is required.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              )
            else
              for (final account in app.accounts)
                SwitchListTile.adaptive(
                  value: account.enabled,
                  onChanged: busy || app.allAccounts
                      ? null : (value) => onAccountChanged?.call(account, value),
                  title: Text(account.name),
                  dense: true,
                ),
          ],
        ),
      ],
    ]),
  );

  IconData _iconFor(String packageName) {
    if (packageName == 'com.google.android.gm') {
      return Icons.mail_outline_rounded;
    }
    if (packageName.contains('messaging') ||
        packageName.contains('messages')) return Icons.sms_outlined;
    if (packageName.contains('calendar')) return Icons.calendar_month_outlined;
    if (packageName.contains('facebook') ||
        packageName.contains('instagram') ||
        packageName.contains('whatsapp') ||
        packageName.contains('snapchat') ||
        packageName.contains('discord')) return Icons.forum_outlined;
    return Icons.notifications_none_rounded;
  }
}
