import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Per-device Android BLE security evidence is collected without claiming delivery', () {
    final native = File('native/android/SalusBluetoothDiagnostics.kt').readAsStringSync();
    final store = File('native/android/SalusWatchTransportStatus.kt').readAsStringSync();
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    final service = File('lib/services/watch_notification_service.dart').readAsStringSync();
    final screen = File('lib/screens/watch_device_screen.dart').readAsStringSync();

    expect(native, contains('ACTION_BOND_STATE_CHANGED'));
    expect(native, contains('action.ENCRYPTION_CHANGE'));
    expect(native, contains('getEncryptionStatus'));
    expect(native, contains('getAlgorithm'));
    expect(native, contains('getKeySize'));
    expect(native, contains('Not queryable on this Android release'));
    expect(native, contains('ENCRYPTION REQUIRED (15)'));
    expect(native, contains('AUTHENTICATION REQUIRED (5)'));
    expect(native, contains('keySize in 1..16'));
    expect(native, isNot(contains('getLtk')));
    expect(store, contains('SalusBluetoothDiagnostics.snapshot(context, deviceId)'));
    expect(sender, contains('SalusBluetoothDiagnostics.watch(app, deviceId)'));
    expect(sender, contains('SalusBluetoothDiagnostics.unwatch(app, deviceId)'));
    expect(sender, contains('"Garmin GFDI confirmed; 5035 data ACK received (display NOT verified)"'));
    expect(service, contains('securityEncryption: json['));
    expect(screen, contains('Active BLE encryption: \${state.securityEncryption}'));
    expect(screen, contains('Bluetooth security errors: \${state.securityLastError}'));
    expect(screen, contains('A data acknowledgment does not prove the watch displayed an alert.'));
  });
}
