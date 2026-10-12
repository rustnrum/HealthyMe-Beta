import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/recovery_service.dart';
import '../../services/home_insight_service.dart';
import '../../state/app_state.dart';
import '../../state/diet_log_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/salus_premium_ui.dart';
import '../../widgets/salus_premium_visuals.dart';

/// Four visible dashboards share one design language. Actual data is always
/// retrieved from the existing providers; there are no seeded display scores.
class SalusPremiumHome extends ConsumerStatefulWidget {
  const SalusPremiumHome({super.key});
  @override ConsumerState<SalusPremiumHome> createState()=>_SalusPremiumHomeState();
}
class _SalusPremiumHomeState extends ConsumerState<SalusPremiumHome> {
  @override void initState(){super.initState();SalusAppearance.load();}
  @override Widget build(BuildContext context){
    final app=ref.watch(appStateProvider);
    final health=app.health;
    final log=ref.watch(dietLogStateProvider);
    final workouts=ref.watch(workoutStateProvider);
    final recovery=RecoveryService.build(app,completedWorkouts:workouts.history);
    final insight=HomeInsightService.build(app);
    final now=DateTime.now();
    final kcal=log.knownTotal(now,(e)=>e.calories);
    final first=app.profile.firstName.trim().isEmpty?'there':app.profile.firstName.trim().split(' ').first;
    final completed=workouts.history.where((w)=>_sameDay(w.completedAt,now)).length;
    final stepAvailable=health.resolvedSources.containsKey('Steps');
    final stepGoal=app.profile.stepGoal; // Existing goal, not a guessed number.
    final sleepKnown=health.sleepMinutes>0;
    final sleepLabel=sleepKnown?'${health.sleepMinutes~/60}h ${health.sleepMinutes%60}m':'—';
    final hrvTrend=health.hrv30.isEmpty?null:health.hrv30.map((v)=>v.toDouble()).toList();
    return ColoredBox(color:SalusV.background,child:ListView(
      padding:const EdgeInsets.fromLTRB(17,17,17,46),children:[
        Row(children:[const Text('S A L U S',style:TextStyle(color:SalusV.ink,
          fontSize:20,fontWeight:FontWeight.w900,letterSpacing:2.1)),
          const Spacer(),IconButton(tooltip:'AI health insights',onPressed:()=>Navigator.pushNamed(context,'/health-intelligence'),
            icon:const Icon(Icons.auto_awesome,color:SalusV.cyan))]),
        const SizedBox(height:13),
        SalusHeading(first,caption:_greeting(now.hour).toUpperCase()),
        const SizedBox(height:21),SalusWeekStrip(day:now),
        const SizedBox(height:18),
        SalusPhotoHero(asset:'assets/premium/salus_night_mountains.jpg',
          title:'Small steps create\nbig changes.',height:125,
          onTap:()=>Navigator.pushNamed(context,'/recovery')),
        const SizedBox(height:21),const SalusSection("Today's overview"),
        const SizedBox(height:9),
        Row(children:[
          Expanded(child:SalusMetricTile(label:'Activity',icon:Icons.directions_walk_rounded,
            value:stepAvailable?'${health.stepsToday}':'—',color:SalusV.green,
            detail:stepAvailable?'steps today':'No steps source',
            progress:stepAvailable&&stepGoal>0?health.stepsToday/stepGoal:null,
            onTap:()=>Navigator.pushNamed(context,'/activity-detail'))),
          const SizedBox(width:10),
          Expanded(child:SalusMetricTile(label:'Nutrition',icon:Icons.restaurant_rounded,
            value:kcal==null?'—':'${kcal.round()}',color:SalusV.orange,
            detail:kcal==null?'No food logged':'kcal eaten',
            onTap:()=>Navigator.pushNamed(context,'/diet'))),
        ]),const SizedBox(height:10),
        Row(children:[
          Expanded(child:SalusMetricTile(label:'Training',icon:Icons.fitness_center_rounded,
            value:'$completed',color:SalusV.blue,detail:'completed today',
            onTap:()=>Navigator.pushNamed(context,'/workout'))),
          const SizedBox(width:10),
          Expanded(child:SalusMetricTile(label:'Sleep',icon:Icons.bedtime_rounded,
            value:sleepLabel,color:SalusV.purple,
            detail:sleepKnown?'last recorded sleep':'No sleep data',
            progress:sleepKnown&&app.profile.plannedSleepMinutes>0?health.sleepMinutes/app.profile.plannedSleepMinutes:null,
            onTap:()=>Navigator.pushNamed(context,'/sleep-detail'))),
        ]),
        const SizedBox(height:13),
        SalusGlass(glow:SalusV.green,onTap:()=>Navigator.pushNamed(context,'/recovery'),
          child:Row(children:[
            SalusGauge(value:recovery.score?.toDouble(),total:100,
              center:recovery.score?.toString()??'—',caption:recovery.score==null?'No score':recovery.label,
              color:SalusV.green,size:104),
            const SizedBox(width:15),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Recovery',style:TextStyle(color:SalusV.ink,fontSize:17,fontWeight:FontWeight.w800)),
              const SizedBox(height:4),
              Text(recovery.summary,maxLines:3,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:SalusV.secondary,fontSize:12,height:1.4)),
              const SizedBox(height:6),
              Text('${recovery.confidence}% data coverage',
                style:const TextStyle(color:SalusV.green,fontSize:11,fontWeight:FontWeight.w700)),
              if(hrvTrend!=null&&hrvTrend.length>1)...[
                const SizedBox(height:6),SalusSparkline(values:hrvTrend,color:SalusV.blue,height:23)],
            ])),
            const Icon(Icons.chevron_right,color:SalusV.cyan),
          ])),
        const SizedBox(height:14),
        SalusGlass(glow:SalusV.purple,onTap:()=>Navigator.pushNamed(context,'/health-intelligence'),
          child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Icon(Icons.auto_awesome,color:SalusV.purple,size:25),const SizedBox(width:10),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('What your data says',style:TextStyle(color:SalusV.ink,
                fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:6),
              Text(insight.message,maxLines:4,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:SalusV.secondary,fontSize:12,height:1.45)),
              const SizedBox(height:5),Text(insight.source,
                style:const TextStyle(color:SalusV.muted,fontSize:10)),
            ])),const Icon(Icons.chevron_right,color:SalusV.cyan),
          ])),
        const SizedBox(height:20),const SalusSection('Health intelligence'),
        const SizedBox(height:8),SalusGlass(onTap:()=>Navigator.pushNamed(context,'/health-intelligence'),
          child:const Row(children:[Icon(Icons.thermostat_rounded,color:SalusV.purple),
            SizedBox(width:9),Expanded(child:Text('Vitals, skin temperature & trends',
              style:TextStyle(color:SalusV.ink,fontWeight:FontWeight.w700))),
            Icon(Icons.chevron_right,color:SalusV.cyan)])),
        const SizedBox(height:14),
        const Text('Measurements are shown only when available from connected sources or your entries.',
          style:TextStyle(color:SalusV.muted,fontSize:11,height:1.5)),
      ]));
  }
  bool _sameDay(DateTime a,DateTime b)=>a.year==b.year&&a.month==b.month&&a.day==b.day;
  String _greeting(int hour)=>hour<12?'Good morning,':hour<17?'Good afternoon,':'Good evening,';
}
