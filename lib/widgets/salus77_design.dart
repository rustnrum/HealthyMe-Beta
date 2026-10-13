// Shared visual system for the actual Salus Build 77 dashboard layouts.
// Rendered values are passed from existing Salus providers, never mocked.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'salus_premium_visuals.dart';

class S77 {
  static Color get bg => SalusV.background;
  static Color get panel => SalusV.panel;
  static Color get ink => SalusV.ink;
  static Color get sub => SalusV.secondary;
  static Color get dim => SalusV.muted;
  static Color get edge => SalusV.border;
  static Color get cyan => SalusV.cyan;
  static Color get green => SalusV.green;
  static Color get blue => SalusV.blue;
  static Color get orange => SalusV.orange;
  static Color get purple => SalusV.purple;
  static Color get red => SalusV.red;
  static Color get surface => SalusV.lightMode ? const Color(0xffe5f0f7) : const Color(0xff0a1724);
  static const double gutter = 17;
}

/// A full-screen scene behind the entire Home page, including its cards.
/// Never blocks scrolling, taps, or existing module selection.
class SalusMountainBackdrop extends StatelessWidget {
  const SalusMountainBackdrop({super.key,required this.child,required this.light});
  final Widget child;
  final bool light;
  @override Widget build(BuildContext context)=>Stack(fit:StackFit.expand,children:[
    ColoredBox(color:S77.bg),
    Positioned.fill(child:Opacity(opacity:light?0.34:0.83,
      child:Image.asset('assets/premium/salus_mountain_79.webp',
        fit:BoxFit.cover,alignment:Alignment.topCenter))),
    Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
      gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
        stops:const [0.0,0.38,1.0],
        colors:light?[const Color(0x9cf4f8fc),const Color(0xcaf4f8fc),const Color(0xf1f4f8fc)]:
          [const Color(0x67030d18),const Color(0xa5050d18),const Color(0xe8040b13)])))),
    child,
  ]);
}

class S77Surface extends StatelessWidget {
  const S77Surface({super.key,required this.child,this.accent,this.onTap,this.padding=const EdgeInsets.all(15),this.radius=19});
  final Widget child;
  final Color? accent;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  @override Widget build(BuildContext context) {
    final g=accent??S77.cyan;
    return DecoratedBox(decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(radius),
      border:Border.all(color:accent==null?S77.edge:g.withValues(alpha:SalusV.lightMode?0.67:0.47),width:SalusV.lightMode?1.25:0.9),
      gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[
        g.withValues(alpha:SalusV.lightMode?0.20:0.20),S77.panel,S77.surface]),
      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:SalusV.lightMode?0.06:0.18),blurRadius:13,offset:const Offset(0,5))]),
      child:Material(color:Colors.transparent,child:InkWell(
        borderRadius:BorderRadius.circular(radius),onTap:onTap,
        child:Padding(padding:padding,child:child))));
  }
}

class S77Title extends StatelessWidget {
  const S77Title(this.title,{super.key,this.subtitle,this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override Widget build(BuildContext context)=>Row(children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(subtitle!=null)Text(subtitle!,style:TextStyle(color:S77.cyan,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:2)),
      if(subtitle!=null)const SizedBox(height:5),
      Text(title,style:TextStyle(color:S77.ink,fontSize:27,fontWeight:FontWeight.w900,letterSpacing:-0.7)),
    ])),if(trailing!=null)trailing!,
  ]);
}
class S77Section extends StatelessWidget {
  const S77Section(this.title,{super.key,this.action,this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override Widget build(BuildContext context)=>Row(children:[
    Expanded(child:Text(title,style:TextStyle(color:S77.ink,fontSize:17,fontWeight:FontWeight.w800))),
    if(action!=null)TextButton(onPressed:onTap,child:Text(action!,style:TextStyle(color:S77.cyan,fontSize:12,fontWeight:FontWeight.w700)))]);
}
class S77Tabs extends StatelessWidget {
  const S77Tabs({super.key,required this.items,required this.selected,required this.onSelected});
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelected;
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:S77.surface,border:Border.all(color:S77.edge),borderRadius:BorderRadius.circular(15)),
    child:Row(children:[for(var i=0;i<items.length;i++)Expanded(child:InkWell(
      borderRadius:BorderRadius.circular(11),onTap:()=>onSelected(i),child:AnimatedContainer(
        duration:const Duration(milliseconds:180),padding:const EdgeInsets.symmetric(vertical:10),
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(11),
          gradient:i==selected?LinearGradient(colors:[S77.cyan,S77.blue]):null),
        alignment:Alignment.center,child:Text(items[i],textAlign:TextAlign.center,
          style:TextStyle(color:i==selected?const Color(0xff001523):S77.sub,fontWeight:FontWeight.w800,fontSize:11)))))])
  );
}

