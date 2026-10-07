import 'dart:io';

import 'package:flutter/services.dart';

class CpapPairingService {
  static const MethodChannel _channel =
      MethodChannel('com.rustnrum.healthyme/source_discovery');

  Future<bool> hasSavedPairing(String deviceId) async {
    if (!Platform.isAndroid || deviceId.isEmpty) return false;
    return await _channel.invokeMethod<bool>(
          'cpapHasSavedPairing',
          <String, dynamic>{'deviceId': deviceId},
        ) ??
        false;
  }

  Future<bool> resetPairing(String deviceId) async {
    if (!Platform.isAndroid || deviceId.isEmpty) return false;
    return await _channel.invokeMethod<bool>(
          'resetCpapPairing',
          <String, dynamic>{'deviceId': deviceId},
        ) ??
        false;
  }
}
