/// Timestamped provider-owned record value object kept for saved Health Connect
/// imports and chart models. This file contains no transport or hardware code.
class DirectMetricSample {
  final String sourceId,deviceId,deviceName,metric,unit;
  final double value;
  final DateTime capturedAt;
  const DirectMetricSample({required this.sourceId,required this.deviceId,
    required this.deviceName,required this.metric,required this.value,
    required this.unit,required this.capturedAt});
  Map<String,dynamic> toJson()=>{
    'sourceId':sourceId,'deviceId':deviceId,'deviceName':deviceName,
    'metric':metric,'value':value,'unit':unit,
    'capturedAt':capturedAt.toIso8601String(),
  };
  factory DirectMetricSample.fromJson(Map<String,dynamic> j)=>DirectMetricSample(
    sourceId:j['sourceId']?.toString()??'',deviceId:j['deviceId']?.toString()??'',
    deviceName:j['deviceName']?.toString()??'Health Connect provider',
    metric:j['metric']?.toString()??'',
    value:(j['value'] as num?)?.toDouble()??0,
    unit:j['unit']?.toString()??'',
    capturedAt:DateTime.tryParse(j['capturedAt']?.toString()??'')??DateTime.now());
}
