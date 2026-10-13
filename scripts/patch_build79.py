#!/usr/bin/env python3
"""Build 79: approved mountain hero, source-specific energy, Recovery coverage.

Runs only on validated Build 78; unchanged existing data and navigation.
"""
from pathlib import Path


def replace(path, before, after):
    p = Path(path)
    original = p.read_text()
    count = original.count(before)
    if count != 1:
        raise RuntimeError(f'Build79 anchor mismatch {path}: {count}: {before[:95]!r}')
    p.write_text(original.replace(before, after, 1))


pub = Path('pubspec.yaml')
if 'version: 0.21.41+79' in pub.read_text():
    print('Build 79 already applied')
    raise SystemExit(0)
if 'version: 0.21.40+78' not in pub.read_text():
    raise RuntimeError('Build 79 requires validated 0.21.40+78 source')
replace('pubspec.yaml', 'version: 0.21.40+78', 'version: 0.21.41+79')

# An individual sleeping reading must still not invent a full Recovery score.
# Two days of historical resting HR do permit a low-confidence provisional
# comparison when sleep is also recorded; the earlier 4-day baseline remains
# required for an ordinary/full-coverage RHR contribution.
recovery = 'lib/services/recovery_service.dart'
replace(recovery,
    'if (current == null || h.restingHeartRate30.length < 4) {',
    'if (current == null || h.restingHeartRate30.length < 3) {')
replace(recovery,
    "score: objectiveScore,\n          confidence: objectiveConfidence,\n          band: RecoveryBand.noData,\n          label: 'Preliminary',",
    "score: (50 + (objectiveScore - 50) * (objectiveConfidence / 100)).round().clamp(0, 100).toInt(),\n"
    "          confidence: objectiveConfidence,\n          band: RecoveryBand.noData,\n          label: 'Preliminary',")
replace(recovery,
    "Measured resting heart rate available · ${h.restingHeartRate30.length} of 4 baseline readings. No comparison score yet.",
    "Measured resting heart rate available · ${h.restingHeartRate30.length} of 3 baseline readings. No comparison score yet.")
replace(recovery,
    "detail:\n          '${current.round()} bpm • ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} vs baseline',\n      weight: _rhrWeight,",
    "detail:\n          '${current.round()} bpm • ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} vs baseline'\n          '${h.restingHeartRate30.length == 3 ? ' • early baseline' : ''}',\n      weight: h.restingHeartRate30.length == 3 ? 10 : _rhrWeight,")

home = 'lib/screens/premium/salus_home_77.dart'
replace(home,
    "import '../../services/recovery_service.dart';",
    "import '../../services/recovery_service.dart';\n"
    "import '../../services/salus_energy_service.dart';\n"
    "import '../../services/direct_metric_service.dart';")
replace(home,
    '  double? _calorieGoal;\n',
    '  double? _calorieGoal;\n  DirectMetricSample? _deviceBodyBattery;\n')
replace(home,
    '  @override void initState(){super.initState();SalusAppearance.load();_loadTarget();}',
    '  @override void initState(){super.initState();SalusAppearance.load();_loadTarget();_loadBattery();}\n'
    '  Future<void> _loadBattery() async {\n'
    '    try {\n'
    '      final records = await const DirectMetricService().loadSamples();\n'
    '      final now = DateTime.now();\n'
    "      final values = records.where((s) => s.metric == 'Body battery' &&\n"
    '          s.value.isFinite && s.value >= 1 && s.value <= 100 &&\n'
    '          !s.capturedAt.isAfter(now) &&\n'
    '          now.difference(s.capturedAt) <= const Duration(hours: 12)).toList()\n'
    '        ..sort((a,b) => a.capturedAt.compareTo(b.capturedAt));\n'
    '      if (mounted) setState(() => _deviceBodyBattery = values.isEmpty ? null : values.last);\n'
    '    } catch (_) { /* Device-only telemetry must not block Home. */ }\n'
    '  }')
replace(home,
    '    final rec=RecoveryService.build(app,completedWorkouts:work.history);',
    '    final rec=RecoveryService.build(app,completedWorkouts:work.history);\n'
    '    final energy=SalusEnergyService.estimate(h,app.profile);\n'
    "    final training=rec.contributors.where((c)=>c.name=='Training load').first;")
