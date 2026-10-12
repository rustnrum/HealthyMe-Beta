import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'direct_device_store.dart';

/// Only manufacturer/model/revisions and observed service UUIDs are stored.
/// No Bluetooth serial number, proprietary writes, or firmware update support.
class BleDeviceInformation {
  final String deviceId;
  final String deviceName;
  final DateTime checkedAt;
  final String status;
  final bool disAvailable;
  final Map<String, String> values;
  final List<String> serviceUuids;
  final List<String> notes;
  final List<String> firmwareHistory;

  const BleDeviceInformation({
    required this.deviceId,
    required this.deviceName,
    required this.checkedAt,
    required this.status,
    required this.disAvailable,
    required this.values,
    required this.serviceUuids,
    required this.notes,
    required this.firmwareHistory,
  });

  String? get firmware => values['firmware'];
  String? get hardware => values['hardware'];
  String? get model => values['model'];
  String? get manufacturer => values['manufacturer'];

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'checkedAt': checkedAt.toIso8601String(),
    'status': status,
    'disAvailable': disAvailable,
    'values': values,
    'serviceUuids': serviceUuids,
    'notes': notes,
    'firmwareHistory': firmwareHistory,
  };

  factory BleDeviceInformation.fromJson(Map<String, dynamic> raw) =>
      BleDeviceInformation(
        deviceId: raw['deviceId']?.toString() ?? '',
        deviceName: raw['deviceName']?.toString() ?? 'Bluetooth device',
        checkedAt: DateTime.tryParse(raw['checkedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        status: raw['status']?.toString() ?? 'unavailable',
        disAvailable: raw['disAvailable'] == true,
        values: (raw['values'] is Map)
            ? (raw['values'] as Map).map(
                (k, v) => MapEntry(k.toString(), v.toString()))
            : const {},
        serviceUuids: (raw['serviceUuids'] as List? ?? const [])
            .map((x) => x.toString()).toList(),
        notes: (raw['notes'] as List? ?? const [])
            .map((x) => x.toString()).toList(),
        firmwareHistory: (raw['firmwareHistory'] as List? ?? const [])
            .map((x) => x.toString()).toList(),
      );
}

class BleDeviceInformationService {
  static const _channel = MethodChannel('com.rustnrum.healthyme/source_discovery');
  static const _prefix = 'salus_device_information_v1_';

  static String cacheKey(String id) => '$_prefix${base64Url.encode(utf8.encode(id))}';

  Future<BleDeviceInformation?> load(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(cacheKey(deviceId));
    if (saved == null) return null;
    try {
      final json = jsonDecode(saved);
      if (json is Map<String, dynamic>) {
        final data = BleDeviceInformation.fromJson(json);
        return data.deviceId == deviceId ? data : null;
      }
    } catch (_) {
      // Corrupt cache never prevents reinspection.
    }
    return null;
  }

  static List<String> revisionHistory(
    BleDeviceInformation? previous,
    String? newFirmware,
    DateTime checkedAt,
  ) {
    final past = previous?.firmwareHistory ?? const <String>[];
    final before = previous?.firmware;
    if (before == null || before.isEmpty || newFirmware == null ||
        newFirmware.isEmpty || before == newFirmware) return past;
    return [
      ...past,
      '${checkedAt.toUtc().toIso8601String()} • $before → $newFirmware',
    ].take(20).toList();
  }

  Future<BleDeviceInformation> refresh(SavedDirectDevice device) async {
    if (!Platform.isAndroid) {
      throw StateError('Bluetooth device information is supported on Android.');
    }
    final access = await Permission.bluetoothConnect.request();
    if (!access.isGranted) {
      throw StateError('Allow Bluetooth connection permission to inspect this device.');
    }
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'readBleDeviceInfo', {'deviceId': device.id},
    );
    if (raw == null) throw StateError('The device did not return information.');
    final values = (raw['values'] as Map? ?? const {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );
    final now = DateTime.now();
    final previous = await load(device.id);
    // A timeout/no-DIS result must not erase earlier verified revision fields.
    final merged = {...?previous?.values, ...values};
    final current = BleDeviceInformation(
      deviceId: device.id,
      deviceName: device.name,
      checkedAt: now,
      status: raw['status']?.toString() ?? 'unavailable',
      disAvailable: raw['disAvailable'] == true,
      values: merged,
      serviceUuids: (raw['serviceUuids'] as List? ?? const [])
          .map((x) => x.toString()).toList(),
      notes: (raw['notes'] as List? ?? const [])
          .map((x) => x.toString()).toList(),
      firmwareHistory: revisionHistory(previous, values['firmware'], now),
    );
    // Preserve a last-known service inventory when the ring was unreachable.
    final persisted = BleDeviceInformation(
      deviceId: current.deviceId,
      deviceName: current.deviceName,
      checkedAt: current.checkedAt,
      status: current.status,
      disAvailable: current.disAvailable || (previous?.disAvailable ?? false),
      values: current.values,
      serviceUuids: current.serviceUuids.isNotEmpty
          ? current.serviceUuids : (previous?.serviceUuids ?? const []),
      notes: current.notes,
      firmwareHistory: current.firmwareHistory,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey(device.id), jsonEncode(persisted.toJson()));
    return persisted;
  }
}
