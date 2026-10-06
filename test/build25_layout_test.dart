import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/core/theme/app_theme.dart';
import 'package:healthy_me/widgets/salus_widgets.dart';

void main() {
  testWidgets('build 25 metric cards do not overflow at phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 134,
                    child: SalusGlassMetricCard(
                      icon: Icons.bedtime_rounded,
                      label: 'Sleep',
                      value: '7h 24m',
                      status: 'Building baseline',
                      color: AppTheme.blue,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 134,
                    child: SalusGlassMetricCard(
                      icon: Icons.show_chart_rounded,
                      label: 'HRV',
                      value: '68 ms',
                      status: 'Building baseline',
                      color: AppTheme.mint,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 134,
                    child: SalusGlassMetricCard(
                      icon: Icons.favorite_border_rounded,
                      label: 'Resting HR',
                      value: '54 bpm',
                      status: 'Building baseline',
                      color: AppTheme.rose,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('build 25 recovery orb keeps subtitle outside ring', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Center(
            child: SalusRecoveryOrb(
              score: 96,
              subtitle: 'Your signals are in a good range today.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('96'), findsOneWidget);
    expect(find.text('Your signals are in a good range today.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('build 25 pinned week strip fits narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SalusWeekStrip()),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
