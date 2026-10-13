// Build 77 Health: source-verified summaries and premium visual composition.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/recovery_service.dart';
import '../../services/direct_metric_service.dart';
import '../../services/hrv_source_service.dart';
import '../../services/salus_energy_service.dart';
import '../../state/app_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/module_menu_button.dart';
import '../../widgets/salus_premium_ui.dart';
import '../../widgets/salus77_design.dart';

class SalusHealth77 extends ConsumerStatefulWidget {
  const SalusHealth77({super.key});
  @override ConsumerState<SalusHealth77> createState()=>_SalusHealth77State();
}
class _SalusHealth77State extends ConsumerState<SalusHealth77>{
  List<DirectMetricSample> _hrvSamples=const [];
  Future<void> _loadHrvSamples() async {
    try {
      final samples=await const DirectMetricService().loadSamples();
      if(mounted) setState(()=>_hrvSamples=samples);
    } catch (_) { /* A missing history must not block Health. */ }
  }
  @override void initState(){super.initState();SalusAppearance.load();_loadHrvSamples();}
  @override Widget build(BuildContext context){
    final app=ref.watch(appStateProvider),workouts=ref.watch(workoutStateProvider);
    final health=app.health,rec=RecoveryService.build(app,completedWorkouts:workouts.history);
    ref.listen(appStateProvider,(previous,next){
      if(previous?.health!=next.health) _loadHrvSamples();
    });
    final hrvView=HrvSourceService.resolve(health:health,
        selectedSource:app.metricSources['HRV'],directSamples:_hrvSamples);
    final energy=SalusEnergyService.estimate(health,app.profile);
    final hasStages=health.sleepDeepMinutes+health.sleepRemMinutes+health.sleepLightMinutes>0;
    return ValueListenableBuilder<bool>(valueListenable:SalusAppearance.light,builder:(context,light,_)=>ColoredBox(color:S77.bg,
      child:ListView(padding:const EdgeInsets.fromLTRB(17,17,17,38),children:[
        S77Title('Health',subtitle:'YOUR WHOLE HEALTH IN FOCUS',trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          HealthyMeModuleMenuButton(iconColor:S77.ink,showLabel:true,lightSurface:light,current:HealthyMeModule.health,onSelected:(m){switch(m){
            case HealthyMeModule.fitness:Navigator.of(context).popUntil((r)=>r.isFirst);break;
            case HealthyMeModule.workout:Navigator.of(context).pushReplacementNamed('/workout');break;
            case HealthyMeModule.diet:Navigator.of(context).pushReplacementNamed('/diet');break;
            case HealthyMeModule.health:break;
          }}),const PremiumThemeButton()])),
        const SizedBox(height:16),S77Tabs(items:const ['Overview','Sleep','Recovery','Vitals'],selected:0,onSelected:(v){
          final route=switch(v){1=>'/sleep-detail',2=>'/recovery',3=>'/metric-heart-rate',_=>null};
          if(route!=null)Navigator.of(context).pushNamed(route);
        }),
        const SizedBox(height:14),S77Surface(accent:S77.green,onTap:()=>Navigator.pushNamed(context,'/recovery'),child:Row(children:[
          S77Arc(size:149,center:rec.score?.toString()??'—',caption:rec.score==null?'No score':rec.label,
            segments:rec.score==null?[]:[(value:rec.score!.toDouble(),color:S77.green),
              (value:(100-rec.score!).toDouble(),color:S77.edge)]),
          const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Recovery Score',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w900,fontSize:16)),
            const SizedBox(height:8),Text(rec.summary,maxLines:5,overflow:TextOverflow.ellipsis,
              style:TextStyle(color:S77.sub,fontSize:11,height:1.45)),
            const SizedBox(height:10),Text('${rec.confidence}% signal coverage',style:TextStyle(color:S77.green,fontWeight:FontWeight.w800,fontSize:11)),
          ])),
        ])),
        const SizedBox(height:13),S77Section('Sleep',action:'Details',onTap:()=>Navigator.pushNamed(context,'/sleep-detail')),
        const SizedBox(height:5),S77Surface(accent:S77.purple,onTap:()=>Navigator.pushNamed(context,'/sleep-detail'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Icon(Icons.nights_stay_rounded,color:S77.purple,size:25),const SizedBox(width:10),
            Expanded(child:Text(health.sleepMinutes>0?'${health.sleepMinutes~/60}h ${health.sleepMinutes%60}m':'No sleep recorded',
              style:TextStyle(color:S77.ink,fontSize:26,fontWeight:FontWeight.w900))),
            Icon(Icons.chevron_right,color:S77.cyan)]),
          const SizedBox(height:10),if(hasStages)ClipRRect(borderRadius:BorderRadius.circular(7),child:Row(children:[
            if(health.sleepDeepMinutes>0)Expanded(flex:health.sleepDeepMinutes,child:Container(color:S77.purple,height:14)),
            if(health.sleepLightMinutes>0)Expanded(flex:health.sleepLightMinutes,child:Container(color:S77.blue,height:14)),
            if(health.sleepRemMinutes>0)Expanded(flex:health.sleepRemMinutes,child:Container(color:S77.cyan,height:14)),
          ]))else Container(height:12,decoration:BoxDecoration(color:S77.edge,borderRadius:BorderRadius.circular(8))),
          const SizedBox(height:11),if(hasStages)S77Legend(items:[
            (label:'Deep ${health.sleepDeepMinutes}m',color:S77.purple),
            (label:'Light ${health.sleepLightMinutes}m',color:S77.blue),
            (label:'REM ${health.sleepRemMinutes}m',color:S77.cyan)])
          else Text('Stages unavailable from selected source',style:TextStyle(color:S77.sub,fontSize:11)),
          const SizedBox(height:7),Text('Source: ${health.resolvedSources['Sleep']??'Not selected'}',style:TextStyle(color:S77.dim,fontSize:10)),
        ])),
        const SizedBox(height:15),S77Section('Heart & HRV',action:'Trends',onTap:()=>Navigator.pushNamed(context,'/trends')),
        const SizedBox(height:6),Row(children:[
          Expanded(child:S77Metric(label:'Resting HR',value:health.restingHeartRate==null?'—':'${health.restingHeartRate!.round()}',
            caption:'bpm',icon:Icons.favorite,color:S77.red,height:91,onTap:()=>Navigator.pushNamed(context,'/metric-resting-heart-rate'))),
          const SizedBox(width:9),Expanded(child:S77Metric(
            label:hrvView.hasRmssd?'HRV':hrvView.hasIndex?'HRV device index':'HRV',
            value:hrvView.hasRmssd?'${hrvView.rmssdMs!.round()}':
                hrvView.hasIndex?'${hrvView.latestIndex!.value.round()}':'—',
            caption:hrvView.hasIndex&&!hrvView.hasRmssd?'index · not RMSSD':'ms',
            icon:Icons.monitor_heart,color:S77.cyan,height:91,
            onTap:()=>Navigator.pushNamed(context,'/metric-hrv'))),
        ]),const SizedBox(height:9),Row(children:[
          Expanded(child:S77Metric(label:'Blood oxygen',value:health.bloodOxygenPercent==null?'—':'${health.bloodOxygenPercent!.round()}',
            caption:'%',icon:Icons.water_drop_outlined,color:S77.blue,height:91,onTap:()=>Navigator.pushNamed(context,'/spo2-history'))),
          const SizedBox(width:9),Expanded(child:S77Metric(label:'Breathing',value:health.respiratoryRate==null?'—':health.respiratoryRate!.toStringAsFixed(1),
            caption:'breaths/min',icon:Icons.air_rounded,color:S77.orange,height:91,onTap:()=>Navigator.pushNamed(context,'/metric-respiratory-rate'))),
        ]),
        const SizedBox(height:11),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:S77Surface(accent:S77.red,padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Resting heart rate',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:12)),
            const SizedBox(height:8),PremiumLineChart(values:health.restingHeartRate30.map((x)=>x.toDouble()).toList(),color:S77.red,height:118,unit:'bpm'),
          ]))),const SizedBox(width:9),
          Expanded(child:S77Surface(accent:S77.cyan,padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(hrvView.hasIndex&&!hrvView.hasRmssd?'HRV device index':'HRV history',
                style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:12)),
            const SizedBox(height:8),PremiumLineChart(
              values:hrvView.hasRmssd
                ? hrvView.rmssdHistory.map((x)=>x.toDouble()).toList()
                : hrvView.indexHistory.map((x)=>x.value).toList(),
              color:S77.cyan,height:118,unit:hrvView.hasRmssd?'ms':'index'),
            if(hrvView.hasIndex&&!hrvView.hasRmssd) Text(
              'Firmware index • excluded from Recovery',
              style:TextStyle(color:S77.sub,fontSize:9)),
          ]))),
        ]),
        const SizedBox(height:6),Text('Charts contain only available device readings; missing history remains blank.',
          style:TextStyle(color:S77.dim,fontSize:10)),
        const SizedBox(height:17),S77Section('Contributing Factors',action:'Recovery details',onTap:()=>Navigator.pushNamed(context,'/recovery')),
        const SizedBox(height:6),S77Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          for(final c in rec.contributors)Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text(c.name,style:TextStyle(color:S77.ink,fontWeight:FontWeight.w700,fontSize:12))),
              Text(c.score==null?'Unavailable':'${c.score} / 100',style:TextStyle(color:c.score==null?S77.dim:S77.green,fontSize:11))]),
            const SizedBox(height:4),ClipRRect(borderRadius:BorderRadius.circular(7),child:LinearProgressIndicator(
              value:c.score==null?0.0:c.score!/100,minHeight:6,backgroundColor:S77.edge,color:c.score==null?S77.edge:S77.green)),
            const SizedBox(height:3),Text(c.detail,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:S77.dim,fontSize:10)),
          ]))
        ])),
        const SizedBox(height:14),S77Section('Energy & workload'),
        const SizedBox(height:6),S77Surface(accent:S77.cyan,child:Row(children:[
          Icon(Icons.battery_charging_full,color:S77.cyan,size:27),
          const SizedBox(width:10),Expanded(child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Salus Energy',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800)),
              Text('Experimental estimate · sleep & heart trends',
                style:TextStyle(color:S77.sub,fontSize:10)),
              Text(energy.quality,style:TextStyle(color:S77.dim,fontSize:10)),
          ])),Text(energy.score==null?'—':'${energy.score} / 100',
            style:TextStyle(color:S77.cyan,fontSize:18,fontWeight:FontWeight.w900)),
        ])),
        const SizedBox(height:14),S77Section('More Health Data',action:'All trends',onTap:()=>Navigator.pushNamed(context,'/trends')),
        const SizedBox(height:6),S77Surface(accent:S77.purple,onTap:()=>Navigator.pushNamed(context,'/health-intelligence'),child:Row(children:[
          Icon(Icons.device_thermostat,color:S77.purple,size:30),const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Skin temperature & intelligence',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:14)),
            const SizedBox(height:5),Text('View source-verified records; no temperature is assumed.',style:TextStyle(color:S77.sub,fontSize:11))])),
          Icon(Icons.chevron_right,color:S77.cyan)
        ])),
        const SizedBox(height:9),S77Surface(accent:S77.blue,onTap:()=>Navigator.pushNamed(context,'/sources'),child:Row(children:[
          Icon(Icons.devices,color:S77.blue,size:25),const SizedBox(width:10),Expanded(child:Text('Devices & sources',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w700))),
          Icon(Icons.chevron_right,color:S77.cyan)])),
      ])));
  }
}
