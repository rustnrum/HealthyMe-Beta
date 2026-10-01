import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/core/theme/app_theme.dart';
import 'package:healthy_me/models/models.dart';
import 'package:healthy_me/screens/body_screen.dart';
import 'package:healthy_me/state/app_state.dart';

void main() {
  testWidgets('body measurement dialog opens and closes without framework errors',
      (tester) async {
    const initial = HealthyMeState(
      profile: UserProfile(
        completed: true,
        heightIn: 64,
        manualCurrentWeightLb: 200,
      ),
      measurements: BodyMeasurements(
        waist: 40,
        chest: 44,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialAppStateProvider.overrideWithValue(initial)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: BodyScreen()),
        ),
      ),
    );

    await tester.tap(find.text('Measurements').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Body measurements'), findsOneWidget);
    expect(find.text('Waist (in)'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
