import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../services/direct_metric_service.dart';
import '../services/metric_history_service.dart';
import '../services/source_name_service.dart';
import '../state/app_state.dart';
import '../state/health_sync_provider.dart';
import '../widgets/salus_premium_ui.dart';

/// Shows only Health Connect history, divided by the actual originating app.
class MetricDetailScreen extends ConsumerStatefulWidget {
  final String metric;
  const MetricDetailScreen({super.key, required this.metric});
  @override ConsumerState<MetricDetailScreen> createState() => _MetricDetailScreenState();
}
class _MetricDetailScreenState extends ConsumerState<MetricDetailScreen> {
  late Future<MetricHistoryResult> _future;
  String _range = '7 days';
  String? _selectedSource;
  @override void initState() { super.initState(); _future = _load(); }
  Future<MetricHistoryResult> _load() => const MetricHistoryService().load(widget.metric,
    healthConnectAuthorized: ref.read(appStateProvider).health.authorized);
  Future<void> _refresh() async {
    await ref.read(healthSyncProvider.notifier).sync();
    if(mounted) setState(() => _future = _load());
  }
  @override Widget build(BuildContext context) {
    final app=ref.watch(appStateProvider);
    final configured=app.metricSources[widget.metric];
    final unit=MetricHistoryService.unitFor(widget.metric);
    return Scaffold(backgroundColor:AppTheme.surface,
      appBar:AppBar(title:Text(MetricHistoryService.labelFor(widget.metric)),actions:[
        IconButton(tooltip:'Refresh Health Connect',icon:const Icon(Icons.refresh),onPressed:_refresh),
      ]),
      body:FutureBuilder<MetricHistoryResult>(future:_future,builder:(context,snapshot){
        final all=snapshot.data?.readings ?? const <DirectMetricSample>[];
        final sources=<String,String>{};
        for(final item in all) {sources[item.sourceId]=item.deviceName;}
        final preferred=configured != null && configured != 'Auto' && !configured.startsWith('ble:')
          ? sources.keys.where((x)=>SourceNameService.sameProvider(x,configured)).firstOrNull : null;
        final selected=_selectedSource ?? preferred ??
          (configured != null && configured != 'Auto' ? configured : (all.isEmpty ? null:all.last.sourceId));
        final days=_range=='24 hours'?1:_range=='7 days'?7:30;
        final cutoff=DateTime.now().subtract(Duration(days:days));
        final filtered=all.where((x)=>x.sourceId==selected && !x.capturedAt.isBefore(cutoff)).toList();
        final latest=filtered.isEmpty?null:filtered.last;
        final mean=filtered.isEmpty?null:filtered.map((x)=>x.value).reduce((a,b)=>a+b)/filtered.length;
        final low=filtered.isEmpty?null:filtered.map((x)=>x.value).reduce(math.min);
        final high=filtered.isEmpty?null:filtered.map((x)=>x.value).reduce(math.max);
        String value(double x)=>x==x.roundToDouble()?x.toStringAsFixed(0):x.toStringAsFixed(1);
        return ListView(padding:const EdgeInsets.all(18),children:[
          Text(MetricHistoryService.labelFor(widget.metric),
            style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:AppTheme.textPrimary)),
          const SizedBox(height:8),
          const Text('Health Connect measurements only. The originating app is retained for every record.',
            style:TextStyle(color:AppTheme.textSecondary)),
          if(snapshot.data?.warning!=null) Padding(padding:const EdgeInsets.symmetric(vertical:12),
            child:Text(snapshot.data!.warning!,style:const TextStyle(color:AppTheme.amber))),
          if(widget.metric=='HRV') const Padding(padding:EdgeInsets.symmetric(vertical:12),
            child:Text('HRV is RMSSD in milliseconds. If no records appear, check Health Connect read permissions and whether another app supplies HRV.',
              style:TextStyle(color:AppTheme.textSecondary))),
          if(sources.isNotEmpty) Padding(padding:const EdgeInsets.only(top:16),
            child:DropdownButtonFormField<String>(
              initialValue:sources.containsKey(selected)?selected:null,
              isExpanded:true,decoration:const InputDecoration(labelText:'Recorded data origin'),
              items:[for(final x in sources.entries) DropdownMenuItem(value:x.key,
                child:Text(x.value,overflow:TextOverflow.ellipsis))],
              onChanged:(x)=>setState(()=>_selectedSource=x))),
          const SizedBox(height:20),
          Wrap(spacing:8,children:[for(final range in const ['24 hours','7 days','30 days'])
            ChoiceChip(label:Text(range),selected:_range==range,
              onSelected:(_)=>setState(()=>_range=range))]),
          const SizedBox(height:24),
          if(snapshot.connectionState==ConnectionState.waiting)
            const Center(child:CircularProgressIndicator())
          else if(snapshot.hasError)
            const Text('History query failed.',style:TextStyle(color:AppTheme.textSecondary))
          else if(latest==null)
            const Padding(padding:EdgeInsets.symmetric(vertical:52),child:Text(
              'No Health Connect measurements available for this source and period.',
              textAlign:TextAlign.center,style:TextStyle(color:AppTheme.textSecondary)))
          else ...[
            Text('${value(latest.value)} $unit',style:const TextStyle(
              color:AppTheme.textPrimary,fontSize:37,fontWeight:FontWeight.w800)),
            Text('From ${latest.deviceName} · ${latest.capturedAt.toLocal()}',
              style:const TextStyle(color:AppTheme.textSecondary,fontSize:12)),
            const SizedBox(height:18),
            PremiumLineChart(values:filtered.map((x)=>x.value).toList(),height:220,
              color:AppTheme.cyan,unit:unit),
            const SizedBox(height:15),
            Text('${filtered.length} recorded readings · average ${value(mean!)} $unit · '
              'minimum ${value(low!)} $unit · maximum ${value(high!)} $unit',
              style:const TextStyle(color:AppTheme.textSecondary)),
            const SizedBox(height:20),
            const Text('Recorded measurements',style:TextStyle(
              color:AppTheme.textPrimary,fontWeight:FontWeight.w800,fontSize:18)),
            for(final x in filtered.reversed.take(60)) ListTile(
              title:Text('${value(x.value)} $unit'),
              subtitle:Text('${x.capturedAt.toLocal()}'),
              trailing:SizedBox(width:115,child:Text(x.deviceName,
                textAlign:TextAlign.end,maxLines:2,overflow:TextOverflow.ellipsis)),
            ),
          ],
        ]);
      }),
    );
  }
}
