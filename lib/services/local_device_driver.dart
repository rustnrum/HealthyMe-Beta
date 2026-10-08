import 'package:flutter/services.dart';

import 'ble_protocol_profiles.dart';

/// The results of a local, capability-first driver decision. A detected family
/// is not the same thing as a working data decoder.
enum SalusDriverStatus { ready, standardOnly, recognizedOnly, unknown }

class SalusDriverDecision {
  const SalusDriverDecision({
    required this.id,
    required this.status,
    required this.deviceKind,
    required this.supportedMetrics,
    required this.note,
  });

  final String id;
  final SalusDriverStatus status;
  final String deviceKind;
  final List<String> supportedMetrics;
  final String note;

  bool get canRead =>
      status == SalusDriverStatus.ready ||
      status == SalusDriverStatus.standardOnly;
}

/// The BLE transport is injected, so matching and dispatch can be tested
/// without a device, permissions, or an Android emulator.
abstract class SalusBleDriverTransport {
  Future<Map<dynamic, dynamic>> invoke(
    String method,
    Map<String, dynamic> arguments,
  );
}

class AndroidSalusBleTransport implements SalusBleDriverTransport {
  const AndroidSalusBleTransport();
  static const _channel =
      MethodChannel('com.rustnrum.healthyme/source_discovery');

  @override
  Future<Map<dynamic, dynamic>> invoke(
    String method,
    Map<String, dynamic> arguments,
  ) async =>
      (await _channel.invokeMethod<Map<dynamic, dynamic>>(
        method,
        arguments,
      )) ??
      <dynamic, dynamic>{};
}

/// Local registry plus standardized transport dispatch. Protocol decoding in
/// the legacy native reader remains a backend behind this interface.
/// Adding new local drivers does not require editing the UI or data store.
class SalusLocalDeviceDrivers {
  const SalusLocalDeviceDrivers({
    SalusBleDriverTransport transport = const AndroidSalusBleTransport(),
  }) : _transport = transport;

  final SalusBleDriverTransport _transport;

  static const _nativeProtocolIds = {
    'ring-uart-v1',
    'garmin-family',
    'cpap-family',
  };

  SalusDriverDecision match({
    required String name,
    required String? protocolId,
    Iterable<String> services = const [],
    String? deviceKind,
  }) {
    final report = BleProtocolProfiles.analyze(services, name: name);
    final effectiveId = protocolId ?? report.protocolProfile?.id;
    final profile = BleProtocolProfiles.profiles.where(
      (candidate) => candidate.id == effectiveId,
    );
    final knownProfile = profile.isEmpty ? null : profile.first;
    final standard = report.standardCapabilities;
    final kind = deviceKind ?? knownProfile?.deviceKind ?? report.deviceKind;

    if (_nativeProtocolIds.contains(effectiveId) &&
        knownProfile?.dataReaderReady == true) {
      return SalusDriverDecision(
        id: effectiveId!,
        status: SalusDriverStatus.ready,
        deviceKind: kind,
        supportedMetrics: knownProfile!.capabilities,
        note: 'Bundled native protocol reader available.',
      );
    }
    if (standard.isNotEmpty) {
      // Only the battery and heart-rate standard GATT decoders are wired up
      // in this Android backend at present. Other advertised services are
      // discoverable but may need an additional decoder.
      return SalusDriverDecision(
        id: 'standard-gatt',
        status: SalusDriverStatus.standardOnly,
        deviceKind: kind,
        supportedMetrics: standard.where((metric) =>
            metric == 'Battery' || metric == 'Heart rate').toList(),
        note: 'Standard GATT access; reads only implemented characteristics.',
      );
    }
    if (effectiveId != null && effectiveId.isNotEmpty) {
      return SalusDriverDecision(
        id: effectiveId,
        status: SalusDriverStatus.recognizedOnly,
        deviceKind: kind,
        supportedMetrics: const [],
        note: 'Device family detected but no compatible health-data reader is installed.',
      );
    }
    return SalusDriverDecision(
      id: 'unknown',
      status: SalusDriverStatus.unknown,
      deviceKind: kind,
      supportedMetrics: const [],
      note: 'No compatible proprietary reader identified. Standard GATT probe is available.',
    );
  }

  Future<Map<dynamic, dynamic>> read({
    required String deviceId,
    required String deviceName,
    required String? protocolId,
    required String deviceKind,
    Iterable<String> advertisedServices = const [],
    required Duration duration,
    String? cpapPasskey,
  }) async {
    final decision = match(
      name: deviceName,
      protocolId: protocolId,
      services: advertisedServices,
      deviceKind: deviceKind,
    );
    final standardArgs = <String, dynamic>{
      'deviceId': deviceId,
      'durationMs': duration.inMilliseconds,
    };
    if (decision.status == SalusDriverStatus.ready) {
      final raw = await _transport.invoke('readProtocolMetrics', {
        ...standardArgs,
        'deviceName': deviceName,
        'protocolId': decision.id,
        'cpapPasskey': cpapPasskey,
      });
      if (raw['fallbackStandard'] != true) return raw;
      // A backend may reject a profile when the actual services differ.
      return _transport.invoke('readStandardMetrics', standardArgs);
    }
    // Unsupported or unrecognized families must not invoke proprietary
    // commands. A read-only standard probe may still find battery/heart rate.
    final raw = await _transport.invoke('readStandardMetrics', standardArgs);
    if (raw['metrics'] is Map && (raw['metrics'] as Map).isNotEmpty) return raw;
    return <dynamic, dynamic>{
      ...raw,
      'metrics': raw['metrics'] ?? <String, double>{},
      'reader': 'standard-gatt',
      'message': '${decision.note} No verified standard readings were returned.',
      'driverId': decision.id,
      'driverStatus': decision.status.name,
    };
  }
}
