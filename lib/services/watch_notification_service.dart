import 'dart:io';

import 'package:flutter/services.dart';

class WatchNotificationAccount {
  final String name;
  final bool enabled;

  const WatchNotificationAccount({required this.name, required this.enabled});

  factory WatchNotificationAccount.fromMap(Map<dynamic, dynamic> map) =>
      WatchNotificationAccount(
        name: map['name']?.toString() ?? '',
        enabled: map['enabled'] == true,
      );
}

class WatchNotificationApp {
  final String packageName;
  final String label;
  final bool enabled;
  final bool allAccounts;
  final List<WatchNotificationAccount> accounts;

  const WatchNotificationApp({
    required this.packageName,
    required this.label,
    required this.enabled,
    this.allAccounts = true,
    this.accounts = const [],
  });

  bool get isGmail => packageName == 'com.google.android.gm';

  factory WatchNotificationApp.fromMap(Map<dynamic, dynamic> map) =>
      WatchNotificationApp(
        packageName: map['packageName']?.toString() ?? '',
        label: map['label']?.toString() ?? 'App',
        enabled: map['enabled'] == true,
        allAccounts: map['allAccounts'] != false,
        accounts: (map['accounts'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map(WatchNotificationAccount.fromMap)
            .where((item) => item.name.isNotEmpty)
            .toList(),
      );
}

class WatchNotificationState {
  final bool accessEnabled;
  final bool masterEnabled;
  final bool deliverySupported;
  final List<WatchNotificationApp> apps;
  final DateTime? lastObservedAt;
  final DateTime? lastEligibleAt;
  final String lastEligibleApp;

  const WatchNotificationState({
    required this.accessEnabled,
    required this.masterEnabled,
    required this.deliverySupported,
    required this.apps,
    this.lastObservedAt,
    this.lastEligibleAt,
    this.lastEligibleApp = '',
  });

  int get enabledAppCount => apps.where((app) => app.enabled).length;

  static DateTime? _fromEpoch(dynamic value) {
    if (value is! num || value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }

  factory WatchNotificationState.fromMap(Map<dynamic, dynamic> map) =>
      WatchNotificationState(
        accessEnabled: map['accessEnabled'] == true,
        masterEnabled: map['masterEnabled'] == true,
        deliverySupported: map['deliverySupported'] == true,
        lastObservedAt: _fromEpoch(map['lastObservedAt']),
        lastEligibleAt: _fromEpoch(map['lastEligibleAt']),
        lastEligibleApp: map['lastEligibleApp']?.toString() ?? '',
        apps: (map['apps'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map(WatchNotificationApp.fromMap)
            .where((item) => item.packageName.isNotEmpty)
            .toList(),
      );
}

class WatchNotificationService {
  static const MethodChannel _channel =
      MethodChannel('com.rustnrum.healthyme/source_discovery');

  Future<WatchNotificationState> load({
    required String deviceId,
    required String protocolId,
    required String deviceName,
  }) async {
    if (!Platform.isAndroid) {
      return const WatchNotificationState(
        accessEnabled: false,
        masterEnabled: false,
        deliverySupported: false,
        apps: [],
      );
    }
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getWatchNotificationState',
      <String, dynamic>{
        'deviceId': deviceId,
        'protocolId': protocolId,
        'deviceName': deviceName,
      },
    );
    return WatchNotificationState.fromMap(
      raw ?? const <dynamic, dynamic>{},
    );
  }

  Future<void> setMaster({
    required String deviceId,
    required String protocolId,
    required String deviceName,
    required bool enabled,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>(
      'setWatchNotificationMaster',
      <String, dynamic>{
        'deviceId': deviceId,
        'protocolId': protocolId,
        'deviceName': deviceName,
        'enabled': enabled,
      },
    );
  }

  Future<void> setApp({
    required String deviceId,
    required String packageName,
    required bool enabled,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>(
      'setWatchNotificationApp',
      <String, dynamic>{
        'deviceId': deviceId,
        'packageName': packageName,
        'enabled': enabled,
      },
    );
  }

  Future<void> setAllAccounts({
    required String deviceId,
    required String packageName,
    required bool enabled,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>(
      'setWatchNotificationAllAccounts',
      <String, dynamic>{
        'deviceId': deviceId,
        'packageName': packageName,
        'enabled': enabled,
      },
    );
  }

  Future<void> setAccount({
    required String deviceId,
    required String packageName,
    required String account,
    required bool enabled,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>(
      'setWatchNotificationAccount',
      <String, dynamic>{
        'deviceId': deviceId,
        'packageName': packageName,
        'account': account,
        'enabled': enabled,
      },
    );
  }

  Future<void> openNotificationAccess() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<bool>('openNotificationAccess');
  }
}