class S77Metric extends StatelessWidget {
  const S77Metric({super.key,required this.label,required this.value,required this.icon,required this.color,
    this.caption,this.progress,this.onTap,this.height=116});
  final String label,value;
  final IconData icon;
  final Color color;
  final String? caption;
  final double? progress;
  final VoidCallback? onTap;
  final double height;
  @override Widget build(BuildContext context)=>S77Surface(accent:color,onTap:onTap,padding:const EdgeInsets.all(12),
    child:SizedBox(height:height,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:color.withValues(alpha:.18),borderRadius:BorderRadius.circular(9)),child:Icon(icon,color:color,size:19)),
        const SizedBox(width:7),Expanded(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:S77.sub,fontSize:12,fontWeight:FontWeight.w700)))]),
      const Spacer(),Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:S77.ink,fontSize:24,fontWeight:FontWeight.w900)),
      if(caption!=null)Text(caption!,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:S77.dim,fontSize:10)),
      const SizedBox(height:5),ClipRRect(borderRadius:BorderRadius.circular(6),child:LinearProgressIndicator(
        minHeight:4,value:progress?.clamp(0.0,1.0).toDouble() ?? 0.0,color:color,
        backgroundColor:S77.edge.withValues(alpha:.75))),
    ])));
}

/// Compact circular metric tile; unmeasured targets stay hollow, never 0%.
class S77RingTile extends StatelessWidget {
  const S77RingTile({super.key,required this.label,required this.value,
    required this.icon,required this.color,this.detail,this.fraction,this.onTap});
  final String label,value;
  final IconData icon;
  final Color color;
  final String? detail;
  final double? fraction;
  final VoidCallback? onTap;
  @override Widget build(BuildContext context) {
    final progress=fraction==null?null:fraction!.clamp(0.0,1.0).toDouble();
    final ringDiameter=MediaQuery.sizeOf(context).width<392?74.0:82.0;
    return S77Surface(accent:color,onTap:onTap,padding:const EdgeInsets.all(11),child:SizedBox(height:132,
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Icon(icon,color:color,size:18),const SizedBox(width:6),
          Expanded(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:12)))]),
        const Spacer(),Row(children:[
          S77Arc(size:ringDiameter,center:progress==null?'—':'${(progress*100).round()}%',
            caption:progress==null?'No goal':'of goal',
            segments:progress==null?const []:[
              (value:progress*100,color:color),
              (value:(1-progress)*100,color:S77.edge)]),
          const SizedBox(width:6),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(value,maxLines:1,overflow:TextOverflow.ellipsis,
              style:TextStyle(color:S77.ink,fontWeight:FontWeight.w900,fontSize:16)),
            if(detail!=null)Text(detail!,maxLines:2,overflow:TextOverflow.ellipsis,
              style:TextStyle(color:S77.sub,fontSize:10,height:1.35))])),
        ]),
      ])));
  }
}

class S77Arc extends StatelessWidget {
  const S77Arc({super.key,required this.center,required this.caption,required this.segments,this.size=170});
  final String center,caption;
  /// Values must be measured and positive. Null/empty paints track only.
  final List<({double value,Color color})> segments;
  final double size;
  @override Widget build(BuildContext context)=>SizedBox(width:size,height:size,child:Stack(alignment:Alignment.center,children:[
    CustomPaint(size:Size.square(size),painter:_S77ArcPainter(segments,S77.edge.withValues(alpha:.65))),
    Column(mainAxisSize:MainAxisSize.min,children:[
      Text(center,style:TextStyle(fontSize:size>140?25:size>100?21:16,fontWeight:FontWeight.w900,color:S77.ink)),
      const SizedBox(height:2),Text(caption,textAlign:TextAlign.center,style:TextStyle(fontSize:size>100?10:9,color:S77.sub))])
  ]));
}
class _S77ArcPainter extends CustomPainter {
  _S77ArcPainter(this.data,this.track);
  final List<({double value,Color color})> data;
  final Color track;
  @override void paint(Canvas canvas,Size size){
    final stroke=size.width*.105;final rect=Rect.fromLTWH(stroke/2+2,stroke/2+2,size.width-stroke-4,size.height-stroke-4);
    final paint=Paint()..style=PaintingStyle.stroke..strokeWidth=stroke..strokeCap=StrokeCap.round;
    canvas.drawArc(rect,0,math.pi*2,false,paint..color=track);
    final eligible=data.where((x)=>x.value.isFinite&&x.value>0).toList();
    if(eligible.isEmpty)return;
    final total=eligible.fold<double>(0,(sum,e)=>sum+e.value);if(total<=0)return;
    final gap=math.min(.048,(math.pi*2)/eligible.length*.13);
    var theta=-math.pi/2;
    for(final part in eligible){final sweep=math.pi*2*part.value/total;
      if(sweep>gap)canvas.drawArc(rect,theta+gap/2,sweep-gap,false,paint..color=part.color);
      theta+=sweep;}
  }
  @override bool shouldRepaint(covariant _S77ArcPainter o)=>o.data!=data||o.track!=track;
}

