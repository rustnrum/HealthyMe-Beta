import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Build 75 premium visual language. These are presentation-only widgets;
/// no fake numbers are injected, and null is always treated as unavailable.
class SalusV {
  static const background = Color(0xff050d16);
  static const panel = Color(0xff0d1e2b);
  static const panelLow = Color(0xff081723);
  static const border = Color(0xff274554);
  static const ink = Color(0xfff4f9fc);
  static const secondary = Color(0xffabc0c9);
  static const muted = Color(0xff77919d);
  static const cyan = Color(0xff03d8f4);
  static const blue = Color(0xff4b9df9);
  static const green = Color(0xff12e3a2);
  static const orange = Color(0xffffa32a);
  static const red = Color(0xffff607a);
  static const purple = Color(0xffb785ff);
  static const yellow = Color(0xfffbd343);
  static const Color shadow = Color(0x4a000000);
}

class SalusGlass extends StatelessWidget {
  const SalusGlass({super.key, required this.child, this.onTap,
    this.padding = const EdgeInsets.all(16), this.glow, this.radius = 20});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? glow;
  final double radius;
  @override Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [glow?.withValues(alpha: 0.13) ?? const Color(0xff112937),
          SalusV.panel, SalusV.panelLow]),
      border: Border.all(color: glow?.withValues(alpha: .40) ?? SalusV.border, width: 1),
      boxShadow: const [BoxShadow(color: SalusV.shadow, blurRadius: 18, offset: Offset(0, 7))],
    ),
    child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(radius),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(radius),
        child: Padding(padding: padding, child: child))),
  );
}

class SalusSection extends StatelessWidget {
  const SalusSection(this.title, {super.key, this.trailing, this.onTap});
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  @override Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(color: SalusV.ink,
      fontWeight: FontWeight.w800, fontSize: 17))),
    if (trailing != null) TextButton(onPressed: onTap,
      child: Text(trailing!, style: const TextStyle(color: SalusV.cyan, fontSize: 12))),
  ]);
}

class SalusHeading extends StatelessWidget {
  const SalusHeading(this.title,{super.key,this.caption,this.trailing});
  final String title;
  final String? caption;
  final Widget? trailing;
  @override Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (caption != null) Text(caption!,style:const TextStyle(color:SalusV.secondary,
        fontSize:11,letterSpacing:2,fontWeight:FontWeight.w700)),
      if (caption != null) const SizedBox(height: 5),
      Text(title,style:const TextStyle(color: SalusV.ink,fontSize:27,fontWeight:FontWeight.w900,
        letterSpacing:-.6)),
    ])),
    if (trailing != null) trailing!,
  ]);
}

class SalusWeekStrip extends StatelessWidget {
  const SalusWeekStrip({super.key,this.day});
  final DateTime? day;
  @override Widget build(BuildContext context) {
    final now = day ?? DateTime.now();
    const names = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return Row(children: [for (int i = 6; i >= 0; i--)
      Expanded(child: Builder(builder: (context) {
        final d = now.subtract(Duration(days:i)); final selected=i==0;
        return Column(children: [
          Text(names[d.weekday-1],style: TextStyle(color:selected?SalusV.cyan:SalusV.secondary,
            fontSize:11,fontWeight:selected?FontWeight.w800:FontWeight.w500)),
          const SizedBox(height:8),
          Container(height:37,width:37,alignment:Alignment.center,
            decoration:BoxDecoration(shape:BoxShape.circle,
              color:selected?SalusV.cyan:SalusV.panel,
              border:Border.all(color:selected?SalusV.cyan:SalusV.border)),
            child: Text('${d.day}',style:TextStyle(color:selected?SalusV.background:SalusV.ink,
              fontWeight:selected?FontWeight.w900:FontWeight.w600))),
        ]);
      })),
    ]);
  }
}

