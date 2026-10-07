import 'dart:io';

import 'package:flutter/services.dart';

class NotificationAccessService {
  static const MethodChannel _channel =
      MethodChannel('com.rustnrum.healthyme/source_discovery');

  Future<bool> isEnabled() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('notificationAccessStatus') ??
        false;
  }

  Future<void> openSettings() async {
    if (!Platform.isAndroid) return;
    final opened =
        await _channel.invokeMethod<bool>('openNotificationAccess') ?? false;
    if (!opened) {
      throw StateError('Could not open Android notification access settings.');
    }
  }
}
