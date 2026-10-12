// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/app_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/salus_premium_ui.dart';
import '../../widgets/salus_premium_visuals.dart';
import '../../widgets/module_menu_button.dart';

/// Analytics only from completed sessions. The colored muscle groups describe
/// sets assigned to exercises by a simple, disclosed name mapping; they are
/// NOT measured activation, muscle growth, or a physiological recovery score.
class SalusTrainingOverview extends ConsumerStatefulWidget {
  SalusTrainingOverview({super.key,required this.onToday,required this.onSchedule,required this.onHistory});
  final VoidCallback onToday,onSchedule,onHistory;
  @override ConsumerState<SalusTrainingOverview> createState()=>_SalusTrainingOverviewState();
}
class _SalusTrainingOverviewState extends ConsumerState<SalusTrainingOverview>{
  @override void initState(){super.initState();SalusAppearance.load();}
  static const groups=['Chest','Back','Legs','Shoulders','Arms','Core'];
  static const colors=[Color(0xffed7876),SalusSkin.blue,SalusSkin.orange,SalusSkin.purple,SalusSkin.green,Color(0xffe2bf60)];
  static String? group(String name){final n=name.toLowerCase();
    if(RegExp('bench|push.up|chest|pec|fly').hasMatch(n))return 'Chest';
    if(RegExp('pull.up|pull.down|row|deadlift|lat |back').hasMatch(n))return 'Back';
    if(RegExp('squat|lunge|leg |calf|quad|hamstring|glute').hasMatch(n))return 'Legs';
    if(RegExp('shoulder|lateral raise|overhead|military press|delt').hasMatch(n))return 'Shoulders';
    if(RegExp('curl|tricep|bicep|hammer|pushdown|extension').hasMatch(n))return 'Arms';
    if(RegExp('plank|crunch|sit.up|core|abdom|russian twist').hasMatch(n))return 'Core';
    return null;
  }
  bool _sameWeek(DateTime d,DateTime now){final start=DateTime(now.year,now.month,now.day).subtract(Duration(days:now.weekday-1));return !d.isBefore(start)&&d.isBefore(start.add(Duration(days:7)));}
  @override Widget build(BuildContext context)=>ValueListenableBuilder<bool>(valueListenable:SalusAppearance.light,builder:(context,light,_){
    final p=SalusSkin(light),state=ref.watch(workoutStateProvider),h=ref.watch(appStateProvider).health;
    final now=DateTime.now(),completed=state.history.where((w)=>_sameWeek(w.completedAt,now)).toList();
    final connected=h.workouts.where((w)=>_sameWeek(w.start,now)).toList();
    final planned=state.scheduled.where((w)=>_sameWeek(w.scheduledFor,now)).toList();
    final counts={for(final g in groups)g:0};
    var unclassified=0;var programSets=0;
    for(final w in completed){for(final e in w.exercises){
      final g=group(e.name);final sets=math.max(0,e.sets);
      if(g==null){unclassified+=sets;}else{counts[g]=counts[g]!+sets;}programSets+=sets;
    }}
    final activity=<double?>[];
    for(var i=6;i>=0;i--){final d=DateTime(now.year,now.month,now.day).subtract(Duration(days:i));
      activity.add((state.history.where((w)=>w.completedAt.year==d.year&&w.completedAt.month==d.month&&w.completedAt.day==d.day).length+
        h.workouts.where((w)=>w.start.year==d.year&&w.start.month==d.month&&w.start.day==d.day).length).toDouble());}
    final upcoming=[...state.scheduled]..sort((a,b)=>a.scheduledFor.compareTo(b.scheduledFor));
    return ColoredBox(color:p.canvas,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,40),children:[
      Row(children:[Expanded(child:SalusHeading('Training',caption:'MOVEMENT & STRENGTH')),
       HealthyMeModuleMenuButton(current:HealthyMeModule.workout,onSelected:(m){switch(m){
         case HealthyMeModule.fitness:Navigator.of(context).popUntil((r)=>r.isFirst);break;
         case HealthyMeModule.workout:break;
         case HealthyMeModule.diet:Navigator.of(context).pushReplacementNamed('/diet');break;
         case HealthyMeModule.health:Navigator.of(context).pushReplacementNamed('/health');break;
       }}),PremiumThemeButton()]),
      SizedBox(height:13),SalusWeekStrip(),SizedBox(height:16),
      SalusPhotoHero(asset:'assets/premium/training_hero.jpg',title:'Build a\nstronger you.',
        subtitle:'Keep up your program, one session at a time.',height:157,buttonText:'View workouts',onTap:widget.onToday),
      SizedBox(height:18),Row(children:[
        Expanded(child:PremiumCard(child:_stat(p,Icons.fitness_center_rounded,'Workouts','${completed.length+connected.length}','completed this week',SalusSkin.blue))),
        SizedBox(width:8),Expanded(child:PremiumCard(child:_stat(p,Icons.event_rounded,'Planned','${planned.length}','scheduled this week',SalusSkin.green))),
        SizedBox(width:8),Expanded(child:PremiumCard(child:_stat(p,Icons.view_list_rounded,'Program sets','$programSets','from completed plans',SalusSkin.orange))),
      ]),
      SizedBox(height:18),PremiumSection(title:'Training frequency · 7 days'),SizedBox(height:8),
      PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(completed.isNotEmpty||connected.isNotEmpty)PremiumLineChart(values:activity,height:145,color:SalusSkin.blue)
        else Padding(padding:EdgeInsets.symmetric(vertical:24),child:Text('No completed training sessions recorded this week.',style:TextStyle(color:SalusV.secondary,fontSize:12))),
        Text('Completed sessions by date (including connected workouts; overlapping sources may duplicate sessions).',style:TextStyle(color:p.secondary,fontSize:11)),
      ])),
      SizedBox(height:21),PremiumSection(title:'Muscle workload'),SizedBox(height:8),
      PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Center(child:ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.asset('assets/premium/muscle_reference.jpg',height:225,fit:BoxFit.contain))),
        SizedBox(height:8),Text('Anatomy reference illustration · colors are not measured activation.',style:TextStyle(color:p.muted,fontSize:10)),
        SizedBox(height:10),
        if(programSets==0)Text('Log a completed workout to show actual sets by muscle group.',style:TextStyle(color:p.secondary,fontSize:13)),
        if(programSets>0)...[
          SizedBox(height:8),for(var i=0;i<groups.length;i++)_muscleRow(p,groups[i],counts[groups[i]]!,programSets,colors[i]),
          if(unclassified>0)Text('$unclassified sets are unclassified because the exercise name has no verified muscle mapping.',style:TextStyle(color:p.secondary,fontSize:11)),
        ],
        SizedBox(height:8),Text('Colors describe exercise categories from completed workout plans, not measured muscle activation or recovery.',style:TextStyle(color:p.secondary,fontSize:11)),
      ])),
      SizedBox(height:21),PremiumSection(title:'Upcoming workouts',trailing:'Full schedule',onTap:widget.onSchedule),
      SizedBox(height:8),if(upcoming.isEmpty)PremiumCard(child:Column(children:[
        Text('No workout scheduled',style:TextStyle(color:p.ink,fontWeight:FontWeight.w700)),SizedBox(height:10),
        Text('Use Schedule to plan a workout or add exercises from a template.',style:TextStyle(color:p.secondary,fontSize:12)),
        SizedBox(height:10),FilledButton(onPressed:widget.onSchedule,child:Text('Plan a workout')),
      ]))else ...[
        for(final item in upcoming.where((w)=>!w.scheduledFor.isBefore(DateTime(now.year,now.month,now.day))).take(3))
          Padding(padding:const EdgeInsets.only(bottom:8),child:PremiumCard(onTap:widget.onSchedule,child:Row(children:[
            Icon(Icons.calendar_today,color:p.accent),SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.name,style:TextStyle(color:p.ink,fontWeight:FontWeight.w700)),
              SizedBox(height:4),Text('${item.scheduledFor.month}/${item.scheduledFor.day} · ${item.exercises.length} exercises',style:TextStyle(color:p.secondary,fontSize:12))])),Icon(Icons.chevron_right,color:p.secondary),
          ]))),
      ],
      SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton(onPressed:widget.onHistory,child:Text('Workout history'))),SizedBox(width:9),Expanded(child:FilledButton(onPressed:widget.onToday,child:Text('Open workouts')))]),
      SizedBox(height:18),Text('Salus never fabricates workout volume, heart-rate zones or strength progression when the source does not provide them.',style:TextStyle(color:p.muted,fontSize:11)),
    ]));
  });
  Widget _stat(SalusSkin p,IconData icon,String label,String count,String caption,Color accent)=>SizedBox(height:95,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(icon,size:19,color:accent),SizedBox(height:8),Text(count,style:TextStyle(color:p.ink,fontSize:23,fontWeight:FontWeight.w800)),
    Text(label,style:TextStyle(color:p.ink,fontSize:11,fontWeight:FontWeight.w700)),Text(caption,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:p.secondary,fontSize:9)),
  ]));
  Widget _muscleRow(SalusSkin p,String name,int count,int all,Color color)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Row(children:[
    SizedBox(width:84,child:Text(name,style:TextStyle(color:p.ink,fontSize:12,fontWeight:FontWeight.w600))),
    Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(9),child:LinearProgressIndicator(value:all==0?0:count/all,minHeight:9,color:color,backgroundColor:p.track))),
    SizedBox(width:9),Text('$count sets',style:TextStyle(color:p.secondary,fontSize:11)),
  ]));
}
