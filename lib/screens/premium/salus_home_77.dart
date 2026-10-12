// Build 77 Home: visual-first wellness dashboard, only measured/provider data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/recovery_service.dart';
import '../../services/home_insight_service.dart';
import '../../state/app_state.dart';
import '../../state/diet_log_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/module_menu_button.dart';
import '../../widgets/salus_premium_ui.dart';
import '../../widgets/salus77_design.dart';
import '../../widgets/salus_premium_visuals.dart';

class SalusHome77 extends ConsumerStatefulWidget{
  const SalusHome77({super.key});
  @override ConsumerState<SalusHome77> createState()=>_SalusHome77State();
}
class _SalusHome77State extends ConsumerState<SalusHome77>{
  @override void initState(){super.initState();SalusAppearance.load();}
  bool _isToday(DateTime d,DateTime now)=>d.year==now.year&&d.month==now.month&&d.day==now.day;
  @override Widget build(BuildContext context){
    final app=ref.watch(appStateProvider);
    final health=app.health,log=ref.watch(dietLogStateProvider),work=ref.watch(workoutStateProvider);
    final recovery=RecoveryService.build(app,completedWorkouts:work.history);
    final insight=HomeInsightService.build(app);
    final now=DateTime.now();
    final name=app.profile.firstName.trim().isEmpty?'there':app.profile.firstName.trim().split(' ').first;
    final stepsKnown=health.resolvedSources.containsKey('Steps');
    final sleepKnown=health.sleepMinutes>0;
    final kcal=log.knownTotal(now,(x)=>x.calories);
    final completed=work.history.where((x)=>_isToday(x.completedAt,now)).length;
    final nowDate='${now.month}/${now.day}/${now.year}';
    return ValueListenableBuilder<bool>(valueListenable:SalusAppearance.light,builder:(context,light,_)=>ColoredBox(color:S77.bg,
      child:ListView(padding:const EdgeInsets.fromLTRB(17,14,17,42),children:[
        Row(children:[Expanded(child:Text('S A L U S',style:TextStyle(color:S77.ink,fontSize:21,fontWeight:FontWeight.w900,letterSpacing:3))),
          HealthyMeModuleMenuButton(current:HealthyMeModule.fitness,onSelected:(m){switch(m){
            case HealthyMeModule.fitness:break;
            case HealthyMeModule.workout:Navigator.of(context).pushNamed('/workout');break;
            case HealthyMeModule.diet:Navigator.of(context).pushNamed('/diet');break;
            case HealthyMeModule.health:Navigator.of(context).pushNamed('/health');break;
          }}),const PremiumThemeButton()]),
        const SizedBox(height:7),Text('Good ${now.hour<12?'morning':now.hour<17?'afternoon':'evening'},',style:TextStyle(color:S77.sub,fontSize:14)),
        Text(name,style:TextStyle(color:S77.ink,fontSize:35,fontWeight:FontWeight.w900)),
        const SizedBox(height:5),Text(nowDate,style:TextStyle(color:S77.dim,fontSize:11)),
        const SizedBox(height:16),SalusWeekStrip(day:now),
        const SizedBox(height:17),S77Hero(asset:'assets/premium/training_hero.jpg',title:'Train. Recover.\nLive better.',
          caption:'Your health, food and movement in one place.',onTap:()=>Navigator.pushNamed(context,'/recovery'),height:174),
        const SizedBox(height:18),const S77Section('Today\'s Overview'),const SizedBox(height:8),
        Row(children:[Expanded(child:S77Metric(label:'Activity',value:stepsKnown?'${health.stepsToday}':'—',
          caption:stepsKnown?'steps today':'No steps source',icon:Icons.directions_walk,color:S77.green,
          progress:stepsKnown&&app.profile.stepGoal>0?health.stepsToday/app.profile.stepGoal:null,
          onTap:()=>Navigator.pushNamed(context,'/activity-detail'))),const SizedBox(width:9),
          Expanded(child:S77Metric(label:'Nutrition',value:kcal==null?'—':'${kcal.round()}',
            caption:kcal==null?'No food logged':'kcal eaten',icon:Icons.restaurant_menu,color:S77.orange,
            onTap:()=>Navigator.pushNamed(context,'/diet')))]),
        const SizedBox(height:9),Row(children:[Expanded(child:S77Metric(label:'Workout',value:'$completed',
          caption:'completed today',icon:Icons.fitness_center,color:S77.blue,
          onTap:()=>Navigator.pushNamed(context,'/workout'))),const SizedBox(width:9),
          Expanded(child:S77Metric(label:'Sleep',value:sleepKnown?'${health.sleepMinutes~/60}h ${health.sleepMinutes%60}m':'—',
            caption:sleepKnown?'last sleep record':'No sleep data',icon:Icons.bedtime,color:S77.purple,
            progress:sleepKnown&&app.profile.plannedSleepMinutes>0?health.sleepMinutes/app.profile.plannedSleepMinutes:null,
            onTap:()=>Navigator.pushNamed(context,'/sleep-detail')))]),
        const SizedBox(height:15),S77Section('Recovery',action:'Details',onTap:()=>Navigator.pushNamed(context,'/recovery')),
        const SizedBox(height:6),S77Surface(accent:S77.green,onTap:()=>Navigator.pushNamed(context,'/recovery'),child:Row(children:[
          S77Arc(size:119,center:recovery.score?.toString()??'—',caption:recovery.score==null?'Unavailable':recovery.label,
            segments:recovery.score==null?[]:[(value:recovery.score!.toDouble(),color:S77.green),(value:(100-recovery.score!).toDouble(),color:S77.edge)]),
          const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('How ready are you?',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w900,fontSize:15)),
            const SizedBox(height:7),Text(recovery.summary,maxLines:4,overflow:TextOverflow.ellipsis,style:TextStyle(color:S77.sub,fontSize:11,height:1.4)),
            const SizedBox(height:7),Text('${recovery.confidence}% signal coverage',style:TextStyle(color:S77.green,fontWeight:FontWeight.w700,fontSize:10)),
          ]))
        ])),
        const SizedBox(height:16),S77Section('Your Health Insights',action:'Open AI',onTap:()=>Navigator.pushNamed(context,'/coach')),
        const SizedBox(height:6),S77Surface(accent:S77.purple,onTap:()=>Navigator.pushNamed(context,'/health-intelligence'),child:Row(children:[
          Icon(Icons.auto_awesome,color:S77.purple,size:26),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('What your data says',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:14)),
            const SizedBox(height:5),Text(insight.message,maxLines:5,overflow:TextOverflow.ellipsis,style:TextStyle(color:S77.sub,fontSize:11,height:1.45))
          ])),Icon(Icons.chevron_right,color:S77.cyan)
        ])),
        const SizedBox(height:16),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>Navigator.pushNamed(context,'/health'),icon:const Icon(Icons.favorite_outline),label:const Text('Health'))),
          const SizedBox(width:8),Expanded(child:FilledButton.icon(onPressed:()=>Navigator.pushNamed(context,'/diet'),icon:const Icon(Icons.restaurant),label:const Text('Meals')))]),
      ])));
  }
}
