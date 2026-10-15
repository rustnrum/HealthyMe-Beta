import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/screens/premium/salus_home_85.dart';

void main() {
  test('Build 85 uses the Home mountain candidate and unchanged original ring', () {
    expect(File('assets/premium/salus_mountain_85.webp').existsSync(), isTrue);
    expect(File('assets/preview84/img/ring_recovery.png').existsSync(), isTrue);
    final home = File('lib/screens/premium/salus_home_85.dart').readAsStringSync();
    final shell = File('lib/screens/home_shell.dart').readAsStringSync();
    expect(home, contains('assets/premium/salus_mountain_85.webp'));
    expect(home, contains('assets/preview84/img/ring_recovery.png'));
    expect(shell, contains('SalusHome85()'));
    expect(shell, contains('index == 0'));
  });

  for (final size in const [
    Size(320, 720),
    Size(360, 800),
    Size(412, 920),
    Size(650, 850),
    Size(820, 960),
    Size(1100, 980),
  ]) {
    testWidgets('Approved Home layout has no exceptions at ${size.width} x ${size.height}',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: RepaintBoundary(
            key: Key('salus-home-render-review'),
            child: SalusHome85(),
          )),
          routes: {
            '/workout': (_) => const Scaffold(body: Text('Workout module')),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Recovery Score'), findsOneWidget);
      expect(find.text('DESIGN PREVIEW  ·  SAMPLE DATA'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      // Do not export screenshots during flutter test. On Linux CI the
      // RenderRepaintBoundary.toImage/PNG export stalled at exactly the
      // three capture widths and hit Flutter's 10-minute test timeout.
      // Visual screenshots are a separate review task; this blocking test
      // deliberately checks real widget layout and scrolling only.
      // Explicitly verify the available width of the actual two-column
      // Recovery card, not just the absence of a framework error.
      if (size.width == 320) {
        expect(tester.getSize(find.byKey(const Key('home-recovery-ring'))).width,
            lessThanOrEqualTo(120));
        expect(tester.getSize(find.byKey(const Key('home-recovery-metrics'))).width,
            greaterThanOrEqualTo(135));
        // Verify real geometry instead of an arbitrary rounded pixel cap.
        // A fractional 259.4px label is valid when it fits beside the arrow.
        final labelFinder = find.byKey(const Key('home-plan-button-label'));
        final planRowFinder = find.ancestor(
          of: labelFinder,
          matching: find.byType(Row),
        ).first;
        final arrowFinder = find.descendant(
          of: planRowFinder,
          matching: find.byIcon(Icons.arrow_forward_rounded),
        );
        final labelRect = tester.getRect(labelFinder);
        final rowRect = tester.getRect(planRowFinder);
        final arrowRect = tester.getRect(arrowFinder);
        expect(labelRect.left, greaterThanOrEqualTo(rowRect.left));
        expect(labelRect.right, lessThanOrEqualTo(arrowRect.left));
        expect(arrowRect.right, lessThanOrEqualTo(rowRect.right));
      }
      // Content should remain scrollable and no fixed-height full-screen
      // Stack should clip the main cards on shorter folded viewports.
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text("View Today's Plan"), findsOneWidget);
    });
  }
}
