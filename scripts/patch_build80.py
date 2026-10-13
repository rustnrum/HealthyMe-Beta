#!/usr/bin/env python3
"""Build 80: full Home mountain, proportional rings, real resting HR axes,
watch-independent Salus Energy emphasis, and Salus-only visible branding.

Apply against validated Build 79 only. No package ID, key or storage mutation.
"""
from pathlib import Path


def replace(file, old, new):
    path = Path(file)
    content = path.read_text()
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f'Build80 patch anchor mismatch {file}: {count} {old[:130]!r}')
    path.write_text(content.replace(old, new, 1))


version = Path('pubspec.yaml').read_text()
if 'version: 0.21.42+80' in version:
    print('Build 80 is already installed; nothing to patch.')
    raise SystemExit(0)
if 'version: 0.21.41+79' not in version:
    raise RuntimeError('Build 80 requires the validated 0.21.41+79 source')
replace('pubspec.yaml', 'version: 0.21.41+79', 'version: 0.21.42+80')

home = 'lib/screens/premium/salus_home_77.dart'
# The native Garmin Body Battery protocol remains available as a source reference
# elsewhere, but it is not a source for the main cross-device Salus Energy estimate.
replace(home, "import '../../services/direct_metric_service.dart';\n", '')
replace(home, '''  double? _calorieGoal;
  DirectMetricSample? _deviceBodyBattery;
  @override void initState(){super.initState();SalusAppearance.load();_loadTarget();_loadBattery();}
  Future<void> _loadBattery() async {
    try {
      final records = await const DirectMetricService().loadSamples();
      final now = DateTime.now();
      final values = records.where((s) => s.metric == 'Body battery' &&
          s.value.isFinite && s.value >= 1 && s.value <= 100 &&
          !s.capturedAt.isAfter(now) &&
          now.difference(s.capturedAt) <= const Duration(hours: 12)).toList()
        ..sort((a,b) => a.capturedAt.compareTo(b.capturedAt));
      if (mounted) setState(() => _deviceBodyBattery = values.isEmpty ? null : values.last);
    } catch (_) { /* Device-only telemetry must not block Home. */ }
  }
''', '''  double? _calorieGoal;
  @override void initState(){super.initState();SalusAppearance.load();_loadTarget();}
''')

# Fixed full-viewport scenic background. The mountain is behind ALL scrolling
# content, rather than clipped into a standalone card. Apply theme-appropriate
# overlays so a dark/light switch doesn't make titles unreadable.
replace(home,
    'ColoredBox(color:S77.bg,child:ListView(padding:const EdgeInsets.fromLTRB(17,11,17,40),children:[',
    'SalusMountainBackdrop(light:light,child:ListView(padding:const EdgeInsets.fromLTRB(17,11,17,40),children:[')

replace(home, '''        const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(20),
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
          ]))),''', '''        const SizedBox(height:12),SizedBox(height:210,child:Padding(
          padding:const EdgeInsets.fromLTRB(12,10,10,14),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          mainAxisAlignment:MainAxisAlignment.center,children:[
            Text(day,style:TextStyle(color:light?S77.sub:const Color(0xffbde5f6),fontSize:12)),
            const SizedBox(height:9),
            Text('Good ${now.hour<12?'morning':now.hour<17?'afternoon':'evening'},',
              style:TextStyle(color:S77.ink,fontSize:24,fontWeight:FontWeight.w800)),
            Text(name,style:TextStyle(color:S77.ink,fontSize:30,fontWeight:FontWeight.w900)),
            const SizedBox(height:10),
            Text('Train. Recover. Live better.',
              style:TextStyle(color:light?S77.sub:const Color(0xffe9f8ff),fontSize:13,fontWeight:FontWeight.w600)),
          ]))),''')

# The Recovery ring is slightly wider, but the numerical glyph is smaller.
replace(home, 'S77Arc(size:135,center:rec.score?.toString()??\'—\',',
             'S77Arc(size:143,center:rec.score?.toString()??\'—\',')
replace(home, """              const SizedBox(height:7),_signal(Icons.battery_charging_full,S77.cyan,
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
                style:TextStyle(color:S77.sub,fontSize:9)),""", """              const SizedBox(height:7),_signal(Icons.bolt_rounded,S77.cyan,'Salus Energy',
                energy.score==null?'—':'${energy.score} est.'),
              const SizedBox(height:7),_signal(Icons.fitness_center,S77.orange,'Activity Load',
                training.reading??(training.score==null?'—':'${training.score} / 100')),
              const SizedBox(height:7),Text('${energy.quality} · ${energy.coverage}% available inputs',
                maxLines:2,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:S77.sub,fontSize:9)),""")
