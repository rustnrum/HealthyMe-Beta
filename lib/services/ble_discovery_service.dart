import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_protocol_profiles.dart';

class BleDeviceCandidate {
  final String id;
  final String name;
  final int rssi;
  final List<String> advertisedServices;
  final List<String> capabilities;
  final String? protocolProfile;
  final String? protocolId;
  final String? protocolNote;
  final String deviceKind;
  final String manufacturerDataHex;
  final String bondState;

  const BleDeviceCandidate({
    required this.id,
    required this.name,
    required this.rssi,
    required this.advertisedServices,
    required this.capabilities,
    required this.protocolProfile,
    this.protocolId,
    required this.protocolNote,
    this.deviceKind = 'Health device',
    required this.manufacturerDataHex,
    this.bondState = 'unknown',
  });

  bool get hasKnownCapabilities =>
      capabilities.isNotEmpty || protocolProfile != null;
}

class BleServiceInspection {
  final String serviceUuid;
  final List<String> characteristicDetails;

  const BleServiceInspection({
    required this.serviceUuid,
    required this.characteristicDetails,
  });
}

class BleDeviceInspection {
  final List<BleServiceInspection> services;
  final List<String> capabilities;
  final String? protocolProfile;
  final String? protocolId;
  final String? protocolNote;
  final String deviceKind;

  const BleDeviceInspection({
    required this.services,
    required this.capabilities,
    required this.protocolProfile,
    this.protocolId,
    required this.protocolNote,
    this.deviceKind = 'Health device',
  });
}

class BlePairResult {
  final bool usable;
  final bool bonded;
  final String state;
  final String message;

  const BlePairResult({
    required this.usable,
    required this.bonded,
    required this.state,
    required this.message,
  });
}

class BleDiscoveryService {
  static const MethodChannel _channel =
      MethodChannel('com.rustnrum.healthyme/source_discovery');

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;

    final statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final scan = statuses[Permission.bluetoothScan];
    final connect = statuses[Permission.bluetoothConnect];

    if (scan != PermissionStatus.granted ||
        connect != PermissionStatus.granted) {
      throw StateError(
        'Bluetooth scan/connect permission is required to use nearby health devices.',
      );
    }
  }

  Future<List<BleDeviceCandidate>> scan({
    Duration duration = const Duration(seconds: 8),
  }) async {
    if (!Platform.isAndroid) return const [];
    await _requestPermissions();

    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'scanBle',
        <String, dynamic>{'durationMs': duration.inMilliseconds},
      );

      final devices = (raw ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(_candidateFromMap)
          .toList()
        ..sort((a, b) {
          if (a.hasKnownCapabilities != b.hasKnownCapabilities) {
            return a.hasKnownCapabilities ? -1 : 1;
          }
          return b.rssi.compareTo(a.rssi);
        });

      return devices;
    } on PlatformException catch (error) {
      throw StateError(error.message ?? error.code);
    }
  }

  Future<BleDeviceInspection> inspect(BleDeviceCandidate device) async {
    if (!Platform.isAndroid) {
      throw StateError('Bluetooth inspection is only available on Android.');
    }
    await _requestPermissions();

    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'inspectBle',
        <String, dynamic>{'deviceId': device.id},
      );

      final map = raw ?? const <dynamic, dynamic>{};
      final services = (map['services'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (service) => BleServiceInspection(
              serviceUuid: service['serviceUuid']?.toString() ?? '',
              characteristicDetails:
                  (service['characteristics'] as List<dynamic>? ?? const [])
                      .map((value) => value.toString())
                      .toList(),
            ),
          )
          .where((service) => service.serviceUuid.isNotEmpty)
          .toList();

      final report = BleProtocolProfiles.analyze(
        services.map((service) => service.serviceUuid),
        name: device.name,
      );

      return BleDeviceInspection(
        services: services,
        capabilities: report.allCapabilities,
        protocolProfile: report.protocolProfile?.label,
        protocolId: report.protocolProfile?.id,
        protocolNote: report.protocolProfile?.note,
        deviceKind: report.deviceKind,
      );
    } on PlatformException catch (error) {
      throw StateError(error.message ?? error.code);
    }
  }

  Future<BlePairResult> pair(BleDeviceCandidate device) async {
    if (!Platform.isAndroid) {
      throw StateError('Direct Bluetooth pairing is only available on Android.');
    }
    await _requestPermissions();

    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'pairBle',
        <String, dynamic>{'deviceId': device.id},
      );
      final map = raw ?? const <dynamic, dynamic>{};
      return BlePairResult(
        usable: map['usable'] != false,
        bonded: map['bonded'] == true,
        state: map['state']?.toString() ?? 'unknown',
        message: map['message']?.toString() ??
            'Device is available for direct Salus communication.',
      );
    } on PlatformException catch (error) {
      throw StateError(error.message ?? error.code);
    }
  }

  BleDeviceCandidate _candidateFromMap(Map<dynamic, dynamic> raw) {
    final services =
        (raw['advertisedServices'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => value.toString())
            .toList();
    final rawName = raw['name']?.toString().trim() ?? '';
    final name = rawName.isEmpty ? 'Unnamed BLE device' : rawName;
    final report = BleProtocolProfiles.analyze(services, name: name);

    return BleDeviceCandidate(
      id: raw['id']?.toString() ?? '',
      name: name,
      rssi: (raw['rssi'] as num?)?.toInt() ?? -127,
      advertisedServices: services,
      capabilities: report.allCapabilities,
      protocolProfile: report.protocolProfile?.label,
      protocolId: report.protocolProfile?.id,
      protocolNote: report.protocolProfile?.note,
      deviceKind: report.deviceKind,
      manufacturerDataHex: raw['manufacturerDataHex']?.toString() ?? '',
      bondState: raw['bondState']?.toString() ?? 'unknown',
    );
  }
}
