// Salus Home: approved recovery-led layout, source-verified readings only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/recovery_service.dart';
import '../../services/salus_energy_service.dart';
import '../../services/direct_metric_service.dart';
import '../../services/home_insight_service.dart';
import '../../state/app_state.dart';
import '../../state/diet_log_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/module_menu_button.dart';
import '../../widgets/salus_premium_ui.dart';
import '../../widgets/salus77_design.dart';

class SalusHome77 extends ConsumerStatefulWidget {
  const SalusHome77({super.key});
  @override ConsumerState<SalusHome77> createState()=>_SalusHome77State();
}
class _SalusHome77State extends ConsumerState<SalusHome77> {
  double? _calorieGoal;
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
  Future<void> _loadTarget() async {
    try { final p=await SharedPreferences.getInstance();
      final value=p.getDouble('salus_nutrition_target_Calories');
      if(mounted) setState(()=>_calorieGoal=(value!=null&&value>0)?value:null);
    } catch (_) { /* A missing target is not a zero-calorie goal. */ }
  }
  bool _sameDay(DateTime a,DateTime b)=>a.year==b.year&&a.month==b.month&&a.day==b.day;
  bool _week(DateTime x,DateTime now){
    final start=DateTime(now.year,now.month,now.day).subtract(Duration(days:now.weekday-1));
    return !x.isBefore(start)&&x.isBefore(start.add(const Duration(days:7)));
  }
  @override Widget build(BuildContext context){
    final app=ref.watch(appStateProvider),h=app.health;
    final log=ref.watch(dietLogStateProvider),work=ref.watch(workoutStateProvider);
    final rec=RecoveryService.build(app,completedWorkouts:work.history);
    final energy=SalusEnergyService.estimate(h,app.profile);
    final training=rec.contributors.where((c)=>c.name=='Training load').first;
    final insight=HomeInsightService.build(app);
    final now=DateTime.now();
    final name=app.profile.firstName.trim().isEmpty?'there':app.profile.firstName.trim().split(' ').first;
    final knownSteps=h.resolvedSources.containsKey('Steps');
    final calories=log.knownTotal(now,(e)=>e.calories);
    final todayWorkouts=work.history.where((x)=>_sameDay(x.completedAt,now)).length;
    final weekWorkouts=work.history.where((x)=>_week(x.completedAt,now)).length;
    final sleepKnown=h.sleepMinutes>0;
    final sleepTarget=app.profile.plannedSleepMinutes;
    final workTarget=app.profile.workoutGoalPerWeek;
    final day='${now.month}/${now.day}/${now.year}';
    return ValueListenableBuilder<bool>(valueListenable:SalusAppearance.light,builder:(context,light,_)=>
      ColoredBox(color:S77.bg,child:ListView(padding:const EdgeInsets.fromLTRB(17,11,17,40),children:[
        Row(children:[Expanded(child:Text('S A L U S',style:TextStyle(color:S77.ink,fontSize:19,
          fontWeight:FontWeight.w900,letterSpacing:3))),
          HealthyMeModuleMenuButton(iconColor:S77.ink,showLabel:true,lightSurface:light,current:HealthyMeModule.fitness,
            onSelected:(m){switch(m){
              case HealthyMeModule.fitness:break;
              case HealthyMeModule.workout:Navigator.of(context).pushNamed('/workout');break;
              case HealthyMeModule.diet:Navigator.of(context).pushNamed('/diet');break;
              case HealthyMeModule.health:Navigator.of(context).pushNamed('/health');break;
            }}),const PremiumThemeButton()]),
        const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(20),
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
          ]))),
        const SizedBox(height:14),S77Section('Recovery Score',action:'Details',onTap:()=>Navigator.pushNamed(context,'/recovery')),
        const SizedBox(height:7),S77Surface(accent:S77.green,onTap:()=>Navigator.pushNamed(context,'/recovery'),
          child:Row(children:[
            S77Arc(size:135,center:rec.score?.toString()??'—',
              caption:rec.score==null?'Unavailable':rec.label,
              segments:rec.score==null?const []:[
                (value:rec.score!.toDouble(),color:S77.green),
                (value:(100-rec.score!).toDouble(),color:S77.blue)]),
            const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              _signal(Icons.bedtime,S77.purple,'Sleep',
                sleepKnown?'${h.sleepMinutes~/60}h ${h.sleepMinutes%60}m':'—'),
              const SizedBox(height:7),_signal(Icons.monitor_heart,S77.blue,'HRV',
                h.hrvMs==null?'—':'${h.hrvMs!.round()} ms'),
              const SizedBox(height:7),_signal(Icons.favorite,S77.red,'RHR',
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
              const SizedBox(height:8),Text('${rec.confidence}% signal coverage',
                style:TextStyle(color:S77.green,fontSize:10,fontWeight:FontWeight.w800)),
            ])),
          ])),
        const SizedBox(height:10),S77Surface(accent:S77.purple,onTap:()=>Navigator.pushNamed(context,'/health-intelligence'),
          child:Row(children:[Icon(Icons.auto_awesome,color:S77.purple,size:24),const SizedBox(width:10),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('AI Health Insight',style:TextStyle(color:S77.ink,fontSize:13,fontWeight:FontWeight.w900)),
              const SizedBox(height:4),Text(insight.message,maxLines:3,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:S77.sub,fontSize:11,height:1.4))])),
            Icon(Icons.chevron_right,color:S77.cyan,size:19)])),
        const SizedBox(height:15),const S77Section("Today's Overview"),const SizedBox(height:7),
        Row(children:[Expanded(child:S77RingTile(label:'Steps',
          value:knownSteps?'${h.stepsToday}':'—',detail:'today',icon:Icons.directions_walk_rounded,color:S77.green,
          fraction:knownSteps&&app.profile.stepGoal>0?h.stepsToday/app.profile.stepGoal:null,
          onTap:()=>Navigator.pushNamed(context,'/activity-detail'))),const SizedBox(width:9),
          Expanded(child:S77RingTile(label:'Nutrition',value:calories==null?'—':'${calories.round()}',
            detail:'kcal eaten',icon:Icons.restaurant_menu,color:S77.orange,
            fraction:calories!=null&&_calorieGoal!=null?calories/_calorieGoal!:null,
            onTap:()=>Navigator.pushNamed(context,'/diet')))]),
        const SizedBox(height:9),Row(children:[Expanded(child:S77RingTile(label:'Workout',
          value:'$todayWorkouts',detail:'completed today',icon:Icons.fitness_center,color:S77.blue,
          fraction:workTarget>0?weekWorkouts/workTarget:null,
          onTap:()=>Navigator.pushNamed(context,'/workout'))),const SizedBox(width:9),
          Expanded(child:S77RingTile(label:'Sleep',
            value:sleepKnown?'${h.sleepMinutes~/60}h ${h.sleepMinutes%60}m':'—',
            detail:'last recorded night',icon:Icons.bedtime,color:S77.purple,
            fraction:sleepKnown&&sleepTarget>0?h.sleepMinutes/sleepTarget:null,
            onTap:()=>Navigator.pushNamed(context,'/sleep-detail')))]),
        const SizedBox(height:16),S77Section('Vital Trends',action:'All trends',onTap:()=>Navigator.pushNamed(context,'/trends')),
        const SizedBox(height:7),Row(children:[
          Expanded(child:_trend(context,'Resting HR',h.restingHeartRate30.map((v)=>v.toDouble()).toList(),S77.red,'bpm','/metric-resting-heart-rate')),
          const SizedBox(width:9),Expanded(child:_trend(context,'HRV',h.hrv30.map((v)=>v.toDouble()).toList(),S77.blue,'ms','/metric-hrv')),
        ]),
        const SizedBox(height:11),S77Surface(onTap:()=>Navigator.pushNamed(context,'/health'),child:Row(children:[
          Icon(Icons.favorite_outline,color:S77.purple),const SizedBox(width:9),
          Expanded(child:Text(rec.summary,maxLines:3,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:S77.sub,fontSize:12))),Icon(Icons.chevron_right,color:S77.cyan)])),
      ])));
  }
  Widget _signal(IconData icon,Color color,String label,String reading)=>Row(children:[
    Icon(icon,color:color,size:15),const SizedBox(width:6),Expanded(child:Text(label,
      style:TextStyle(color:S77.sub,fontSize:11))),
    Text(reading,style:TextStyle(color:S77.ink,fontSize:11,fontWeight:FontWeight.w900)),
  ]);
  Widget _trend(BuildContext context,String label,List<double?> values,Color color,String unit,String route)=>
    S77Surface(onTap:()=>Navigator.pushNamed(context,route),padding:const EdgeInsets.all(10),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(label,style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:12)),
        const SizedBox(height:5),PremiumLineChart(values:values,color:color,height:108,unit:unit),
      ]));
}
