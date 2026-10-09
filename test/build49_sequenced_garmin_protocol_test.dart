import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Garmin compact header and sequence are preserved in the source implementation', () {
    final codec = File('native/android/SalusGarminGfdiCodec.kt').readAsStringSync();
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    expect(codec, contains('data class Frame(val type: Int, val payload: ByteArray, val sequence: Int?)'));
    expect(codec, contains('5000 + (packet[2].toInt() and 255)'));
    expect(codec, contains('high and 0x1f'));
    expect(codec, contains('(0x80 or sequence).toByte()'));
    expect(codec, contains('protobufChunkAck'));
    expect(sender, contains('SalusGarminGfdiCodec.decodeFrame(decoded)'));
    expect(sender, contains('processGfdi(message.type, message.payload, message.sequence)'));
    expect(sender, contains('notificationSubscriptionResponse('));
    expect(sender, contains('payload[1].toInt() and 255, sequence))'));
    expect(sender, contains('protobufChunkAck(5043, requestId, offset, sequence)'));
  });

  test('Garmin sequenced byte fixtures remain tracked', () {
    final harness = File('test/garmin_sequenced_gfdi_check.kt').readAsStringSync();
    for (final raw in ['0x8624 to 5036','0x852B to 5043','0x832B to 5043','0x842B to 5043']) {
      expect(harness, contains(raw));
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.11+49'));
  });
}
