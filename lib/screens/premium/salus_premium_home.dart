// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/recovery_service.dart';
import '../../services/home_insight_service.dart';
import '../../state/app_state.dart';
import '../../state/diet_log_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/salus_premium_ui.dart';

/// Premium overview: live data only. The original fitness, sleep, and device
/// screens remain accessible from their existing modules and routes.
class SalusPremiumHome extends ConsumerStatefulWidget {
  const SalusPremiumHome({super.key});
  @override ConsumerState<SalusPremiumHome> createState()=>_SalusPremiumHomeState();
}
class _SalusPremiumHomeState extends ConsumerState<SalusPremiumHome> {
  @override void initState(){super.initState();SalusAppearance.load();}
  @override Widget build(BuildContext context)=>ValueListenableBuilder<bool>(
    valueListenable:SalusAppearance.light,builder:(context,light,_){
      final p=SalusSkin(light),app=ref.watch(appStateProvider),h=app.health;
      final log=ref.watch(dietLogStateProvider);
      final workouts=ref.watch(workoutStateProvider);
      final recovery=RecoveryService.build(app,completedWorkouts:workouts.history);
      final insight=HomeInsightService.build(app);
      final today=DateTime.now();
      final kcal=log.knownTotal(today,(e)=>e.calories);
      final first=app.profile.firstName.trim().isEmpty?'there':app.profile.firstName.trim().split(' ').first;
      final todayCompleted=workouts.history.where((w)=>w.completedAt.year==today.year&&w.completedAt.month==today.month&&w.completedAt.day==today.day).length;
      final days=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return ColoredBox(color:p.canvas,child:ListView(padding:const EdgeInsets.fromLTRB(18,18,18,32),children:[
        Row(children:[Text('SALUS',style:TextStyle(color:p.ink,fontWeight:FontWeight.w900,letterSpacing:5,fontSize:21)),
          const Spacer(),const PremiumThemeButton(),IconButton(tooltip:'Salus AI',onPressed:()=>Navigator.pushNamed(context,'/voice'),icon:Icon(Icons.auto_awesome,color:p.accent))]),
        const SizedBox(height:17),PremiumTitle(subtitle:_greeting(today.hour),title:first),
        const SizedBox(height:18),SizedBox(height:65,child:Row(children:[for(var i=6;i>=0;i--) Expanded(child:Builder(builder:(context){
          final d=today.subtract(Duration(days:i));final selected=i==0;
          return Column(children:[Text(days[d.weekday-1],style:TextStyle(color:p.secondary,fontSize:11)),const SizedBox(height:5),
            CircleAvatar(radius:17,backgroundColor:selected?p.accent:p.panel,child:Text('${d.day}',style:TextStyle(color:selected?(light?Colors.white:p.canvas):p.ink,fontSize:13,fontWeight:selected?FontWeight.w800:FontWeight.w400)))]);
        }))])),
        const SizedBox(height:10),PremiumCard(padding:EdgeInsets.zero,onTap:()=>Navigator.pushNamed(context,'/recovery'),child:ClipRRect(borderRadius:BorderRadius.circular(20),child:SizedBox(height:106,child:Stack(fit:StackFit.expand,children:[
          Image.asset('lib/assets/images/hero_mountains.jpg',fit:BoxFit.cover),
          Container(decoration:BoxDecoration(gradient:LinearGradient(colors:[Colors.black.withValues(alpha:.68),Colors.transparent]))),
          const Positioned(left:18,top:24,child:Text('Small steps create\nbig changes.',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w800))),
          const Positioned(right:16,bottom:16,child:Icon(Icons.arrow_forward_ios,color:Colors.white,size:18)),
        ])))),
        const SizedBox(height:21),const PremiumSection(title:"Today's overview"),const SizedBox(height:12),
        Row(children:[
          Expanded(child:PremiumCard(onTap:()=>Navigator.pushNamed(context,'/activity-detail'),child:_mini(p,'Activity',h.resolvedSources.containsKey('Steps')?'${h.stepsToday}':'—', 'steps',Icons.directions_walk_rounded,SalusSkin.green))),
          const SizedBox(width:10),Expanded(child:PremiumCard(onTap:()=>Navigator.pushNamed(context,'/diet'),child:_mini(p,'Nutrition',kcal==null?'—':kcal.round().toString(),'kcal actually eaten',Icons.restaurant_rounded,SalusSkin.orange))),
        ]),const SizedBox(height:10),Row(children:[
          Expanded(child:PremiumCard(onTap:()=>Navigator.pushNamed(context,'/workout'),child:_mini(p,'Workout','$todayCompleted','completed today',Icons.fitness_center_rounded,SalusSkin.blue))),
          const SizedBox(width:10),Expanded(child:PremiumCard(onTap:()=>Navigator.pushNamed(context,'/recovery'),child:_mini(p,'Sleep',h.sleepMinutes>0?'${h.sleepMinutes~/60}h ${h.sleepMinutes%60}m':'—','last recorded',Icons.bedtime_rounded,SalusSkin.purple))),
        ]),
        const SizedBox(height:13),PremiumCard(onTap:()=>Navigator.pushNamed(context,'/recovery'),child:Row(children:[
          Icon(Icons.favorite_rounded,color:const Color(0xffef7978),size:24),const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Recovery',style:TextStyle(color:p.ink,fontSize:17,fontWeight:FontWeight.w800)),
            const SizedBox(height:5),Text(recovery.summary,maxLines:3,overflow:TextOverflow.ellipsis,style:TextStyle(color:p.secondary,fontSize:12)),
            const SizedBox(height:4),Text('${recovery.confidence}% data coverage',style:TextStyle(color:p.muted,fontSize:11))])),
          const SizedBox(width:8),PremiumRing(value:recovery.score?.toDouble(),maximum:100,center:recovery.score?.toString()??'—',caption:recovery.score==null?'No score':recovery.label,color:SalusSkin.green,size:82),
        ])),
        const SizedBox(height:13),PremiumCard(onTap:()=>Navigator.pushNamed(context,'/health-intelligence'),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.insights_rounded,color:p.accent,size:23),const SizedBox(width:11),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('What your data says',style:TextStyle(color:p.ink,fontWeight:FontWeight.w800,fontSize:16)),
            const SizedBox(height:6),Text(insight.message,style:TextStyle(color:p.secondary,fontSize:13,height:1.4)),
            const SizedBox(height:7),Text(insight.source,style:TextStyle(color:p.muted,fontSize:11))])),
          Icon(Icons.chevron_right,color:p.secondary),
        ])),
        const SizedBox(height:22),const PremiumSection(title:'Explore your health'),const SizedBox(height:9),
        PremiumCard(onTap:()=>Navigator.pushNamed(context,'/health-intelligence'),child:Row(children:[Icon(Icons.monitor_heart_outlined,color:p.accent),const SizedBox(width:9),Expanded(child:Text('Vitals, trends & skin temperature',style:TextStyle(color:p.ink,fontWeight:FontWeight.w700))),Icon(Icons.arrow_forward_ios,size:16,color:p.secondary)])),
        const SizedBox(height:14),Text('All values come from your logged entries or connected measurements. Unavailable data is not estimated.',style:TextStyle(color:p.muted,fontSize:11)),
      ]));
    });
  String _greeting(int h)=>h<12?'Good morning,':h<17?'Good afternoon,':'Good evening,';
  Widget _mini(SalusSkin p,String title,String value,String detail,IconData icon,Color accent)=>
    SizedBox(height:99,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(icon,size:20,color:accent),const SizedBox(width:7),Expanded(child:Text(title,style:TextStyle(color:p.ink,fontWeight:FontWeight.w700,fontSize:14)))]),
      const Spacer(),Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:p.ink,fontSize:23,fontWeight:FontWeight.w900)),
      const SizedBox(height:2),Text(detail,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:p.secondary,fontSize:11)),
    ]));
}
