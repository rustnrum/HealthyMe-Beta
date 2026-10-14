import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/screens/preview84/screens/shell.dart';

void main() {
  for (final width in [360.0, 820.0]) {
    testWidgets('Build 84 original-assets Home and Health render at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: PreviewShell()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Recovery Score'), findsOneWidget);
      await tester.tap(find.text('Health').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Body Battery'), findsOneWidget);
    });
  }
}