# Keep the same data paths; only replace the plot for resting-HR, not for HRV.
replace(home, 'const SizedBox(height:5),PremiumLineChart(values:values,color:color,height:108,unit:unit),',
             "const SizedBox(height:5),unit=='bpm' ? S77RestingHeartChart(values:values,height:108,color:color) : PremiumLineChart(values:values,color:color,height:108,unit:unit),")

visual = 'lib/widgets/salus77_design.dart'
# Add the scenic backdrop to the existing component system, respecting dark/light.
marker = 'class S77Surface extends StatelessWidget {'
backdrop = '''/// A full-screen scene behind the entire Home page, including its cards.
/// Never blocks scrolling, taps, or existing module selection.
class SalusMountainBackdrop extends StatelessWidget {
  const SalusMountainBackdrop({super.key,required this.child,required this.light});
  final Widget child;
  final bool light;
  @override Widget build(BuildContext context)=>Stack(fit:StackFit.expand,children:[
    ColoredBox(color:S77.bg),
    Positioned.fill(child:Opacity(opacity:light?0.34:0.83,
      child:Image.asset('assets/premium/salus_mountain_79.webp',
        fit:BoxFit.cover,alignment:Alignment.topCenter))),
    Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
      gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
        stops:const [0.0,0.38,1.0],
        colors:light?[const Color(0x9cf4f8fc),const Color(0xcaf4f8fc),const Color(0xf1f4f8fc)]:
          [const Color(0x67030d18),const Color(0xa5050d18),const Color(0xe8040b13)])))),
    child,
  ]);
}

'''
replace(visual, marker, backdrop+marker)
# A larger ring with less dominant typography. Keep the single source of ring
# logic; nutrition & training can continue using this component.
replace(visual, 'child:SizedBox(height:116,', 'child:SizedBox(height:132,')
replace(visual, '    final progress=fraction==null?null:fraction!.clamp(0.0,1.0).toDouble();', '    final progress=fraction==null?null:fraction!.clamp(0.0,1.0).toDouble();\n    final ringDiameter=MediaQuery.sizeOf(context).width<392?74.0:82.0;')
replace(visual, 'S77Arc(size:68,center:progress==null', 'S77Arc(size:ringDiameter,center:progress==null')
replace(visual, 'const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[\n            Text(value',
             'const SizedBox(width:6),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[\n            Text(value')
replace(visual, 'fontWeight:FontWeight.w900,fontSize:19)),\n            if(detail!=null)',
             'fontWeight:FontWeight.w900,fontSize:16)),\n            if(detail!=null)')
replace(visual, 'fontSize:size>140?29:22', 'fontSize:size>140?25:size>100?21:16')
replace(visual, 'const SizedBox(height:2),Text(caption,textAlign:TextAlign.center,style:TextStyle(fontSize:10,color:S77.sub))])', 'const SizedBox(height:2),Text(caption,textAlign:TextAlign.center,style:TextStyle(fontSize:size>100?10:9,color:S77.sub))])')

