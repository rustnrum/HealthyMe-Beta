import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ble_discovery_service.dart';

class SavedDirectDevice {
  final String id;
  final String name;
  final String deviceKind;
  final String? protocolId;
  final String? protocolLabel;
  final List<String> capabilities;
  final bool bonded;
  final String pairState;
  final DateTime savedAt;

  const SavedDirectDevice({
    required this.id,
    required this.name,
    required this.deviceKind,
    required this.protocolId,
    required this.protocolLabel,
    required this.capabilities,
    required this.bonded,
    required this.pairState,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'deviceKind': deviceKind,
        'protocolId': protocolId,
        'protocolLabel': protocolLabel,
        'capabilities': capabilities,
        'bonded': bonded,
        'pairState': pairState,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedDirectDevice.fromJson(Map<String, dynamic> json) =>
      SavedDirectDevice(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Bluetooth device',
        deviceKind: json['deviceKind']?.toString() ?? 'Bluetooth health device',
        protocolId: json['protocolId']?.toString(),
        protocolLabel: json['protocolLabel']?.toString(),
        capabilities:
            (json['capabilities'] as List<dynamic>? ?? const <dynamic>[])
                .map((value) => value.toString())
                .toList(),
        bonded: json['bonded'] == true,
        pairState: json['pairState']?.toString() ?? 'direct',
        savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class DirectDeviceStore {
  static const _key = 'salus_direct_devices_v1';

  Future<List<SavedDirectDevice>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final devices = decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedDirectDevice.fromJson)
          .where((device) => device.id.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return devices;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save({
    required BleDeviceCandidate device,
    BleDeviceInspection? inspection,
    required BlePairResult pair,
  }) async {
    final devices = await load();
    final next = SavedDirectDevice(
      id: device.id,
      name: device.name,
      deviceKind: inspection?.deviceKind ?? device.deviceKind,
      protocolId: inspection?.protocolId ?? device.protocolId,
      protocolLabel: inspection?.protocolProfile ?? device.protocolProfile,
      capabilities: inspection?.capabilities ?? device.capabilities,
      bonded: pair.bonded,
      pairState: pair.state,
      savedAt: DateTime.now(),
    );
    final updated = [
      for (final item in devices)
        if (item.id != device.id) item,
      next,
    ];
    await _write(updated);
  }

  Future<void> remove(String id) async {
    final devices = await load();
    await _write(devices.where((device) => device.id != id).toList());
  }

  Future<void> _write(List<SavedDirectDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final value = jsonEncode(devices.map((device) => device.toJson()).toList());
    await prefs.setString(_key, value);
  }
}
