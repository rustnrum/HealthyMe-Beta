// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/app_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/salus_premium_ui.dart';

/// Analytics only from completed sessions. The colored muscle groups describe
/// sets assigned to exercises by a simple, disclosed name mapping; they are
/// NOT measured activation, muscle growth, or a physiological recovery score.
class SalusTrainingOverview extends ConsumerStatefulWidget {
  const SalusTrainingOverview({super.key,required this.onToday,required this.onSchedule,required this.onHistory});
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
  bool _sameWeek(DateTime d,DateTime now){final start=DateTime(now.year,now.month,now.day).subtract(Duration(days:now.weekday-1));return !d.isBefore(start)&&d.isBefore(start.add(const Duration(days:7)));}
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
      Row(children:[Expanded(child:PremiumTitle(subtitle:'MOVEMENT & STRENGTH',title:'Training')),const PremiumThemeButton()]),
      const SizedBox(height:18),Row(children:[
        Expanded(child:PremiumCard(child:_stat(p,Icons.fitness_center_rounded,'Workouts','${completed.length+connected.length}','completed this week',SalusSkin.blue))),
        const SizedBox(width:8),Expanded(child:PremiumCard(child:_stat(p,Icons.event_rounded,'Planned','${planned.length}','scheduled this week',SalusSkin.green))),
        const SizedBox(width:8),Expanded(child:PremiumCard(child:_stat(p,Icons.view_list_rounded,'Program sets','$programSets','from completed plans',SalusSkin.orange))),
      ]),
      const SizedBox(height:18),const PremiumSection(title:'Training frequency · 7 days'),const SizedBox(height:8),
      PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        PremiumLineChart(values:activity,height:145,color:SalusSkin.blue),
        Text('Completed sessions by date (including connected workouts; overlapping sources may duplicate sessions).',style:TextStyle(color:p.secondary,fontSize:11)),
      ])),
      const SizedBox(height:21),const PremiumSection(title:'Muscle workload'),const SizedBox(height:8),
      PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(programSets==0)Text('Complete a workout containing exercises to see your program distribution.',style:TextStyle(color:p.secondary,fontSize:13)),
        if(programSets>0)...[
          SizedBox(height:190,child:Center(child:CustomPaint(size:const Size(145,178),painter:_MuscleDiagram(p,counts)))),
          const SizedBox(height:8),for(var i=0;i<groups.length;i++)_muscleRow(p,groups[i],counts[groups[i]]!,programSets,colors[i]),
          if(unclassified>0)Text('$unclassified sets are unclassified because the exercise name has no verified muscle mapping.',style:TextStyle(color:p.secondary,fontSize:11)),
        ],
        const SizedBox(height:8),Text('Colors describe exercise categories from completed workout plans, not measured muscle activation or recovery.',style:TextStyle(color:p.secondary,fontSize:11)),
      ])),
      const SizedBox(height:21),PremiumSection(title:'Upcoming workouts',trailing:'Full schedule',onTap:widget.onSchedule),
      const SizedBox(height:8),if(upcoming.isEmpty)PremiumCard(child:Column(children:[
        Text('No workout scheduled',style:TextStyle(color:p.ink,fontWeight:FontWeight.w700)),const SizedBox(height:10),
        Text('Use Schedule to plan a workout or add exercises from a template.',style:TextStyle(color:p.secondary,fontSize:12)),
        const SizedBox(height:10),FilledButton(onPressed:widget.onSchedule,child:const Text('Plan a workout')),
      ]))else ...[
        for(final item in upcoming.where((w)=>!w.scheduledFor.isBefore(DateTime(now.year,now.month,now.day))).take(3))
          Padding(padding:const EdgeInsets.only(bottom:8),child:PremiumCard(onTap:widget.onSchedule,child:Row(children:[
            Icon(Icons.calendar_today,color:p.accent),const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.name,style:TextStyle(color:p.ink,fontWeight:FontWeight.w700)),
              const SizedBox(height:4),Text('${item.scheduledFor.month}/${item.scheduledFor.day} · ${item.exercises.length} exercises',style:TextStyle(color:p.secondary,fontSize:12))])),Icon(Icons.chevron_right,color:p.secondary),
          ]))),
      ],
      const SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton(onPressed:widget.onHistory,child:const Text('Workout history'))),const SizedBox(width:9),Expanded(child:FilledButton(onPressed:widget.onToday,child:const Text('Open workouts')))]),
      const SizedBox(height:18),Text('Salus never fabricates workout volume, heart-rate zones or strength progression when the source does not provide them.',style:TextStyle(color:p.muted,fontSize:11)),
    ]));
  });
  Widget _stat(SalusSkin p,IconData icon,String label,String count,String caption,Color accent)=>SizedBox(height:95,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(icon,size:19,color:accent),const SizedBox(height:8),Text(count,style:TextStyle(color:p.ink,fontSize:23,fontWeight:FontWeight.w800)),
    Text(label,style:TextStyle(color:p.ink,fontSize:11,fontWeight:FontWeight.w700)),Text(caption,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:p.secondary,fontSize:9)),
  ]));
  Widget _muscleRow(SalusSkin p,String name,int count,int all,Color color)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Row(children:[
    SizedBox(width:84,child:Text(name,style:TextStyle(color:p.ink,fontSize:12,fontWeight:FontWeight.w600))),
    Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(9),child:LinearProgressIndicator(value:all==0?0:count/all,minHeight:9,color:color,backgroundColor:p.track))),
    const SizedBox(width:9),Text('$count sets',style:TextStyle(color:p.secondary,fontSize:11)),
  ]));
}

/// Deliberately diagrammatic, not medical anatomy. Front-body zones are tinted
/// only where completed workout names map to the selected category.
class _MuscleDiagram extends CustomPainter{
  const _MuscleDiagram(this.p,this.counts);
  final SalusSkin p;final Map<String,int> counts;
  Color tint(String group)=>counts[group]!>0? _SalusTrainingOverviewState.colors[_SalusTrainingOverviewState.groups.indexOf(group)]:p.track;
  @override void paint(Canvas c,Size s){
    void rect(double x,double y,double w,double h,double r,String g){c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,y,w,h),Radius.circular(r)),Paint()..color=tint(g));}
    final outer=Paint()..color=p.secondary.withValues(alpha:.8)..style=PaintingStyle.stroke..strokeWidth=1;
    c.drawOval(const Rect.fromLTWH(60,2,26,26),outer);
    rect(50,36,17,14,6,'Shoulders');rect(79,36,17,14,6,'Shoulders');
    rect(60,37,13,21,3,'Chest');rect(74,37,13,21,3,'Chest');
    rect(51,53,10,38,5,'Arms');rect(85,53,10,38,5,'Arms');
    rect(64,62,18,34,5,'Core');
    rect(60,99,15,54,5,'Legs');rect(78,99,15,54,5,'Legs');
    rect(62,157,12,16,3,'Legs');rect(79,157,12,16,3,'Legs');
    final title=TextPainter(text:TextSpan(text:'FRONT',style:TextStyle(color:p.muted,fontSize:9,letterSpacing:2)),textDirection:TextDirection.ltr)..layout();title.paint(c,const Offset(2,4));
  }
  @override bool shouldRepaint(covariant _MuscleDiagram old)=>old.counts!=counts||old.p.light!=p.light;
}