# Use an honest, easy-to-read BPM scale with ticks, small headroom and spaced
# daily points. No interpolation of unrecorded days or invented readings.
rest_chart = '''
/// Recorded resting heart rate only. Each point is an observed daily value;
/// the y-axis is an expanded bpm range rather than exaggerated auto-zoom.
class S77RestingHeartChart extends StatelessWidget {
  const S77RestingHeartChart({super.key,required this.values,this.height=120,this.color=const Color(0xffff607a)});
  final List<double?> values;
  final double height;
  final Color color;
  @override Widget build(BuildContext context) {
    final usable=values.whereType<double>().where((v)=>v.isFinite&&v>=30&&v<=180).toList();
    if(usable.length<2)return SizedBox(height:height,child:Center(child:Text(
      'More recorded days needed for a trend',style:TextStyle(color:S77.sub,fontSize:11))));
    return SizedBox(height:height,child:CustomPaint(painter:_S77RestingHeartPainter(usable,color,S77.edge,S77.sub)));
  }
}
class _S77RestingHeartPainter extends CustomPainter {
  _S77RestingHeartPainter(this.values,this.accent,this.grid,this.ink);
  final List<double> values;
  final Color accent,grid,ink;
  @override void paint(Canvas c,Size s){
    if(values.length<2||s.width<=52||s.height<=28)return;
    final lowRaw=values.reduce(math.min),highRaw=values.reduce(math.max);
    var low=((lowRaw-5)/5).floorToDouble()*5;
    var high=((highRaw+5)/5).ceilToDouble()*5;
    if(high-low<15){final center=(high+low)/2;low=center-7.5;high=center+7.5;}
    final left=31.0,right=s.width-7.0,top=9.0,bottom=s.height-17.0;
    final width=right-left,height=bottom-top;
    if(width<=0||height<=0)return;
    for(var i=0;i<=3;i++){
      final y=top+height*i/3;
      c.drawLine(Offset(left,y),Offset(right,y),Paint()..color=grid.withValues(alpha:.55)..strokeWidth=.8);
      final bpm=(high-(high-low)*i/3).round().toString();
      final tp=TextPainter(text:TextSpan(text:bpm,style:TextStyle(color:ink,fontSize:9)),textDirection:TextDirection.ltr)..layout();
      tp.paint(c,Offset(1,y-tp.height/2));
    }
    final points=<Offset>[];
    for(var i=0;i<values.length;i++){
      final x=left+width*i/(values.length-1);
      final y=bottom-(values[i]-low)/(high-low)*height;
      points.add(Offset(x,y));
    }
    final path=Path()..moveTo(points.first.dx,points.first.dy);
    for(final point in points.skip(1)){path.lineTo(point.dx,point.dy);}
    c.drawPath(path,Paint()..color=accent..style=PaintingStyle.stroke..strokeWidth=2.4..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round);
    for(final point in points){c.drawCircle(point,3.2,Paint()..color=accent);}
  }
  @override bool shouldRepaint(covariant _S77RestingHeartPainter old)=>
    old.values!=values||old.accent!=accent||old.grid!=grid||old.ink!=ink;
}

'''
replace(visual, 'class S77Progress extends StatelessWidget {', rest_chart+'class S77Progress extends StatelessWidget {')


# Cross-platform estimate terminology also applies inside the Health module.
replace('lib/screens/premium/salus_health_77.dart',
    "Text('Experimental daily estimate · not Garmin Body Battery',",
    "Text('Experimental estimate · sleep & heart trends',")
replace('lib/services/salus_energy_service.dart',
    "explanation: 'Experimental daily energy estimate, not Garmin Body Battery or a medical measure. '",
    "explanation: 'Experimental daily estimate, not a medical measure. '")

# Focus on user-visible app branding. The internal Flutter package name
# `healthy_me` and fixed Android package ID are deliberately UNCHANGED to
# preserve preferences, health connections and the existing signed install.
# AndroidManifest already names the launchable application "Salus".

replace('test/build75_dark_premium_contract_test.dart',
    r"r'^version: 0\.21\.(37|38|39|40|41)\+(75|76|77|78|79)$'",
    r"r'^version: 0\.21\.(37|38|39|40|41|42)\+(75|76|77|78|79|80)$'")
for t in ('build76_light_dark_navigation_contract_test.dart',
          'build77_visual_navigation_contract_test.dart',
          'build78_visual_match_test.dart',
          'build79_energy_contract_test.dart'):
    replace('test/'+t, "version: 0.21.41+79", "version: 0.21.42+80")

# Previous Build 79 contract claimed device Body Battery was the primary UI.
# It must now require source-independent Salus Energy in the Home panel.
replace('test/build79_energy_contract_test.dart',
    "test('The mountain art and both battery labels are part of Home', () {",
    "test('The mountain art and cross-device Salus Energy are part of Home', () {")
replace('test/build79_energy_contract_test.dart',
    "    expect(home, contains('salus_mountain_79.webp'));",
    "    expect(home, contains('SalusMountainBackdrop('));\n    expect(File('lib/widgets/salus77_design.dart').readAsStringSync(), contains('salus_mountain_79.webp'));")
replace('test/build79_energy_contract_test.dart',
    '''    expect(home, contains("s.metric == 'Body battery'"));''',
    '''    expect(home, isNot(contains("s.metric == 'Body battery'")));
    expect(home, contains("'Salus Energy'"));''')

print('Build 80 patch applied')
