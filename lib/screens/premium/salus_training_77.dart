// Build 77 Training: real completed sessions, calendar and workout categories.
// Planned weights/sets are not reported as measured lifting volume or muscle activation.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/app_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/module_menu_button.dart';
import '../../widgets/salus_premium_ui.dart';
import '../../widgets/salus77_design.dart';
import '../../widgets/salus_premium_visuals.dart';

class SalusTraining77 extends ConsumerStatefulWidget {
  const SalusTraining77({super.key,required this.onToday,required this.onSchedule,required this.onHistory});
  final VoidCallback onToday,onSchedule,onHistory;
  @override ConsumerState<SalusTraining77> createState()=>_SalusTraining77State();
}
class _SalusTraining77State extends ConsumerState<SalusTraining77>{
  @override void initState(){super.initState();SalusAppearance.load();}
  static const groups=['Chest','Back','Legs','Shoulders','Arms','Core'];
  Color _color(String group)=>switch(group){'Chest'=>S77.red,'Back'=>S77.blue,'Legs'=>S77.orange,
    'Shoulders'=>S77.purple,'Arms'=>S77.green,_=>S77.cyan};
  String? _group(String value){final n=value.toLowerCase();
    if(RegExp('bench|push.up|chest|pec|fly').hasMatch(n))return 'Chest';
    if(RegExp('pull.up|pull.down|row|deadlift|lat |back').hasMatch(n))return 'Back';
    if(RegExp('squat|lunge|leg |calf|quad|hamstring|glute').hasMatch(n))return 'Legs';
    if(RegExp('shoulder|lateral raise|overhead|military press|delt').hasMatch(n))return 'Shoulders';
    if(RegExp('curl|tricep|bicep|hammer|pushdown|extension').hasMatch(n))return 'Arms';
    if(RegExp('plank|crunch|sit.up|core|abdom|russian twist').hasMatch(n))return 'Core';
    return null;
  }
  bool _sameDay(DateTime a,DateTime b)=>a.year==b.year&&a.month==b.month&&a.day==b.day;
  bool _week(DateTime x,DateTime now){final start=DateTime(now.year,now.month,now.day).subtract(Duration(days:now.weekday-1));
    return !x.isBefore(start)&&x.isBefore(start.add(const Duration(days:7)));}
  @override Widget build(BuildContext context){
    final work=ref.watch(workoutStateProvider),health=ref.watch(appStateProvider).health;
    final now=DateTime.now();
    final completed=work.history.where((x)=>_week(x.completedAt,now)).toList();
    final connected=health.workouts.where((x)=>_week(x.start,now)).toList();
    final planned=work.scheduled.where((x)=>_week(x.scheduledFor,now)).toList();
    final totals={for(final group in groups)group:0};var unknown=0,totalSets=0;
    for(final entry in completed){for(final exercise in entry.exercises){
      final group=_group(exercise.name),sets=math.max(0,exercise.sets);totalSets+=sets;
      if(group==null){unknown+=sets;}else{totals[group]=totals[group]!+sets;}
    }}
    final upcoming=work.scheduled.where((e)=>!e.scheduledFor.isBefore(DateTime(now.year,now.month,now.day))).toList()
      ..sort((a,b)=>a.scheduledFor.compareTo(b.scheduledFor));
    final seven=<String>[],logged=<double?>[],scheduled=<double?>[];
    for(var i=6;i>=0;i--){final day=now.subtract(Duration(days:i));
      seven.add(['M','T','W','T','F','S','S'][day.weekday-1]);
      logged.add((completed.where((x)=>_sameDay(x.completedAt,day)).length+
        connected.where((x)=>_sameDay(x.start,day)).length).toDouble());
      scheduled.add(planned.where((x)=>_sameDay(x.scheduledFor,day)).length.toDouble());
    }
    return ValueListenableBuilder<bool>(valueListenable:SalusAppearance.light,builder:(context,light,_)=>ColoredBox(color:S77.bg,
      child:ListView(padding:const EdgeInsets.fromLTRB(17,17,17,40),children:[
        S77Title('Training',subtitle:'TRAIN · PROGRESS · REPEAT',trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          HealthyMeModuleMenuButton(current:HealthyMeModule.workout,onSelected:(m){switch(m){
            case HealthyMeModule.fitness:Navigator.of(context).popUntil((r)=>r.isFirst);break;
            case HealthyMeModule.workout:break;
            case HealthyMeModule.diet:Navigator.of(context).pushReplacementNamed('/diet');break;
            case HealthyMeModule.health:Navigator.of(context).pushReplacementNamed('/health');break;
          }}),const PremiumThemeButton()])),
        const SizedBox(height:10),SalusWeekStrip(day:now),
        const SizedBox(height:16),S77Hero(asset:'assets/premium/training_hero.jpg',title:'Build a\nstronger you.',
          caption:'Your training plan and completed sessions, all in one place.',height:191,onTap:widget.onToday),
        const SizedBox(height:13),Row(children:[
          Expanded(child:S77Metric(label:'Workouts',value:'${completed.length+connected.length}',
            caption:'completed this week',icon:Icons.fitness_center,color:S77.blue,height:92)),const SizedBox(width:8),
          Expanded(child:S77Metric(label:'Scheduled',value:'${planned.length}',
            caption:'this week',icon:Icons.calendar_today,color:S77.green,height:92,onTap:widget.onSchedule)),const SizedBox(width:8),
          Expanded(child:S77Metric(label:'Program sets',value:'$totalSets',
            caption:'from completed plans',icon:Icons.format_list_numbered,color:S77.orange,height:92)),
        ]),
        const SizedBox(height:16),S77Section('Weekly Training',action:'History',onTap:widget.onHistory),
        const SizedBox(height:7),S77Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          S77PairedChart(left:scheduled,right:logged,labels:seven,firstColor:S77.purple,secondColor:S77.blue),
          S77Legend(items:[(label:'Scheduled sessions',color:S77.purple),(label:'Recorded completions',color:S77.blue)]),
          const SizedBox(height:8),Text('Connected and Salus workouts may overlap; duplicates are not merged.',style:TextStyle(color:S77.dim,fontSize:10))
        ])),
        const SizedBox(height:16),S77Section('Muscle Workload',action:'Workouts',onTap:widget.onToday),
        const SizedBox(height:7),S77Surface(accent:S77.orange,child:Column(children:[
          ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.asset('assets/premium/muscle_reference.jpg',height:190,fit:BoxFit.contain)),
          const SizedBox(height:7),Text('Anatomy reference · categories derived from completed exercise names',
            textAlign:TextAlign.center,style:TextStyle(color:S77.dim,fontSize:10)),
          const SizedBox(height:13),for(final group in groups)Padding(padding:const EdgeInsets.only(bottom:11),child:Row(children:[
            SizedBox(width:84,child:Text(group,style:TextStyle(color:S77.ink,fontWeight:FontWeight.w700,fontSize:12))),
            Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(
              minHeight:10,value:totalSets==0?0.0:totals[group]!/totalSets,backgroundColor:S77.edge,color:_color(group)))),
            const SizedBox(width:10),SizedBox(width:40,child:Text('${totals[group]} sets',textAlign:TextAlign.right,
              style:TextStyle(color:S77.sub,fontSize:10)))])),
          if(unknown>0)Text('$unknown sets not classified by exercise name.',style:TextStyle(color:S77.sub,fontSize:10)),
          if(totalSets==0)Text('Complete a workout to populate the category graph.',style:TextStyle(color:S77.sub,fontSize:11)),
        ])),
        const SizedBox(height:18),S77Section('Upcoming Workouts',action:'Full schedule',onTap:widget.onSchedule),
        const SizedBox(height:6),if(upcoming.isEmpty)S77Surface(onTap:widget.onSchedule,child:Row(children:[
          Icon(Icons.event_available,color:S77.green,size:28),const SizedBox(width:12),
          Expanded(child:Text('No upcoming workouts. Build your training schedule.',style:TextStyle(color:S77.sub,fontSize:13))),
          Icon(Icons.chevron_right,color:S77.cyan)]))
        else for(final item in upcoming.take(4))Padding(padding:const EdgeInsets.only(bottom:8),child:S77Surface(onTap:widget.onSchedule,child:Row(children:[
          Container(height:41,width:4,decoration:BoxDecoration(color:S77.blue,borderRadius:BorderRadius.circular(4))),
          const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(item.name,style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:14)),
            const SizedBox(height:4),Text('${item.scheduledFor.month}/${item.scheduledFor.day} · ${item.exercises.length} exercises',
              style:TextStyle(color:S77.sub,fontSize:11))])),Icon(Icons.chevron_right,color:S77.cyan)
        ]))),
        const SizedBox(height:17),Row(children:[Expanded(child:OutlinedButton(onPressed:widget.onHistory,child:const Text('Workout History'))),
          const SizedBox(width:8),Expanded(child:FilledButton(onPressed:widget.onToday,child:const Text('Open Workouts')))]),
      ])));
  }
}
