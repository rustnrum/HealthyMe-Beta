// Build 87 Training Dashboard: mockup composition, backed by saved workouts.
// Completed records are not claimed to be verified 1RM or muscle activation.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/app_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/salus77_design.dart';
import 'salus87_ui.dart';

class SalusTraining87 extends ConsumerStatefulWidget {
  const SalusTraining87({super.key,required this.onToday,required this.onSchedule,required this.onHistory});
  final VoidCallback onToday,onSchedule,onHistory;
  @override ConsumerState<SalusTraining87> createState()=>_SalusTraining87State();
}
class _SalusTraining87State extends ConsumerState<SalusTraining87> {
  static const groups=['Chest','Back','Shoulders','Legs','Arms','Core'];
  int _weekOffset=0;
  Color _color(String s)=>switch(s){
    'Chest'=>S87.red,'Back'=>S87.blue,'Shoulders'=>S87.purple,
    'Legs'=>S87.orange,'Arms'=>S87.green,_=>S87.teal};
  String? _group(String s){
    final v=s.toLowerCase();
    if(RegExp('bench|push.up|chest|pec|fly').hasMatch(v))return 'Chest';
    if(RegExp('pull.up|pull.down|row|deadlift|lat |back').hasMatch(v))return 'Back';
    if(RegExp('squat|lunge|leg |calf|quad|hamstring|glute').hasMatch(v))return 'Legs';
    if(RegExp('shoulder|lateral raise|overhead|military press|delt').hasMatch(v))return 'Shoulders';
    if(RegExp('curl|tricep|bicep|hammer|pushdown|extension').hasMatch(v))return 'Arms';
    if(RegExp('plank|crunch|sit.up|core|abdom|russian twist').hasMatch(v))return 'Core';
    return null;
  }
  bool _sameDay(DateTime a,DateTime b)=>a.year==b.year&&a.month==b.month&&a.day==b.day;
  String _date(DateTime d)=>'${d.month}/${d.day}';
  @override Widget build(BuildContext context){
    final library=ref.watch(workoutStateProvider);
    final health=ref.watch(appStateProvider).health;
    final today=DateTime.now();
    final start=DateTime(today.year,today.month,today.day).subtract(Duration(days:today.weekday-1))
      .add(Duration(days:7*_weekOffset));
    final end=start.add(const Duration(days:7));
    final completed=library.history.where((w)=>!w.completedAt.isBefore(start)&&w.completedAt.isBefore(end)).toList();
    final connected=health.workouts.where((w)=>!w.start.isBefore(start)&&w.start.isBefore(end)).toList();
    final scheduled=library.scheduled.where((w)=>!w.scheduledFor.isBefore(start)&&w.scheduledFor.isBefore(end)).toList();
    final totals={for(final x in groups)x:0};var totalSets=0,unclassified=0;
    for(final workout in completed){for(final exercise in workout.exercises){
      final sets=math.max(0,exercise.sets);totalSets+=sets;
      final group=_group(exercise.name);
      if(group==null){unclassified+=sets;}else{totals[group]=totals[group]!+sets;}
    }}
    final logged=<double?>[],planned=<double?>[],labels=<String>[];
    for(var n=0;n<7;n++){
      final day=start.add(Duration(days:n));
      labels.add(['M','T','W','T','F','S','S'][n]);
      logged.add((completed.where((x)=>_sameDay(x.completedAt,day)).length+
        connected.where((x)=>_sameDay(x.start,day)).length).toDouble());
      planned.add(scheduled.where((x)=>_sameDay(x.scheduledFor,day)).length.toDouble());
    }
    final upcoming=library.scheduled.where((w)=>!w.scheduledFor.isBefore(DateTime(today.year,today.month,today.day))).toList()
      ..sort((a,b)=>a.scheduledFor.compareTo(b.scheduledFor));
    return ColoredBox(color:S87.bg,child:ListView(
      padding:const EdgeInsets.fromLTRB(16,18,16,40),children:[
      S87Brand(subtitle:'TRAIN  ·  PROGRESS  ·  LIVE BETTER',
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          IconButton(tooltip:'Home',onPressed:()=>Navigator.of(context).popUntil((r)=>r.isFirst),
            icon:const Icon(Icons.home_outlined,color:S87.ink)),
          IconButton(icon:const Icon(Icons.mic_none_rounded,color:S87.ink),
            tooltip:'Voice assistant',
            onPressed:()=>Navigator.of(context).pushNamed('/voice')),
          IconButton(icon:const Icon(Icons.calendar_month_outlined,color:S87.ink),
            tooltip:'Workout calendar',onPressed:widget.onSchedule),
        ])),
      const SizedBox(height:24),
      const Text('Training Dashboard',style:TextStyle(color:S87.ink,
        fontWeight:FontWeight.w700,fontSize:24)),
      const SizedBox(height:5),
      Row(children:[
        Expanded(child:Text('${_date(start)} – ${_date(end.subtract(const Duration(days:1)))}',
          style:const TextStyle(color:S87.muted,fontSize:12))),
        IconButton(tooltip:'Previous week',onPressed:()=>setState(()=>_weekOffset--),
          icon:const Icon(Icons.chevron_left_rounded,color:S87.muted)),
        IconButton(tooltip:'Current week',onPressed:_weekOffset==0?null:
          ()=>setState(()=>_weekOffset=0),icon:const Icon(Icons.today_rounded,color:S87.teal)),
        IconButton(tooltip:'Next week',onPressed:_weekOffset>=0?null:
          ()=>setState(()=>_weekOffset++),icon:const Icon(Icons.chevron_right_rounded,color:S87.muted)),
      ]),
      const SizedBox(height:9),
      Row(children:[for(var n=0;n<7;n++)Expanded(child:Padding(
        padding:const EdgeInsets.symmetric(horizontal:2),child:Container(
          decoration:BoxDecoration(
            color:_sameDay(start.add(Duration(days:n)),today)?S87.blue.withValues(alpha:.24):S87.card,
            borderRadius:BorderRadius.circular(12),
            border:Border.all(color:_sameDay(start.add(Duration(days:n)),today)?S87.blue:S87.border)),
          padding:const EdgeInsets.symmetric(vertical:10),
          child:Column(children:[
            Text(labels[n],style:const TextStyle(color:S87.muted,fontSize:10)),
            const SizedBox(height:5),
            Text('${start.add(Duration(days:n)).day}',style:const TextStyle(color:S87.ink,
              fontWeight:FontWeight.w700,fontSize:14)),
            const SizedBox(height:6),Container(width:5,height:5,decoration:BoxDecoration(
              shape:BoxShape.circle,color:logged[n]!>0?S87.green:planned[n]!>0?S87.orange:S87.border)),
          ]))))]),
      const SizedBox(height:13),
      const S87PhotoBanner(asset:'assets/premium/training_hero.jpg',
        title:'Build a\nstronger you.',height:155,
        caption:'Your workouts, progress and weekly plan.'),
      const SizedBox(height:14),
      Row(children:[
        Expanded(child:S87Stat(icon:Icons.fitness_center_rounded,title:'Workouts',
          value:'${completed.length+connected.length}',detail:'recorded this week',color:S87.blue,
          onTap:widget.onHistory)),const SizedBox(width:8),
        Expanded(child:S87Stat(icon:Icons.view_agenda_rounded,title:'Program Sets',
          value:'$totalSets',detail:'completed plans',color:S87.green,onTap:widget.onHistory)),
        const SizedBox(width:8),
        Expanded(child:S87Stat(icon:Icons.access_time_rounded,title:'Scheduled',
          value:'${scheduled.length}',detail:'this week',color:S87.purple,onTap:widget.onSchedule)),
      ]),
      const SizedBox(height:24),
      S87Heading('Strength Progress',action:'History',onTap:widget.onHistory),
      const SizedBox(height:6),
      S87Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Weekly workout consistency',style:TextStyle(color:S87.ink,fontWeight:FontWeight.w600,fontSize:14)),
        const SizedBox(height:4),
        const Text('Recorded completions vs scheduled sessions',style:TextStyle(color:S87.muted,fontSize:11)),
        const SizedBox(height:18),
        S77PairedChart(left:planned,right:logged,labels:labels,
          firstColor:S87.purple,secondColor:S87.blue),
        const SizedBox(height:10),
        Row(children:[
          const Icon(Icons.circle,color:S87.purple,size:9),const SizedBox(width:5),
          const Text('Scheduled',style:TextStyle(color:S87.muted,fontSize:11)),
          const SizedBox(width:15),
          const Icon(Icons.circle,color:S87.blue,size:9),const SizedBox(width:5),
          const Text('Completed',style:TextStyle(color:S87.muted,fontSize:11)),
        ]),
        const SizedBox(height:8),
        const Text('A recorded session may also come from a connected source.',
          style:TextStyle(color:S87.muted,fontSize:10)),
      ])),
      const SizedBox(height:22),
      S87Heading('Muscle Analytics',action:'Open workouts',onTap:widget.onToday),
      const SizedBox(height:8),
      S87Panel(child:Column(children:[
        ClipRRect(borderRadius:BorderRadius.circular(13),
          child:Image.asset('assets/premium/muscle_reference.jpg',
            height:245,width:double.infinity,fit:BoxFit.contain)),
        const SizedBox(height:7),
        const Text('Anatomy reference · exercise-name classifications, not measured muscle activation',
          textAlign:TextAlign.center,style:TextStyle(color:S87.muted,fontSize:10)),
        const SizedBox(height:11),
        for(final group in groups)S87GroupBar(label:group,value:'${totals[group]} sets',
          fraction:totalSets>0?totals[group]!/totalSets:0,color:_color(group)),
        if(totalSets==0)const Text('Complete a workout to populate your muscle workload.',
          style:TextStyle(color:S87.muted,fontSize:12)),
        if(unclassified>0)Text('$unclassified sets could not be classified.',
          style:const TextStyle(color:S87.muted,fontSize:11)),
      ])),
      const SizedBox(height:22),
      S87Heading('Workout Schedule',action:'See all',onTap:widget.onSchedule),
      const SizedBox(height:7),
      if(upcoming.isEmpty)S87Panel(onTap:widget.onSchedule,child:Row(children:[
        const Icon(Icons.event_note,color:S87.blue),const SizedBox(width:12),
        const Expanded(child:Text('No upcoming workouts. Plan your next session.',
          style:TextStyle(color:S87.muted,fontSize:12))),
        const Icon(Icons.chevron_right,color:S87.muted),
      ]))
      else for(final x in upcoming.take(5))Padding(
        padding:const EdgeInsets.only(bottom:8),child:S87Panel(onTap:widget.onSchedule,
          padding:const EdgeInsets.all(13),child:Row(children:[
            Container(height:43,width:4,decoration:BoxDecoration(color:S87.blue,
              borderRadius:BorderRadius.circular(5))),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(x.name,maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:S87.ink,fontWeight:FontWeight.w700,fontSize:14)),
              const SizedBox(height:4),
              Text('${_date(x.scheduledFor)}  ·  ${x.exercises.length} exercises',
                style:const TextStyle(color:S87.muted,fontSize:11)),
            ])),
            const Icon(Icons.circle_outlined,color:S87.muted),
          ]))),
      const SizedBox(height:18),
      Row(children:[
        Expanded(child:OutlinedButton(onPressed:widget.onHistory,child:const Text('History'))),
        const SizedBox(width:10),
        Expanded(child:FilledButton(onPressed:widget.onToday,child:const Text('Open Workouts'))),
      ]),
    ]));
  }
}