replace(home,
    "        const SizedBox(height:5),Text('Good ${now.hour<12?'morning':now.hour<17?'afternoon':'evening'}, $name',\n"
    "          style:TextStyle(color:S77.ink,fontWeight:FontWeight.w900,fontSize:25)),\n"
    "        const SizedBox(height:2),Text(day,style:TextStyle(color:S77.sub,fontSize:12)),\n"
    "        const SizedBox(height:12),S77Hero(asset:'assets/premium/training_hero.jpg',height:126,\n"
    "          title:'Train. Recover.\\nLive better.',caption:'Your health, food and movement in one place.',\n"
    "          onTap:()=>Navigator.pushNamed(context,'/recovery')),",
    """        const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(20),
          child:SizedBox(height:208,child:Stack(fit:StackFit.expand,children:[
            Image.asset('assets/premium/salus_mountain_79.webp',fit:BoxFit.cover,
              alignment:Alignment.centerRight),
            DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(
              begin:Alignment.centerLeft,end:Alignment.centerRight,
              colors:[const Color(0xea020f1d),const Color(0x88031323),const Color(0x14031323)]))),
            Padding(padding:const EdgeInsets.fromLTRB(20,18,12,16),child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              mainAxisAlignment:MainAxisAlignment.center,children:[
                Text(day,style:const TextStyle(color:Color(0xffbde5f6),fontSize:12)),
                const SizedBox(height:9),
                Text('Good ${now.hour<12?'morning':now.hour<17?'afternoon':'evening'},',
                  style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w800)),
                Text(name,style:const TextStyle(color:Colors.white,fontSize:29,fontWeight:FontWeight.w900)),
                const SizedBox(height:10),
                const Text('Train. Recover. Live better.',
                  style:TextStyle(color:Color(0xffe9f8ff),fontSize:13,fontWeight:FontWeight.w600)),
              ])),
          ]))),""")
replace(home,
    "              const SizedBox(height:7),_signal(Icons.favorite,S77.red,'RHR',\n"
    "                h.restingHeartRate==null?'—':'${h.restingHeartRate!.round()} bpm'),\n"
    "              const SizedBox(height:8),Text('${rec.confidence}% signal coverage',",
    """              const SizedBox(height:7),_signal(Icons.favorite,S77.red,'RHR',
                h.restingHeartRate==null?'—':'${h.restingHeartRate!.round()} bpm'),
              const SizedBox(height:7),_signal(Icons.battery_charging_full,S77.cyan,
                _deviceBodyBattery==null?'Salus Energy':'Body Battery',
                _deviceBodyBattery==null
                  ? (energy.score==null?'—':'${energy.score} est.')
                  : '${_deviceBodyBattery!.value.round()}'),
              const SizedBox(height:7),_signal(Icons.fitness_center,S77.orange,'Activity Load',
                training.reading??(training.score==null?'—':'${training.score} / 100')),
              const SizedBox(height:7),Text(_deviceBodyBattery!=null
                ? 'Device reading · ${_deviceBodyBattery!.deviceName}'
                : 'Salus Energy · ${energy.quality} (${energy.coverage}% inputs)',
                maxLines:2,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:S77.sub,fontSize:9)),
              const SizedBox(height:8),Text('${rec.confidence}% signal coverage',""")

# Keep the existing Health contributing-factors and source-detail pages. Add
# a visible daily Energy estimate to Health without using it as Recovery input.
health = 'lib/screens/premium/salus_health_77.dart'
replace(health,
    "import '../../services/recovery_service.dart';",
    "import '../../services/recovery_service.dart';\nimport '../../services/salus_energy_service.dart';")
replace(health,
    '    final health=app.health,rec=RecoveryService.build(app,completedWorkouts:workouts.history);',
    '    final health=app.health,rec=RecoveryService.build(app,completedWorkouts:workouts.history);\n'
    '    final energy=SalusEnergyService.estimate(health,app.profile);')
replace(health,
    "        const SizedBox(height:14),S77Section('More Health Data'",
    """        const SizedBox(height:14),S77Section('Energy & workload'),
        const SizedBox(height:6),S77Surface(accent:S77.cyan,child:Row(children:[
          Icon(Icons.battery_charging_full,color:S77.cyan,size:27),
          const SizedBox(width:10),Expanded(child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Salus Energy',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800)),
              Text('Experimental daily estimate · not Garmin Body Battery',
                style:TextStyle(color:S77.sub,fontSize:10)),
              Text(energy.quality,style:TextStyle(color:S77.dim,fontSize:10)),
          ])),Text(energy.score==null?'—':'${energy.score} / 100',
            style:TextStyle(color:S77.cyan,fontSize:18,fontWeight:FontWeight.w900)),
        ])),
        const SizedBox(height:14),S77Section('More Health Data'""")

# Saturated accents rather than washed-out pastel tones.
visuals = 'lib/widgets/salus_premium_visuals.dart'
replace(visuals, 'static const cyan = Color(0xff00b4d0);', 'static const cyan = Color(0xff00d9ff);')
replace(visuals, 'static const green = Color(0xff12c58e);', 'static const green = Color(0xff00edac);')
replace(visuals, 'static const purple = Color(0xffac83e8);', 'static const purple = Color(0xffaf60ff);')

# Tests that check release progression must accept the newer version.
replace('test/build75_dark_premium_contract_test.dart',
    r"r'^version: 0\.21\.(37|38|39|40)\+(75|76|77|78)$'",
    r"r'^version: 0\.21\.(37|38|39|40|41)\+(75|76|77|78|79)$'")
for testfile in ['test/build76_light_dark_navigation_contract_test.dart',
                 'test/build77_visual_navigation_contract_test.dart',
                 'test/build78_visual_match_test.dart']:
    replace(testfile, "contains('version: 0.21.40+78')",
           "contains('version: 0.21.41+79')")

print('Build 79 patch applied')
