import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/recovery_service.dart';
import '../../state/app_state.dart';
import '../../state/workout_state.dart';
import '../../widgets/salus_premium_visuals.dart';

/// Health overview: source-aware summaries, no invented recovery contributors.
/// Dedicated Health Intelligence retains device-specific details and temperature.
class SalusPremiumHealth extends ConsumerWidget {
  const SalusPremiumHealth({super.key});
  String _source(Map<String,String> labels,String key) {
    final s=labels[key];return s==null||s.isEmpty?'Source not selected':s;
  }
  @override Widget build(BuildContext context,WidgetRef ref) {
    final app=ref.watch(appStateProvider),h=app.health;
    final workouts=ref.watch(workoutStateProvider);
    final rec=RecoveryService.build(app,completedWorkouts:workouts.history);
    final rhr=h.restingHeartRate;
    final hrv=h.hrvMs;
    final spo2=h.bloodOxygenPercent;
    final sleep=h.sleepMinutes;
    final knownStages=h.sleepDeepMinutes+h.sleepRemMinutes+h.sleepLightMinutes;
    final stageData=knownStages>0;
    return ColoredBox(color:SalusV.background,child:ListView(
      padding:const EdgeInsets.fromLTRB(17,19,17,46),children:[
        SalusHeading('Health',caption:'YOUR WHOLE HEALTH IN FOCUS',
          trailing:IconButton(tooltip:'Health Intelligence',onPressed:()=>Navigator.pushNamed(context,'/health-intelligence'),
            icon:const Icon(Icons.insights,color:SalusV.cyan))),
        const SizedBox(height:19),
        SalusGlass(glow:SalusV.green,onTap:()=>Navigator.pushNamed(context,'/recovery'),
          child:Row(children:[
            SalusGauge(value:rec.score?.toDouble(),total:100,
              center:rec.score?.toString()??'—',color:SalusV.green,size:124,
              caption:rec.score==null?'Unavailable':rec.label),
            const SizedBox(width:18),Expanded(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('Recovery',style:TextStyle(color:SalusV.ink,fontSize:18,fontWeight:FontWeight.w800)),
                const SizedBox(height:5),Text(rec.summary,maxLines:4,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:SalusV.secondary,fontSize:12,height:1.45)),
                const SizedBox(height:8),Text('${rec.confidence}% data coverage',
                  style:const TextStyle(color:SalusV.green,fontSize:11,fontWeight:FontWeight.w700)),
              ])),const Icon(Icons.chevron_right,color:SalusV.cyan),
          ])),
        const SizedBox(height:12),SalusGlass(glow:SalusV.blue,
          onTap:()=>Navigator.pushNamed(context,'/sleep-detail'),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Row(children:[Icon(Icons.bedtime_rounded,color:SalusV.purple),
              SizedBox(width:9),Text('Sleep',style:TextStyle(color:SalusV.ink,fontSize:16,fontWeight:FontWeight.w800))]),
            const SizedBox(height:8),Text(sleep>0?'${sleep~/60}h ${sleep%60}m':'No sleep recorded',
              style:const TextStyle(color:SalusV.ink,fontSize:26,fontWeight:FontWeight.w900)),
            const SizedBox(height:10),
            if(stageData)...[
              ClipRRect(borderRadius:BorderRadius.circular(7),child:Row(children:[
                if(h.sleepDeepMinutes>0)Expanded(flex:h.sleepDeepMinutes,child:Container(height:12,color:SalusV.purple)),
                if(h.sleepLightMinutes>0)Expanded(flex:h.sleepLightMinutes,child:Container(height:12,color:SalusV.blue)),
                if(h.sleepRemMinutes>0)Expanded(flex:h.sleepRemMinutes,child:Container(height:12,color:SalusV.cyan)),
              ])),const SizedBox(height:8),
              Text('Deep ${h.sleepDeepMinutes}m  ·  Light ${h.sleepLightMinutes}m  ·  REM ${h.sleepRemMinutes}m',
                style:const TextStyle(color:SalusV.secondary,fontSize:11)),
            ]else const Text('Sleep-stage breakdown unavailable from your selected source.',
              style:TextStyle(color:SalusV.secondary,fontSize:11)),
            const SizedBox(height:7),Text(_source(h.resolvedSources,'Sleep'),
              style:const TextStyle(color:SalusV.muted,fontSize:10)),
          ])),
        const SizedBox(height:18),const SalusSection('Vitals & trends'),
        const SizedBox(height:9),Row(children:[
          Expanded(child:SalusMetricTile(label:'Resting HR',icon:Icons.favorite_rounded,
            value:rhr==null?'—':'${rhr.round()} bpm',color:SalusV.red,
            detail:_source(h.resolvedSources,'Resting heart rate'),
            chart:h.restingHeartRate30.map((v)=>v.toDouble()).toList(),
            onTap:()=>Navigator.pushNamed(context,'/metric-resting-heart-rate'))),
          const SizedBox(width:10),
          Expanded(child:SalusMetricTile(label:'HRV',icon:Icons.monitor_heart_rounded,
            value:hrv==null?'—':'${hrv.round()} ms',color:SalusV.purple,
            detail:_source(h.resolvedSources,'HRV'),
            chart:h.hrv30.map((v)=>v.toDouble()).toList(),
            onTap:()=>Navigator.pushNamed(context,'/metric-hrv'))),
        ]),
        const SizedBox(height:10),Row(children:[
          Expanded(child:SalusMetricTile(label:'SpO₂',icon:Icons.water_drop_rounded,
            value:spo2==null?'—':'${spo2.round()}%',color:SalusV.blue,
            detail:_source(h.resolvedSources,'SpO2'),
            onTap:()=>Navigator.pushNamed(context,'/spo2-history'))),
          const SizedBox(width:10),
          Expanded(child:SalusMetricTile(label:'Respiration',icon:Icons.air_rounded,
            value:h.respiratoryRate==null?'—':'${h.respiratoryRate!.toStringAsFixed(1)}/min',
            color:SalusV.orange,detail:_source(h.resolvedSources,'Respiratory rate'),
            chart:h.respiratoryRate30.map((v)=>v.toDouble()).toList(),
            onTap:()=>Navigator.pushNamed(context,'/metric-respiratory-rate'))),
        ]),
        const SizedBox(height:15),
        SalusGlass(glow:SalusV.purple,
          onTap:()=>Navigator.pushNamed(context,'/health-intelligence'),
          child:const Row(children:[Icon(Icons.thermostat_rounded,color:SalusV.purple,size:28),
            SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              children:[Text('Skin & body temperature',
                style:TextStyle(color:SalusV.ink,fontWeight:FontWeight.w800)),
                SizedBox(height:4),Text('View verified readings, sources and baseline trends',
                  style:TextStyle(color:SalusV.secondary,fontSize:11))])),
            Icon(Icons.chevron_right,color:SalusV.cyan)])),
        const SizedBox(height:13),
        SalusGlass(onTap:()=>Navigator.pushNamed(context,'/watch-device'),
          child:const Row(children:[Icon(Icons.battery_charging_full_rounded,color:SalusV.cyan,size:26),
            SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              children:[Text('Garmin Body Battery',style:TextStyle(color:SalusV.ink,fontWeight:FontWeight.w800)),
                SizedBox(height:3),Text('Read source-provided values — never an estimated replacement',
                  style:TextStyle(color:SalusV.secondary,fontSize:11))])),
            Icon(Icons.chevron_right,color:SalusV.cyan)])),
        const SizedBox(height:22),const SalusSection('Your health records'),
        const SizedBox(height:8),Row(children:[
          Expanded(child:SalusGlass(onTap:()=>Navigator.pushNamed(context,'/labs'),
            child:const Column(children:[Icon(Icons.science,color:SalusV.orange),SizedBox(height:7),
              Text('Bloodwork',style:TextStyle(color:SalusV.ink,fontWeight:FontWeight.w700))]))),
          const SizedBox(width:10),Expanded(child:SalusGlass(onTap:()=>Navigator.pushNamed(context,'/backup'),
            child:const Column(children:[Icon(Icons.backup_outlined,color:SalusV.green),SizedBox(height:7),
              Text('Backups',style:TextStyle(color:SalusV.ink,fontWeight:FontWeight.w700))]))),
        ]),
        const SizedBox(height:16),const Text('Numbers are taken from connected or entered records. Missing data is never replaced with sample readings.',
          style:TextStyle(color:SalusV.muted,fontSize:11,height:1.45)),
      ]));
  }
}
