import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'direct_metric_service.dart';

/// Best-effort, standards-only watch charge probe.
/// Garmin Body Battery is an energy metric and MUST NOT be reported as
/// the hardware battery percentage. No assumed/fake battery percentage.
class GarminBatteryService {
  static const _channel =
      MethodChannel('com.rustnrum.healthyme/source_discovery');
  static const _metricStore = 'salus_direct_metric_samples_v1';
  static const _statusKeyPrefix = 'salus_garmin_charge_probe_';
  static const _capabilityKeyPrefix = 'salus_garmin_standard_charge_';

  static double? validatedPercentage(Map<dynamic, dynamic>? result) {
    final raw = result?['metrics'];
    if (raw is! Map) return null;
    final value = raw['Battery'];
    // Explicitly NOT `Body battery` from Garmin's energy telemetry.
    if (value is! num || !value.toDouble().isFinite) return null;
    if (value < 0 || value > 100) return null;
    return value.toDouble();
  }

  Future<String?> lastResult(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_statusKeyPrefix$deviceId');
  }

  Future<bool> knownStandardBattery(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_capabilityKeyPrefix$deviceId') ?? false;
  }

  /// Uses the existing Android readStandardMetrics channel, which reads
  /// service 0x180F / characteristic 0x2A19 if actually advertised.
  /// Does not interfere with Garmin proprietary pairing or write settings.
  Future<String> check(String deviceId, String deviceName) async {
    if (!Platform.isAndroid) return 'Android Bluetooth is required.';
    final prefs = await SharedPreferences.getInstance();
    String description;
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'readStandardMetrics',
        <String, dynamic>{
          'deviceId': deviceId,
          'durationMs': 4500,
        },
      ).timeout(const Duration(seconds: 13));
      final battery = validatedPercentage(result);
      if (battery == null) {
        description = 'No readable standard Bluetooth Battery Level (0x2A19) '
            'was returned by this Garmin. The separate Garmin device-status '
            'battery reader is not implemented yet.';
        // Do NOT overwrite a previously verified reading with a guessed value.
      } else {
        final sample = DirectMetricSample(
          sourceId: 'ble:$deviceId',
          deviceId: deviceId,
          deviceName: deviceName,
          metric: 'Battery',
          value: battery,
          unit: '%',
          capturedAt: DateTime.now(),
        );
        await _save(sample, prefs);
        await prefs.setBool('$_capabilityKeyPrefix$deviceId', true);
        description = 'Garmin battery ${battery.round()}% '
            '— verified using Bluetooth Battery Level.';
      }
    } catch (error) {
      description = 'Garmin charge check failed: $error. '
          'Garmin Connect may be using the Bluetooth connection.';
    }
    await prefs.setString('$_statusKeyPrefix$deviceId', description);
    return description;
  }

  Future<void> _save(
    DirectMetricSample sample,
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_metricStore);
    final all = <Map<String, dynamic>>[];
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final row in decoded) {
          if (row is Map) {
            all.add(Map<String, dynamic>.from(row));
          }
        }
      }
    }
    final cutoff = DateTime.now().subtract(const Duration(days: 370));
    all.removeWhere((row) {
      final date = DateTime.tryParse(row['capturedAt']?.toString() ?? '');
      return date == null || date.isBefore(cutoff);
    });
    all.add(sample.toJson());
    all.sort((a, b) =>
        (a['capturedAt'] as String).compareTo(b['capturedAt'] as String));
    if (all.length > 3200) all.removeRange(0, all.length - 3200);
    final ok = await prefs.setString(_metricStore, jsonEncode(all));
    if (!ok) throw StateError('Could not save the Garmin battery sample.');
  }
}