class SalusPhotoHero extends StatelessWidget {
  const SalusPhotoHero({super.key,required this.asset,required this.title,
    this.subtitle,this.height=140,this.onTap,this.buttonText,this.imageAlignment=Alignment.center});
  final String asset,title;
  final String? subtitle,buttonText;
  final double height;
  final VoidCallback? onTap;
  final Alignment imageAlignment;
  @override Widget build(BuildContext context) => ClipRRect(
    borderRadius:BorderRadius.circular(20),
    child:Material(color:SalusV.panel,child:InkWell(onTap:onTap,child:SizedBox(height:height,
      child:Stack(fit:StackFit.expand,children:[
        Image.asset(asset,fit:BoxFit.cover,alignment:imageAlignment),
        const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(
          begin:Alignment.centerLeft,end:Alignment.centerRight,
          colors:[Color(0xee07131e),Color(0x98091623),Color(0x11060f19)]))),
        Padding(padding:const EdgeInsets.all(18),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,
          children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:20,
            fontWeight:FontWeight.w900,height:1.2)),
            if(subtitle!=null)...[const SizedBox(height:8),SizedBox(width:195,
              child:Text(subtitle!,style:const TextStyle(color:Color(0xffddebf0),fontSize:11)))],
            if(buttonText!=null)...[const SizedBox(height:11),Container(
              padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),
              decoration:BoxDecoration(color:SalusV.cyan,borderRadius:BorderRadius.circular(30)),
              child:Text(buttonText!,style:const TextStyle(color:SalusV.background,
                fontWeight:FontWeight.w800,fontSize:11)))],
          ])),
      ])))),
  );
}

/// A circular metric that does NOT imply completeness if goal is unknown.
class SalusGauge extends StatelessWidget {
  const SalusGauge({super.key,required this.value,required this.total,
    required this.center,required this.color,this.size=88,this.caption});
  final double? value,total;
  final String center;
  final Color color;
  final String? caption;
  final double size;
  @override Widget build(BuildContext context) => SizedBox(width:size,height:size,
    child:Stack(fit:StackFit.expand,children:[
      CustomPaint(painter:_ArcGauge(value,total,color)),
      Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(center,style:TextStyle(color:SalusV.ink,fontWeight:FontWeight.w900,
          fontSize:size>=100?25:18)),
        if(caption!=null)Text(caption!,textAlign:TextAlign.center,
          style:const TextStyle(color:SalusV.secondary,fontSize:9)),
      ])),
    ]));
}
class _ArcGauge extends CustomPainter {
  _ArcGauge(this.value,this.total,this.color);
  final double? value,total; final Color color;
  @override void paint(Canvas c,Size s) {
    final double width=math.max(7.0,s.width*0.095).toDouble();
    final Rect r=Rect.fromLTWH(width,width,s.width-2*width,s.height-2*width);
    final base=Paint()..color=SalusV.border..strokeWidth=width..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;
    c.drawArc(r,-math.pi/2,math.pi*2,false,base);
    if(value==null||total==null||total!<=0)return;
    final ratio=(value!/total!).clamp(0.0,1.0);
    final fg=Paint()..shader=SweepGradient(startAngle:-math.pi/2,endAngle:math.pi*3/2,
      colors:[color.withValues(alpha:.55),color]).createShader(r)
      ..strokeWidth=width..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;
    if(ratio>0)c.drawArc(r,-math.pi/2,2*math.pi*ratio,false,fg);
  }
  @override bool shouldRepaint(covariant _ArcGauge other)=>value!=other.value||total!=other.total||color!=other.color;
}

class SalusMacroRing extends StatelessWidget {
  const SalusMacroRing({super.key,required this.protein,required this.carbs,
    required this.fat,required this.kcal,required this.target,this.size=158});
  final double? protein,carbs,fat,kcal,target;
  final double size;
  @override Widget build(BuildContext context) => SizedBox(width:size,height:size,
    child:Stack(fit:StackFit.expand,children:[
      CustomPaint(painter:_MacroPainter(protein,carbs,fat)),
      Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(kcal==null?'—':'${kcal!.round()}',style:TextStyle(
          color:SalusV.ink,fontWeight:FontWeight.w900,fontSize:size/5.2)),
        const Text('kcal logged',style:TextStyle(color:SalusV.secondary,fontSize:10)),
        if(target!=null)Text('of ${target!.round()}',style:const TextStyle(color:SalusV.muted,fontSize:10)),
      ])),
    ]));
}
class _MacroPainter extends CustomPainter {
  _MacroPainter(this.protein,this.carbs,this.fat);
  final double? protein,carbs,fat;
  @override void paint(Canvas c,Size s) {
    final stroke=s.width*.16,pad=stroke/2+3,rect=Rect.fromLTWH(pad,pad,s.width-2*pad,s.height-2*pad);
    c.drawArc(rect,-math.pi/2,math.pi*2,false,Paint()..color=SalusV.border
      ..style=PaintingStyle.stroke..strokeWidth=stroke);
    if(protein==null||carbs==null||fat==null)return;
    final values=[protein!*4,carbs!*4,fat!*9];
    if(values.any((v)=>v<0||!v.isFinite))return;
    final sum=values.reduce((a,b)=>a+b);if(sum<=0)return;
    double start=-math.pi/2;
    const colors=[SalusV.blue,SalusV.green,SalusV.orange];
    for(var i=0;i<values.length;i++){
      final sweep=2*math.pi*values[i]/sum;
      if(sweep>.05)c.drawArc(rect,start+.02,sweep-.04,false,
        Paint()..style=PaintingStyle.stroke..strokeWidth=stroke
          ..strokeCap=StrokeCap.round..color=colors[i]);
      start+=sweep;
    }
  }
  @override bool shouldRepaint(covariant _MacroPainter other)=>protein!=other.protein||carbs!=other.carbs||fat!=other.fat;
}

