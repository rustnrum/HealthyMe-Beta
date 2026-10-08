import 'dart:io';
import 'package:flutter/services.dart';

class WatchNotificationAccount {
  const WatchNotificationAccount({required this.name, required this.enabled});
  final String name;
  final bool enabled;
  factory WatchNotificationAccount.fromMap(Map<dynamic, dynamic> json) =>
      WatchNotificationAccount(name: json['name']?.toString() ?? '', enabled: json['enabled'] == true);
}

class WatchNotificationApp {
  const WatchNotificationApp({
    required this.packageName, required this.label, required this.enabled,
    this.allAccounts = true, this.accounts = const [],
  });
  final String packageName;
  final String label;
  final bool enabled;
  final bool allAccounts;
  final List<WatchNotificationAccount> accounts;
  bool get isGmail => packageName == 'com.google.android.gm';
  factory WatchNotificationApp.fromMap(Map<dynamic, dynamic> json) => WatchNotificationApp(
    packageName: json['packageName']?.toString() ?? '',
    label: json['label']?.toString() ?? 'App',
    enabled: json['enabled'] == true,
    allAccounts: json['allAccounts'] != false,
    accounts: (json['accounts'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(WatchNotificationAccount.fromMap)
        .where((item) => item.name.isNotEmpty).toList(),
  );
}

class WatchNotificationState {
  const WatchNotificationState({
    required this.accessEnabled, required this.masterEnabled,
    required this.deliverySupported, required this.companionRelay,
    required this.apps, this.lastObservedAt, this.lastEligibleAt,
    this.lastEligibleApp = '',
  });
  final bool accessEnabled;
  final bool masterEnabled;
  /// A verified implemented packet sender exists; this does not prove receipt.
  final bool deliverySupported;
  /// Salus can publish a phone notification for a watch companion to mirror.
  final bool companionRelay;
  final List<WatchNotificationApp> apps;
  final DateTime? lastObservedAt;
  final DateTime? lastEligibleAt;
  final String lastEligibleApp;
  bool get canAttempt => deliverySupported || companionRelay;
  int get enabledAppCount => apps.where((app) => app.enabled).length;
  static DateTime? _time(dynamic value) => value is num && value > 0
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt()) : null;
  factory WatchNotificationState.fromMap(Map<dynamic, dynamic> json,
      {bool companionRelay = false}) => WatchNotificationState(
    accessEnabled: json['accessEnabled'] == true,
    masterEnabled: json['masterEnabled'] == true,
    deliverySupported: json['deliverySupported'] == true,
    companionRelay: companionRelay,
    lastObservedAt: _time(json['lastObservedAt']),
    lastEligibleAt: _time(json['lastEligibleAt']),
    lastEligibleApp: json['lastEligibleApp']?.toString() ?? '',
    apps: (json['apps'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>().map(WatchNotificationApp.fromMap)
        .where((app) => app.packageName.isNotEmpty).toList(),
  );
}

class WatchNotificationService {
  static const _channel = MethodChannel('com.rustnrum.healthyme/source_discovery');

  Future<WatchNotificationState> load({
    required String deviceId, required String protocolId, required String deviceName,
  }) async {
    if (!Platform.isAndroid) return const WatchNotificationState(
      accessEnabled: false, masterEnabled: false, deliverySupported: false,
      companionRelay: false, apps: [],
    );
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getWatchNotificationState', {
        'deviceId': deviceId, 'protocolId': protocolId, 'deviceName': deviceName,
      });
    // An unsupported proprietary BLE sender is NEVER treated as available.
    // Android relay works only if the user's watch companion mirrors Salus alerts.
    final companion = protocolId != 'ido-veryfit-family' && protocolId != 'cpap-family';
    return WatchNotificationState.fromMap(raw ?? const {}, companionRelay: companion);
  }

  Future<void> setMaster({required String deviceId, required String protocolId,
      required String deviceName, required bool enabled}) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setWatchNotificationMaster', {
      'deviceId': deviceId, 'protocolId': protocolId,
      'deviceName': deviceName, 'enabled': enabled,
    });
  }

  Future<void> setApp({required String deviceId, required String packageName,
      required bool enabled}) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setWatchNotificationApp', {
      'deviceId': deviceId, 'packageName': packageName, 'enabled': enabled,
    });
  }

  Future<void> setAllAccounts({required String deviceId,
      required String packageName, required bool enabled}) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setWatchNotificationAllAccounts', {
      'deviceId': deviceId, 'packageName': packageName, 'enabled': enabled,
    });
  }

  Future<void> setAccount({required String deviceId, required String packageName,
      required String account, required bool enabled}) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setWatchNotificationAccount', {
      'deviceId': deviceId, 'packageName': packageName,
      'account': account, 'enabled': enabled,
    });
  }

  Future<void> openNotificationAccess() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<bool>('openNotificationAccess');
  }
}
