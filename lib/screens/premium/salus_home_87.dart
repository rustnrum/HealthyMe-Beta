// Build 87: mockup-led real Home. No preview fixtures or manufactured readings.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/recovery_service.dart';
import '../../services/direct_metric_service.dart';
import '../../services/hrv_source_service.dart';
import '../../services/salus_energy_service.dart';
import '../../services/home_insight_service.dart';
import '../../state/app_state.dart';
import '../../state/diet_log_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/module_menu_button.dart';
import '../../widgets/salus77_design.dart';
import '../../widgets/salus_premium_ui.dart';
import 'salus87_ui.dart';

class SalusHome87 extends ConsumerStatefulWidget {
  const SalusHome87({super.key});
  @override ConsumerState<SalusHome87> createState() => _SalusHome87State();
}
class _SalusHome87State extends ConsumerState<SalusHome87> {
  double? _calorieGoal;
  List<DirectMetricSample> _ringHrvHistory=const [];
  @override void initState(){
    super.initState();
    _loadRingHrvHistory();_loadTarget();
  }
  Future<void> _loadRingHrvHistory() async {
    try {final x=await const DirectMetricService().loadSamples();
      if(mounted)setState(()=>_ringHrvHistory=x);
    }catch(_){/* Data access must never block Home. */}
  }
  Future<void> _loadTarget() async {
    try {final prefs=await SharedPreferences.getInstance();
      final n=prefs.getDouble('salus_nutrition_target_Calories');
      if(mounted)setState(()=>_calorieGoal=n!=null&&n>0?n:null);
    }catch(_){/* Unknown goal is not zero. */}
  }
  bool _sameDay(DateTime a,DateTime b)=>a.year==b.year&&a.month==b.month&&a.day==b.day;
  bool _week(DateTime a,DateTime now) {
    final start=DateTime(now.year,now.month,now.day).subtract(Duration(days:now.weekday-1));
    return !a.isBefore(start)&&a.isBefore(start.add(const Duration(days:7)));
  }
  String _day(DateTime d)=>'${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month-1]} ${d.day}';
  @override Widget build(BuildContext context) {
    final app=ref.watch(appStateProvider),health=app.health;
    ref.listen(appStateProvider,(previous,next){
      if(previous?.health!=next.health)_loadRingHrvHistory();
    });
    final work=ref.watch(workoutStateProvider),diet=ref.watch(dietLogStateProvider);
    final rec=RecoveryService.build(app,completedWorkouts:work.history);
    final hrv=HrvSourceService.resolve(health:health,
      selectedSource:app.metricSources['HRV'],directSamples:_ringHrvHistory);
    final energy=SalusEnergyService.estimate(health,app.profile);
    final insight=HomeInsightService.build(app);
    final now=DateTime.now();
    final name=app.profile.firstName.trim().isEmpty?'there':app.profile.firstName.trim().split(' ').first;
    final greeting=now.hour<12?'Good morning':now.hour<17?'Good afternoon':'Good evening';
    final sleep=health.sleepMinutes>0?'${health.sleepMinutes~/60}h ${health.sleepMinutes%60}m':'—';
    final hr=health.restingHeartRate==null?'—':'${health.restingHeartRate!.round()} bpm';
    final hrvValue=hrv.hasRmssd?'${hrv.rmssdMs!.round()} ms':hrv.hasIndex?
      '${hrv.latestIndex!.value.round()} index':'—';
    final load=rec.contributors.where((c)=>c.name=='Training load').first;
    final activity=load.reading??(load.score==null?'—':'${load.score} / 100');
    // Body Battery is a device-reported measurement, not Salus Energy.
    // A recent, source-attributed record is required; never synthesize it.
    final bodyBatteryRecords=_ringHrvHistory.where((sample)=>
      sample.metric=='Body battery' && sample.deviceId.isNotEmpty &&
      sample.sourceId.isNotEmpty && sample.value.isFinite &&
      sample.value>=1 && sample.value<=100 &&
      !sample.capturedAt.isAfter(now.add(const Duration(minutes:2))) &&
      !sample.capturedAt.isBefore(now.subtract(const Duration(hours:48)))
    ).toList()..sort((a,b)=>a.capturedAt.compareTo(b.capturedAt));
    final bodyBattery=bodyBatteryRecords.isEmpty?null:bodyBatteryRecords.last;
    final kcal=diet.knownTotal(now,(e)=>e.calories);
    final stepsKnown=health.resolvedSources.containsKey('Steps');
    final completedToday=work.history.where((w)=>_sameDay(w.completedAt,now)).length;
    final completedWeek=work.history.where((w)=>_week(w.completedAt,now)).length;
    return ColoredBox(color:S87.bg,child:ListView(
      padding:EdgeInsets.zero,children:[
      SizedBox(height:315,child:Stack(fit:StackFit.expand,children:[
        Image.asset('assets/premium/salus_mountain_85.webp',fit:BoxFit.cover,
          alignment:Alignment.center),
        const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(
          begin:Alignment.topCenter,end:Alignment.bottomCenter,
          stops:[0,.35,1],colors:[Color(0x79060A10),Color(0x57060A10),S87.bg]))),
        Padding(padding:const EdgeInsets.fromLTRB(18,18,18,15),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          S87Brand(trailing:Row(mainAxisSize:MainAxisSize.min,children:[
            IconButton(tooltip:'Voice assistant',onPressed:()=>Navigator.of(context).pushNamed('/voice'),
              icon:const Icon(Icons.mic_none_rounded,color:S87.ink,size:22)),
            HealthyMeModuleMenuButton(current:HealthyMeModule.fitness,
              iconColor:S87.ink,showLabel:false,lightSurface:false,
              onSelected:(module){switch(module){
                case HealthyMeModule.fitness:break;
                case HealthyMeModule.workout:Navigator.of(context).pushNamed('/workout');break;
                case HealthyMeModule.diet:Navigator.of(context).pushNamed('/diet');break;
                case HealthyMeModule.health:Navigator.of(context).pushNamed('/health');break;
              }}),
          ])),
          const Spacer(),
          Text('Today, ${_day(now)}',style:const TextStyle(color:S87.ink,fontSize:14)),
          const SizedBox(height:8),
          Text('$greeting,\n$name',style:const TextStyle(color:S87.ink,
            fontSize:34,fontWeight:FontWeight.w700,height:1.14)),
          const SizedBox(height:12),
          const Text('Train. Recover. Live better.',
            style:TextStyle(color:S87.ink,fontSize:13)),
          const SizedBox(height:14),
        ])),
      ])),
      Padding(padding:const EdgeInsets.fromLTRB(16,0,16,38),child:Column(children:[
        S87Panel(accent:S87.blue,padding:const EdgeInsets.all(14),
          onTap:()=>Navigator.of(context).pushNamed('/recovery'),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[const Icon(Icons.data_usage_rounded,color:S87.green,size:19),
              const SizedBox(width:8),const Expanded(child:Text('Recovery Score',style:
                TextStyle(color:S87.ink,fontSize:17,fontWeight:FontWeight.w700))),
              const Icon(Icons.chevron_right_rounded,color:S87.muted)]),
            const SizedBox(height:10),
            LayoutBuilder(builder:(context,c){
              final ringSize=(c.maxWidth-135).clamp(102.0,154.0).toDouble();
              return Row(children:[
                S87ArtworkRing(asset:'assets/preview84/img/ring_recovery.png',
                  size:ringSize,value:rec.score?.toString()??'—',
                  caption:rec.score==null?'Unavailable':rec.label,measured:rec.score!=null),
                const SizedBox(width:9),
                Expanded(child:Column(children:[
                  S87MetricLine(label:'Sleep',value:sleep,icon:Icons.nightlight_round,color:S87.purple),
                  S87MetricLine(label:hrv.hasIndex&&!hrv.hasRmssd?'HRV index':'HRV',value:hrvValue,
                    icon:Icons.monitor_heart_rounded,color:S87.blue),
                  S87MetricLine(label:'RHR',value:hr,icon:Icons.favorite_rounded,color:S87.red),
                  S87MetricLine(label:'Body Battery',
                    value:bodyBattery==null?'—':'${bodyBattery.value.round()} / 100',
                    icon:Icons.battery_charging_full_rounded,color:S87.green),
                  S87MetricLine(label:'Salus Energy',value:energy.score==null?'—':'${energy.score} est.',
                    icon:Icons.bolt_rounded,color:S87.teal),
                  S87MetricLine(label:'Activity Load',value:activity,
                    icon:Icons.bar_chart_rounded,color:S87.orange),
                ])),
              ]);
            }),
            const SizedBox(height:9),
            Text('${rec.confidence}% signal coverage • ${energy.quality.toLowerCase()} energy estimate',
              style:const TextStyle(color:S87.muted,fontSize:10)),
            if(bodyBattery!=null)Padding(
              padding:const EdgeInsets.only(top:5),
              child:Text('Body Battery · ${bodyBattery.deviceName} · '
                  '${bodyBattery.capturedAt.toLocal().month}/${bodyBattery.capturedAt.toLocal().day}',
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:S87.muted,fontSize:10))),
          ])),
        const SizedBox(height:14),
        S87Panel(accent:S87.purple,onTap:()=>Navigator.of(context).pushNamed('/health-intelligence'),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Row(children:[Icon(Icons.auto_awesome_rounded,color:S87.purple),
              SizedBox(width:9),Expanded(child:Text('AI Health Insight',
                style:TextStyle(color:S87.ink,fontSize:16,fontWeight:FontWeight.w700))),
              Icon(Icons.chevron_right_rounded,color:S87.muted)]),
            const SizedBox(height:10),
            Text(insight.message,style:const TextStyle(color:S87.ink,fontSize:13,height:1.5)),
          ])),
        const SizedBox(height:13),
        SizedBox(width:double.infinity,child:FilledButton.icon(
          onPressed:()=>Navigator.of(context).pushNamed('/workout'),
          icon:const Icon(Icons.arrow_forward_rounded,size:18),
          label:const Text("View Today's Plan"),
          style:FilledButton.styleFrom(backgroundColor:const Color(0xFF143A49),
            foregroundColor:S87.ink,padding:const EdgeInsets.symmetric(vertical:17),
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),
              side:const BorderSide(color:S87.teal))),
        )),
        const SizedBox(height:22),
        const S87Heading("Today's Overview"),
        const SizedBox(height:8),
        Row(children:[
          Expanded(child:S87Stat(icon:Icons.directions_walk_rounded,title:'Steps',
            value:stepsKnown?'${health.stepsToday}':'—',detail:'recorded today',color:S87.green,
            onTap:()=>Navigator.of(context).pushNamed('/activity-detail'))),
          const SizedBox(width:9),
          Expanded(child:S87Stat(icon:Icons.restaurant_menu_rounded,title:'Nutrition',
            value:kcal==null?'—':kcal.round().toString(),
            detail:kcal==null?'not logged':_calorieGoal==null?'kcal eaten':'of ${_calorieGoal!.round()} kcal',
            color:S87.orange,onTap:()=>Navigator.of(context).pushNamed('/diet'))),
        ]),const SizedBox(height:9),
        Row(children:[
          Expanded(child:S87Stat(icon:Icons.fitness_center_rounded,title:'Workout',
            value:'$completedToday',detail:'$completedWeek this week',color:S87.blue,
            onTap:()=>Navigator.of(context).pushNamed('/workout'))),
          const SizedBox(width:9),
          Expanded(child:S87Stat(icon:Icons.bedtime_rounded,title:'Sleep',value:sleep,
            detail:'last recorded night',color:S87.purple,
            onTap:()=>Navigator.of(context).pushNamed('/sleep-detail'))),
        ]),
        const SizedBox(height:20),
        S87Heading('Vital Trends',action:'View trends',onTap:()=>Navigator.of(context).pushNamed('/trends')),
        const SizedBox(height:8),
        // The existing verified 30-day RHR/HRV series must always have a
        // visible place in Home, even when no trend can yet be drawn.
        LayoutBuilder(builder:(context,constraints){
          final compact=constraints.maxWidth<360;
          final rhrPanel=S87Panel(accent:S87.red,
            onTap:()=>Navigator.of(context).pushNamed('/metric-resting-heart-rate'),
            padding:const EdgeInsets.all(12),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Resting Heart Rate',maxLines:1,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:S87.ink,fontSize:13,fontWeight:FontWeight.w700)),
              const SizedBox(height:5),
              Text(hr,style:const TextStyle(color:S87.red,fontSize:17,fontWeight:FontWeight.w800)),
              const SizedBox(height:7),
              S77RestingHeartChart(values:health.restingHeartRate30,
                height:112,color:S87.red),
              const SizedBox(height:6),
              Text('${health.restingHeartRate30.length} recorded days',
                style:const TextStyle(color:S87.muted,fontSize:10)),
            ]));
          final hasRmssdHistory=hrv.hasRmssd&&hrv.rmssdHistory.length>=2;
          final hasIndexHistory=!hrv.hasRmssd&&hrv.indexHistory.length>=2;
          final hrvChartValues=hasRmssdHistory?hrv.rmssdHistory:
            hasIndexHistory?hrv.indexHistory.map((v)=>v.value).toList():<double>[];
          final hrvPanel=S87Panel(accent:S87.blue,
            onTap:()=>Navigator.of(context).pushNamed('/metric-hrv'),
            padding:const EdgeInsets.all(12),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(hrv.hasIndex&&!hrv.hasRmssd?'Device HRV Index':'HRV (RMSSD)',
                maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:S87.ink,fontSize:13,fontWeight:FontWeight.w700)),
              const SizedBox(height:5),
              Text(hrvValue,style:const TextStyle(color:S87.blue,fontSize:17,fontWeight:FontWeight.w800)),
              const SizedBox(height:7),
              if(hasRmssdHistory||hasIndexHistory)
                PremiumLineChart(values:hrvChartValues,height:112,color:S87.blue,
                  unit:hasRmssdHistory?'ms':'index')
              else const SizedBox(height:112,child:Center(child:Text(
                  'No verified HRV trend yet. Tap to check your source.',
                  textAlign:TextAlign.center,
                  style:TextStyle(color:S87.muted,fontSize:11)))),
              const SizedBox(height:6),
              Text(hrv.hasIndex&&!hrv.hasRmssd?
                '${hrv.indexHistory.length} device index records · not RMSSD':
                hrv.hasRmssd?'${hrv.rmssdHistory.length} recorded RMSSD values':
                'Source: ${hrv.sourceLabel}',
                maxLines:2,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:S87.muted,fontSize:10)),
            ]));
          if(compact)return Column(children:[rhrPanel,
            const SizedBox(height:10),hrvPanel]);
          return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Expanded(child:rhrPanel),const SizedBox(width:10),Expanded(child:hrvPanel)]);
        }),
        const SizedBox(height:12),
        S87Panel(child:Text(rec.summary,style:const TextStyle(
          color:S87.muted,fontSize:12,height:1.5))),
        const SizedBox(height:18),
        S87Heading('Additional Health Metrics',action:'Sources',
          onTap:()=>Navigator.of(context).pushNamed('/sources')),
        const SizedBox(height:8),
        Row(children:[
          Expanded(child:S87Stat(icon:Icons.favorite_rounded,title:'Heart Rate',
            value:health.latestHeartRate==null?'—':'${health.latestHeartRate!.round()} bpm',
            detail:'latest recorded',color:S87.red,
            onTap:()=>Navigator.of(context).pushNamed('/metric-heart-rate'))),
          const SizedBox(width:9),
          Expanded(child:S87Stat(icon:Icons.bloodtype_outlined,title:'Blood Oxygen',
            value:health.bloodOxygenPercent==null?'—':'${health.bloodOxygenPercent!.round()}%',
            detail:'SpO₂',color:S87.blue,
            onTap:()=>Navigator.of(context).pushNamed('/spo2-history'))),
        ]),const SizedBox(height:9),
        Row(children:[
          Expanded(child:S87Stat(icon:Icons.air_rounded,title:'Respiratory Rate',
            value:health.respiratoryRate==null?'—':'${health.respiratoryRate!.toStringAsFixed(1)}',
            detail:'breaths per minute',color:S87.purple,
            onTap:()=>Navigator.of(context).pushNamed('/health'))),
          const SizedBox(width:9),
          Expanded(child:S87Stat(icon:Icons.local_fire_department_outlined,title:'Active Calories',
            value:((health.resolvedSources.keys.any((k)=>k.toLowerCase()=='active calories') ||
                (health.authorized && health.activeCaloriesToday>0)) &&
                health.activeCaloriesToday.isFinite &&
                health.activeCaloriesToday>=0 && health.activeCaloriesToday<=15000)?
                '${health.activeCaloriesToday.round()}':'—',
            detail:'kcal from activity',color:S87.orange,
            onTap:()=>Navigator.of(context).pushNamed('/metric-active-calories'))),
        ]),
      ])),
    ]));
  }
}