/// Recorded resting heart rate only. Each point is an observed daily value;
/// the y-axis is an expanded bpm range rather than exaggerated auto-zoom.
class S77RestingHeartChart extends StatelessWidget {
  const S77RestingHeartChart({super.key,required this.values,this.height=120,this.color=const Color(0xffff607a)});
  final List<double?> values;
  final double height;
  final Color color;
  @override Widget build(BuildContext context) {
    final usable=values.whereType<double>().where((v)=>v.isFinite&&v>=30&&v<=180).toList();
    if(usable.length<2)return SizedBox(height:height,child:Center(child:Text(
      'More recorded days needed for a trend',style:TextStyle(color:S77.sub,fontSize:11))));
    return SizedBox(height:height,child:CustomPaint(painter:_S77RestingHeartPainter(usable,color,S77.edge,S77.sub)));
  }
}
class _S77RestingHeartPainter extends CustomPainter {
  _S77RestingHeartPainter(this.values,this.accent,this.grid,this.ink);
  final List<double> values;
  final Color accent,grid,ink;
  @override void paint(Canvas c,Size s){
    if(values.length<2||s.width<=52||s.height<=28)return;
    final lowRaw=values.reduce(math.min),highRaw=values.reduce(math.max);
    var low=((lowRaw-5)/5).floorToDouble()*5;
    var high=((highRaw+5)/5).ceilToDouble()*5;
    if(high-low<15){final center=(high+low)/2;low=center-7.5;high=center+7.5;}
    final left=31.0,right=s.width-7.0,top=9.0,bottom=s.height-17.0;
    final width=right-left,height=bottom-top;
    if(width<=0||height<=0)return;
    for(var i=0;i<=3;i++){
      final y=top+height*i/3;
      c.drawLine(Offset(left,y),Offset(right,y),Paint()..color=grid.withValues(alpha:.55)..strokeWidth=.8);
      final bpm=(high-(high-low)*i/3).round().toString();
      final tp=TextPainter(text:TextSpan(text:bpm,style:TextStyle(color:ink,fontSize:9)),textDirection:TextDirection.ltr)..layout();
      tp.paint(c,Offset(1,y-tp.height/2));
    }
    final points=<Offset>[];
    for(var i=0;i<values.length;i++){
      final x=left+width*i/(values.length-1);
      final y=bottom-(values[i]-low)/(high-low)*height;
      points.add(Offset(x,y));
    }
    final path=Path()..moveTo(points.first.dx,points.first.dy);
    for(final point in points.skip(1)){path.lineTo(point.dx,point.dy);}
    c.drawPath(path,Paint()..color=accent..style=PaintingStyle.stroke..strokeWidth=2.4..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round);
    for(final point in points){c.drawCircle(point,3.2,Paint()..color=accent);}
  }
  @override bool shouldRepaint(covariant _S77RestingHeartPainter old)=>
    old.values!=values||old.accent!=accent||old.grid!=grid||old.ink!=ink;
}

class S77Progress extends StatelessWidget {
  const S77Progress({super.key,required this.label,required this.color,this.value,this.target,this.unit='g'});
  final String label,unit;
  final Color color;
  final double? value,target;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Column(children:[
    Row(children:[Container(width:8,height:8,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),const SizedBox(width:8),
      Expanded(child:Text(label,style:TextStyle(color:S77.ink,fontSize:12,fontWeight:FontWeight.w700))),
      Text(value==null?'Not logged':target==null?'${value!.round()} $unit':'${value!.round()} / ${target!.round()} $unit',
        style:TextStyle(color:S77.sub,fontSize:11))]),
    const SizedBox(height:7),ClipRRect(borderRadius:BorderRadius.circular(9),child:LinearProgressIndicator(
      value:value==null||target==null||target!<=0?0.0:(value!/target!).clamp(0.0,1.0).toDouble(),minHeight:9,
      backgroundColor:S77.edge.withValues(alpha:.7),color:color))]));
}

