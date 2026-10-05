import 'dart:io';

import 'package:flutter/services.dart';

class VisibleHealthApp {
  final String packageName;
  final String label;

  const VisibleHealthApp({
    required this.packageName,
    required this.label,
  });
}

class HealthDiscoveryStatus {
  final bool matchmakingSupported;
  final bool matchmakingPossible;
  final int healthExtensionVersion;
  final List<VisibleHealthApp> visibleApps;
  final String message;

  const HealthDiscoveryStatus({
    required this.matchmakingSupported,
    required this.matchmakingPossible,
    required this.healthExtensionVersion,
    required this.visibleApps,
    required this.message,
  });
}

class NativeSourceDiscoveryService {
  static const MethodChannel _channel =
      MethodChannel('com.rustnrum.healthyme/source_discovery');

  Future<HealthDiscoveryStatus> status() async {
    if (!Platform.isAndroid) {
      return const HealthDiscoveryStatus(
        matchmakingSupported: false,
        matchmakingPossible: false,
        healthExtensionVersion: 0,
        visibleApps: [],
        message: 'Android source discovery is not available on this platform.',
      );
    }

    try {
      final raw =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('discoveryStatus');
      return _statusFromMap(raw ?? const {});
    } on PlatformException catch (error) {
      return HealthDiscoveryStatus(
        matchmakingSupported: false,
        matchmakingPossible: false,
        healthExtensionVersion: 0,
        visibleApps: const [],
        message: error.message ?? error.code,
      );
    }
  }

  Future<bool> launchMatchmaking() async {
    if (!Platform.isAndroid) return false;
    final raw =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('launchMatchmaking');
    return raw?['granted'] == true;
  }

  HealthDiscoveryStatus _statusFromMap(Map<dynamic, dynamic> raw) {
    final apps = (raw['visibleApps'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (app) => VisibleHealthApp(
            packageName: app['packageName']?.toString() ?? '',
            label: app['label']?.toString() ?? 'Health app',
          ),
        )
        .where((app) => app.packageName.isNotEmpty)
        .toList();

    return HealthDiscoveryStatus(
      matchmakingSupported: raw['matchmakingSupported'] == true,
      matchmakingPossible: raw['matchmakingPossible'] == true,
      healthExtensionVersion:
          (raw['healthExtensionVersion'] as num?)?.toInt() ?? 0,
      visibleApps: apps,
      message: raw['message']?.toString() ?? '',
    );
  }
}
