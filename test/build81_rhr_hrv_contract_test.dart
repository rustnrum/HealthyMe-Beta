import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/widgets/salus77_design.dart';

void main() {
  testWidgets('Resting-HR painter receives width inside a loose Column', (tester) async {
    // Mimics the actual narrow Home trend card; Build 80 laid out a zero-width
    // CustomPaint and painted no HR axes or points even with valid measurements.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 166, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [S77RestingHeartChart(values: [57, 62, 64], height: 108)],
      )),
    ))));
    final paint = find.descendant(
      of: find.byType(S77RestingHeartChart),
      matching: find.byType(CustomPaint),
    );
    expect(paint, findsOneWidget);
    final box = tester.renderObject<RenderBox>(paint);
    expect(box.size.width, greaterThan(52));
    expect(box.size.height, 108);
    expect(tester.takeException(), isNull);
  });

  testWidgets('No resting-HR trend is drawn without two real records', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 170, child: S77RestingHeartChart(
        values: [57], height: 108,
      )),
    ))));
    expect(find.text('More recorded days needed for a trend'), findsOneWidget);
  });

  test('Home HRV guides user to selected source, not a fabricated plot', () {
    final home=File('lib/screens/premium/salus_home_77.dart').readAsStringSync();
    expect(home, contains('No verified HRV trend yet'));
    expect(home, contains('Tap to check your HRV source and history'));
    expect(home, contains("'/metric-hrv'"));
    final direct=File('lib/services/direct_metric_service.dart').readAsStringSync();
    expect(direct, contains('isLegacyGarminHrv'));
    expect(File('pubspec.yaml').readAsStringSync(),contains('version: 0.21.49+87'));
  });
}
