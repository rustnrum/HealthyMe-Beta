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
  final String? protocolNote;
  final String manufacturerDataHex;

  const BleDeviceCandidate({
    required this.id,
    required this.name,
    required this.rssi,
    required this.advertisedServices,
    required this.capabilities,
    required this.protocolProfile,
    required this.protocolNote,
    required this.manufacturerDataHex,
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
  final String? protocolNote;

  const BleDeviceInspection({
    required this.services,
    required this.capabilities,
    required this.protocolProfile,
    required this.protocolNote,
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
        'Bluetooth scan/connect permission is required to discover nearby health devices.',
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
      );

      return BleDeviceInspection(
        services: services,
        capabilities: report.allCapabilities,
        protocolProfile: report.protocolProfile?.label,
        protocolNote: report.protocolProfile?.note,
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
    final report = BleProtocolProfiles.analyze(services);

    final rawName = raw['name']?.toString().trim() ?? '';

    return BleDeviceCandidate(
      id: raw['id']?.toString() ?? '',
      name: rawName.isEmpty ? 'Unnamed BLE device' : rawName,
      rssi: (raw['rssi'] as num?)?.toInt() ?? -127,
      advertisedServices: services,
      capabilities: report.allCapabilities,
      protocolProfile: report.protocolProfile?.label,
      protocolNote: report.protocolProfile?.note,
      manufacturerDataHex: raw['manufacturerDataHex']?.toString() ?? '',
    );
  }
}
