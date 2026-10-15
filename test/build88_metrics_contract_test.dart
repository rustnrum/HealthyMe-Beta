import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/screens/premium/salus87_ui.dart';
import 'package:healthy_me/widgets/salus77_design.dart';
import 'package:healthy_me/widgets/salus_premium_ui.dart';

void main() {
  test('Build 88 restores actual metric panels and preserves all live sources', () {
    final home=File('lib/screens/premium/salus_home_87.dart').readAsStringSync();
    final shell=File('lib/screens/home_shell.dart').readAsStringSync();
    for (final value in [
      'S77RestingHeartChart(', 'PremiumLineChart(',
      'health.restingHeartRate30','hrv.rmssdHistory','hrv.indexHistory',
      'health.latestHeartRate','health.bloodOxygenPercent',
      'health.respiratoryRate','health.activeCaloriesToday',
      "sample.metric=='Body battery'",'sample.sourceId.isNotEmpty',
      'sample.capturedAt','bodyBatteryRecords.isEmpty?null',
      "'/metric-resting-heart-rate'", "'/metric-hrv'", "'/sources'",
    ]) {
      expect(home,contains(value),reason:value);
    }
    expect(home,isNot(contains('Data.recovery')));
    expect(home,isNot(contains('DESIGN PREVIEW')));
    expect(shell,contains('SalusHome87()'));
    expect(shell,contains('healthSyncProvider'));
    expect(shell,contains('bottomNavigationBar: _SalusBottomNav('));
    expect(File('pubspec.yaml').readAsStringSync(),contains('version: 0.21.50+88'));
  });

  for (final width in [320.0,360.0,412.0,820.0]) {
    testWidgets('RHR and HRV visual trend panels fit $width logical pixels', (tester) async {
      await tester.binding.setSurfaceSize(Size(width,900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home:Scaffold(backgroundColor:S87.bg,
        body:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(16),
          child:LayoutBuilder(builder:(context,constraints) {
            const rhr=S77RestingHeartChart(values:[63.0,62.0,64.0,63.0],height:112,color:S87.red);
            const hrv=PremiumLineChart(values:[40.0,44.0,42.0,47.0],height:112,color:S87.blue);
            final left=S87Panel(child:Column(children:[const Text('Resting Heart Rate'),rhr]));
            final right=S87Panel(child:Column(children:[const Text('HRV'),hrv]));
            return constraints.maxWidth<360?
              Column(children:[left,const SizedBox(height:10),right]):
              Row(children:[Expanded(child:left),const SizedBox(width:10),Expanded(child:right)]);
          }))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      expect(find.text('Resting Heart Rate'),findsOneWidget);
      expect(find.text('HRV'),findsOneWidget);
    });
  }
}