class SalusMetricTile extends StatelessWidget {
  const SalusMetricTile({super.key,required this.label,required this.value,
    required this.color,required this.icon,this.detail='',this.progress,this.onTap,this.chart});
  final String label,value,detail;
  final Color color;
  final IconData icon;
  final double? progress;
  final VoidCallback? onTap;
  final List<double?>? chart;
  @override Widget build(BuildContext context)=>SalusGlass(glow:color,onTap:onTap,
    padding:const EdgeInsets.all(13),child:SizedBox(height:137,
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Icon(icon,color:color,size:23),const SizedBox(width:8),
          Expanded(child:Text(label,style:const TextStyle(color:SalusV.ink,
            fontSize:13,fontWeight:FontWeight.w700)))]),
        const Spacer(),
        Row(children:[
          Expanded(child:Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(
            color:SalusV.ink,fontSize:23,fontWeight:FontWeight.w900))),
          SizedBox(width:39,height:39,child:CustomPaint(
            painter:_ArcGauge(progress,progress==null?null:1,color))),
        ]),
        const SizedBox(height:4),
        Text(detail,maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(color:SalusV.secondary,fontSize:10)),
        if(progress!=null)...[const SizedBox(height:9),ClipRRect(
          borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(
            value:progress!.clamp(0.0,1.0),minHeight:5,
            color:color,backgroundColor:SalusV.border))],
        if(chart!=null)...[const SizedBox(height:7),SalusSparkline(values:chart!,color:color,height:22)],
      ])));
}

class SalusSparkline extends StatelessWidget {
  const SalusSparkline({super.key,required this.values,required this.color,this.height=55});
  final List<double?> values;final Color color;final double height;
  @override Widget build(BuildContext context){
    if(values.whereType<double>().length<2)return const SizedBox.shrink();
    return SizedBox(height:height,width:double.infinity,
      child:CustomPaint(painter:_Spark(values,color)));
  }
}
class _Spark extends CustomPainter {
  const _Spark(this.values,this.color);
  final List<double?> values;final Color color;
  @override void paint(Canvas c,Size size){
    final valid=values.whereType<double>().where((x)=>x.isFinite).toList();if(valid.length<2)return;
    var lo=valid.reduce(math.min),hi=valid.reduce(math.max);
    if((hi-lo).abs()<.000001){hi+=1;lo-=1;}
    Offset? last;Path? path;
    final pen=Paint()..color=color..strokeWidth=2.2..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;
    for(int i=0;i<values.length;i++){
      final n=values[i];if(n==null||!n.isFinite){if(path!=null)c.drawPath(path,pen);path=null;last=null;continue;}
      final pt=Offset(3+(size.width-6)*i/math.max(1,values.length-1),
        size.height-3-(size.height-6)*(n-lo)/(hi-lo));
      if(last==null){path=Path()..moveTo(pt.dx,pt.dy);}else{path!.lineTo(pt.dx,pt.dy);}
      last=pt;
    }
    if(path!=null)c.drawPath(path,pen);
  }
  @override bool shouldRepaint(covariant _Spark other)=>other.values!=values||other.color!=color;
}

class SalusColorBar extends StatelessWidget {
  const SalusColorBar({super.key,required this.value,required this.target,
    required this.color,required this.label,this.unit='g'});
  final double? value,target;final Color color;final String label,unit;
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text(label,style:const TextStyle(color:SalusV.secondary,fontSize:12))),
      Text(value==null?'Not recorded':target==null?'${value!.round()} $unit':'${value!.round()} / ${target!.round()} $unit',
        style:const TextStyle(color:SalusV.ink,fontSize:12,fontWeight:FontWeight.w700))]),
    const SizedBox(height:7),ClipRRect(borderRadius:BorderRadius.circular(10),
      child:LinearProgressIndicator(minHeight:7,value:target==null||value==null||target!<=0?0:(value!/target!).clamp(0.0,1.0),
        backgroundColor:SalusV.border,color:color)),
  ]);
}
