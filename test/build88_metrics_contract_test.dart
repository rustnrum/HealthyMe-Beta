import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_me/screens/premium/salus87_ui.dart';
import 'package:healthy_me/widgets/salus77_design.dart';
import 'package:healthy_me/widgets/salus_premium_ui.dart';

void main() {
  test('Home retains recorded trends and vitals without proprietary HRV', () {
    final home=File('lib/screens/premium/salus_home_87.dart').readAsStringSync();
    for(final token in [
      'S77RestingHeartChart(', 'PremiumLineChart(',
      'h.restingHeartRate30', 'hrv.rmssdHistory', 'h.latestHeartRate',
      'h.bloodOxygenPercent', 'h.respiratoryRate', 'h.activeCaloriesToday',
      "'/metric-resting-heart-rate'", "'/metric-hrv'",
    ]) {
      expect(home, contains(token), reason:token);
    }
    expect(home, isNot(contains('bodyBatteryRecords')));
    expect(home, isNot(contains('indexHistory')));
    expect(home, isNot(contains('Data.recovery')));
  });
  for(final width in [320.0,360.0,412.0,820.0]) {
    testWidgets('Recorded RHR/HRV charts fit width $width',(tester) async {
      await tester.binding.setSurfaceSize(Size(width,900));
      addTearDown(()=>tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home:Scaffold(backgroundColor:S87.bg,
        body:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(16),
          child:LayoutBuilder(builder:(context,constraints) {
            const rhr=S77RestingHeartChart(values:[63,62,64,63],height:112,color:S87.red);
            const hrv=PremiumLineChart(values:[40,44,42,47],height:112,color:S87.blue);
            final left=S87Panel(child:Column(children:[const Text('Resting Heart Rate'),rhr]));
            final right=S87Panel(child:Column(children:[const Text('HRV'),hrv]));
            return constraints.maxWidth<360?
              Column(children:[left,const SizedBox(height:10),right]):
              Row(children:[Expanded(child:left),const SizedBox(width:10),Expanded(child:right)]);
          }))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
    });
  }
}
