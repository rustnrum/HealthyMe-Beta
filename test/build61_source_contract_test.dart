import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('COLMI sleep decoder saves actual start and end timestamps', () {
    final code = File('native/android/SalusProtocolReader.kt').readAsStringSync();
    expect(code, contains('u16(payload, pointer + 2).toShort().toInt()'));
    expect(code, contains('u16(payload, pointer + 4).toShort().toInt()'));
    expect(code, contains('addHistoryMetric("Sleep start", 1.0, startTime)'));
    expect(code, contains('addHistoryMetric("Sleep end", 1.0, endTime)'));
    expect(code, contains('calendar.set(Calendar.HOUR_OF_DAY, 0)'));
  });

  test('direct sleep chart reads only the chosen source and real dated nights', () {
    final code = File('lib/services/direct_metric_service.dart').readAsStringSync();
    expect(code, contains("sample.sourceId != sleepSource"));
    expect(code, contains("sample.metric != 'Sleep'"));
    expect(code, contains('sleepMinutes7: directSleepSelected ? directSleepMinutes7'));
  });

  test('dubious calorie totals do not appear as factual activity readings', () {
    final activity = File('lib/screens/activity_screen.dart').readAsStringSync();
    expect(activity, contains('caloriesPlausible'));
    expect(activity, contains('Last saved Garmin total — not current'));
    final native = File('native/android/SalusProtocolReader.kt').readAsStringSync();
    expect(native, contains('ringCaloriesTotal in 1..15000'));
  });
}
