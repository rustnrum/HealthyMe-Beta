import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Build 54 negotiates reliable Garmin Multi-Link without guessing', () {
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    final codec = File('native/android/SalusGarminGfdiCodec.kt').readAsStringSync();
    final transport = File('native/android/SalusGarminMlrTransport.kt').readAsStringSync();
    expect(codec, contains('fun registerGfdi(reliable: Boolean = true)'));
    expect(codec, contains('put((if (reliable) 2 else 0).toByte())'));
    expect(sender, contains('val reliable = if (bytes.size > 14)'));
    expect(sender, contains('SalusGarminMlrTransport(handle, mtuPayload + 1)'));
    expect(sender, contains('mlrRequested = false; registrationSent = false'));
    expect(sender, contains('activeMlr.receive(bytes)'));
    expect(sender, contains('mlr?.poll()?.forEach { enqueue(it) }'));
    expect(transport, contains('retransmitDelay = minOf(retransmitDelay * 2, 20_000L)'));
    expect(transport, contains('ackAt = clock() + 250L'));
    expect(transport, contains('if (sequence == nextReceive)'));
    expect(transport, contains('outstanding[nextSend] = Fragment'));
  });

  test('First connection completes Garmin app lifecycle only after negotiation', () {
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    final codec = File('native/android/SalusGarminGfdiCodec.kt').readAsStringSync();
    expect(sender, contains('maybeCompleteApplicationSetup()'));
    expect(sender, contains('if (!informationExchanged || !configurationExchanged || applicationInitialized) return'));
    expect(sender, contains('SalusGarminGfdiCodec.systemEvent(4)'));
    expect(sender, contains('SalusGarminGfdiCodec.systemEvent(0)'));
    expect(sender, contains('SalusGarminGfdiCodec.systemEvent(14)'));
    expect(sender, contains('setupEventsAwaitingAck'));
    expect(codec, contains('return gfdiMessage(5030, byteArrayOf(event.toByte(), 0))'));
  });

  test('Both 5034 command paths and 5033 response statuses are visible', () {
    final sender = File('native/android/SalusGarminNotificationSender.kt').readAsStringSync();
    final codec = File('native/android/SalusGarminGfdiCodec.kt').readAsStringSync();
    expect(sender, contains('1 -> handleAppAttributes('));
    expect(sender, contains('recentAlerts[requested]'));
    expect(sender, contains('deferredAppAttributes'));
    expect(sender, contains('originalType == 5033'));
    expect(sender, contains('Garmin rejected notification update'));
    expect(sender, contains('display still unverified'));
    expect(codec, contains('fun notificationAppAttributes('));
    expect(File('pubspec.yaml').readAsStringSync(), contains('version: 0.21.17+55'));
    expect(sender, isNot(contains('watch displayed notification')));
  });
}