class S77Hero extends StatelessWidget {
  const S77Hero({super.key,required this.asset,required this.title,this.caption,this.onTap,this.height=164});
  final String asset,title;
  final String? caption;
  final VoidCallback? onTap;
  final double height;
  @override Widget build(BuildContext context)=>ClipRRect(borderRadius:BorderRadius.circular(20),child:Material(color:S77.panel,child:InkWell(onTap:onTap,
    child:SizedBox(height:height,child:Stack(fit:StackFit.expand,children:[
      Image.asset(asset,fit:BoxFit.cover,alignment:Alignment.center),
      DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.centerLeft,end:Alignment.centerRight,
        colors:[const Color(0xf0081421),const Color(0xa5081421),const Color(0x10081421)]))),
      Padding(padding:const EdgeInsets.all(19),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[
        SizedBox(width:235,child:Text(title,style:const TextStyle(fontSize:23,color:Colors.white,fontWeight:FontWeight.w900,height:1.15))),
        if(caption!=null)...[const SizedBox(height:8),SizedBox(width:215,child:Text(caption!,style:const TextStyle(fontSize:11,color:Color(0xffd8eaf0),height:1.4)))],
        const SizedBox(height:12),Icon(Icons.arrow_circle_right_outlined,color:S77.cyan,size:25)
      ])),
    ])))));
}

/// Paired bar chart: exactly known values are drawn; unknowns never become filled bars.
class S77PairedChart extends StatelessWidget {
  const S77PairedChart({super.key,required this.left,required this.right,required this.labels,
    this.firstColor=const Color(0xff4b9df9),this.secondColor=const Color(0xff12c58e)});
  final List<double?> left,right;
  final List<String> labels;
  final Color firstColor,secondColor;
  @override Widget build(BuildContext context)=>SizedBox(height:184,
    child:CustomPaint(painter:_S77PairedPainter(left,right,labels,firstColor,secondColor,S77.sub,S77.edge)));
}
class _S77PairedPainter extends CustomPainter {
  _S77PairedPainter(this.left,this.right,this.labels,this.c1,this.c2,this.ink,this.line);
  final List<double?> left,right;
  final List<String> labels;
  final Color c1,c2,ink,line;
  @override void paint(Canvas c,Size s){
    final maxVal=[...left,...right].whereType<double>().fold<double>(0,(a,b)=>math.max(a,b));
    final ceiling=math.max(1.0,maxVal*1.12);
    const top=13.0,bottom=156.0;final height=bottom-top;
    final plotLeft=35.0,plotWidth=math.max(1.0,s.width-41);
    for(var i=0;i<4;i++){
      final y=top+(height*i/3);c.drawLine(Offset(plotLeft,y),Offset(s.width-5,y),Paint()..color=line..strokeWidth=.65);
      final tp=TextPainter(text:TextSpan(text:'${(ceiling*(3-i)/3).round()}',style:TextStyle(color:ink,fontSize:9)),textDirection:TextDirection.ltr)..layout();tp.paint(c,Offset(0,y-6));
    }
    final n=labels.length;if(n==0)return;final cell=plotWidth/n;
    for(var i=0;i<n;i++){
      for(var j=0;j<2;j++){
        final v=j==0?(i<left.length?left[i]:null):(i<right.length?right[i]:null);
        if(v==null||v<0)continue;
        final h=math.max(v>0?2.5:0.0,math.min(height,v/ceiling*height));
        final width=math.max(2.0,math.min(13.0,cell*.26));
        final x=plotLeft+cell*i+cell*.24+j*(width+2);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,bottom-h,width,h),const Radius.circular(3)),Paint()..color=(j==0?c1:c2));
      }
      final tp=TextPainter(text:TextSpan(text:labels[i],style:TextStyle(color:ink,fontSize:9)),textDirection:TextDirection.ltr)..layout();
      tp.paint(c,Offset(plotLeft+cell*i+(cell-tp.width)/2,bottom+8));
    }
  }
  @override bool shouldRepaint(covariant _S77PairedPainter o)=>true;
}

class S77Legend extends StatelessWidget {
  const S77Legend({super.key,required this.items});
  final List<({String label,Color color})> items;
  @override Widget build(BuildContext context)=>Wrap(spacing:15,runSpacing:6,children:[for(final x in items)
    Row(mainAxisSize:MainAxisSize.min,children:[Container(width:9,height:9,decoration:BoxDecoration(color:x.color,borderRadius:BorderRadius.circular(3))),
      const SizedBox(width:5),Text(x.label,style:TextStyle(fontSize:10,color:S77.sub))])]);
}
