import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bonding is device specific, asynchronously confirmed, bounded, and permission guarded', () {
    final code = File('native/android/SalusSafeBondManager.kt').readAsStringSync();
    expect(code, contains('BluetoothDevice.ACTION_BOND_STATE_CHANGED'));
    expect(code, contains('changed?.address != address'));
    expect(code, contains('BluetoothDevice.BOND_BONDED'));
    expect(code, contains('BluetoothDevice.BOND_BONDING'));
    expect(code, contains('BLUETOOTH_CONNECT'));
    expect(code, contains('60_000L'));
    expect(code, contains('context.unregisterReceiver(it)'));
    expect(code, isNot(contains('Cipher')));
  });
  test('Garmin has client transport and real initialization handlers', () {
    final driver = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    final codec = File('native/android/SalusGarminGfdiCodec.kt').readAsStringSync();
    final bridge = File('scripts/patch_build47.py').readAsStringSync();
    expect(driver, contains('device.connectGatt'));
    expect(driver, contains('SalusSafeBondManager(app)'));
    for (final message in [5024, 5050, 5052, 5101, 5036]) {
      expect(driver, contains('$message ->'));
    }
    expect(driver, contains('subscriptionSeen'));
    expect(driver, contains('Subscription not received'));
    expect(driver, contains('Watch notifications off'));
    expect(codec, contains('deviceInformationResponse'));
    expect(codec, contains('configurationResponse'));
    expect(codec, contains('authNegotiationResponse'));
    expect(codec, contains('currentTimeResponse'));
    expect(codec, contains('syncReady'));
    expect(bridge, contains('SalusGarminNotificationSender.watch(this, deviceId, true)'));
    expect(driver, isNot(contains('openGattServer')));
  });
  test('Source keeps signing package and user data identity', () {
    expect(File('pubspec.yaml').readAsStringSync(),
        matches(RegExp(r'version: 0\.21\.\d+\+\d+')));
    expect(File('native/android/SalusGarminNotificationSender.kt').readAsStringSync(),
        contains('package com.rustnrum.healthyme.beta03'));
  });
}
