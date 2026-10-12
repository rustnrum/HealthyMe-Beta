// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'salus_premium_visuals.dart';

/// The premium overview palette is independent of legacy Salus pages so those
/// pages remain legible until their hard-coded dark colors are migrated.
class SalusAppearance {
  static const _key = 'salus_premium_light_v2';
  static final ValueNotifier<bool> light = ValueNotifier<bool>(false);
  static bool _loaded = false;
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      light.value = prefs.getBool(_key) ?? false;
    } catch (_) { /* No device preferences in tests; use light default. */ }
  }
  static Future<void> toggle() async {
    light.value = !light.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, light.value);
  }
}

class SalusSkin {
  final bool light;
  const SalusSkin(this.light);
  Color get canvas => light ? const Color(0xfff6f8f7) : const Color(0xff050d16);
  Color get panel => light ? Colors.white : const Color(0xff0d1e2b);
  Color get ink => light ? const Color(0xff102d28) : const Color(0xfff4f9fc);
  Color get secondary => light ? const Color(0xff627472) : const Color(0xffabc0c9);
  Color get muted => light ? const Color(0xff899795) : const Color(0xff77919d);
  Color get accent => light ? const Color(0xff235f4d) : const Color(0xff03d8f4);
  Color get border => light ? const Color(0xffe8eeeb) : const Color(0xff274554);
  Color get track => light ? const Color(0xffe9efeb) : const Color(0xff274554);
  static const Color green = Color(0xff12e3a2);
  static const Color blue = Color(0xff4b9df9);
  static const Color aqua = Color(0xff03d8f4);
  static const Color orange = Color(0xffffa32a);
  static const Color purple = Color(0xffb785ff);
}

class PremiumSection extends StatelessWidget {
  const PremiumSection({super.key,required this.title,this.trailing,this.onTap});
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  @override Widget build(BuildContext context) {
    final p = SalusSkin(SalusAppearance.light.value);
    return Row(children:[
      Expanded(child:Text(title,style:TextStyle(color:p.ink,fontSize:19,fontWeight:FontWeight.w800))),
      if(trailing!=null) TextButton(onPressed:onTap,child:Text(trailing!,style:TextStyle(color:p.accent))),
    ]);
  }
}

class PremiumCard extends StatelessWidget {
  const PremiumCard({super.key,required this.child,this.padding=const EdgeInsets.all(16),this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override Widget build(BuildContext context) => SalusGlass(
    padding: padding, onTap: onTap, child: child);
}

class PremiumTitle extends StatelessWidget {
  const PremiumTitle({super.key,required this.title,required this.subtitle,this.trailing});
  final String title,subtitle;
  final Widget? trailing;
  @override Widget build(BuildContext context){final p=SalusSkin(SalusAppearance.light.value);return Row(children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(subtitle,style:TextStyle(color:p.secondary,fontSize:13)),
      const SizedBox(height:4),Text(title,style:TextStyle(color:p.ink,fontSize:30,fontWeight:FontWeight.w800,letterSpacing:-0.8)),
    ])),if(trailing!=null) trailing!]);}
}

class PremiumThemeButton extends StatelessWidget {
  const PremiumThemeButton({super.key});
  @override Widget build(BuildContext context) {final p=SalusSkin(SalusAppearance.light.value);
    return IconButton(tooltip:p.light?'Switch dashboards to dark':'Switch dashboards to light',
      onPressed:()=>SalusAppearance.toggle(), icon:Icon(p.light?Icons.dark_mode_outlined:Icons.light_mode_outlined,color:p.accent));
  }
}

class PremiumProgress extends StatelessWidget {
  const PremiumProgress({super.key,required this.label,required this.value,required this.target,required this.color,this.unit='g'});
  final String label,unit; final double? value,target; final Color color;
  @override Widget build(BuildContext context){final p=SalusSkin(SalusAppearance.light.value);
    final known=value!=null&&target!=null&&target!>0;
    final ratio=known?(value!/target!).clamp(0.0,1.0):0.0;
    return Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(label,style:TextStyle(color:p.ink,fontWeight:FontWeight.w600))),
        Text(value==null?'Not logged':target==null?'${value!.round()} $unit':'${value!.round()} / ${target!.round()} $unit',style:TextStyle(color:p.secondary,fontSize:12))]),
      const SizedBox(height:8),ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:ratio,backgroundColor:p.track,color:color,minHeight:8)),
    ]));
  }
}

class PremiumRing extends StatelessWidget {
  const PremiumRing({super.key,required this.value,required this.maximum,required this.center,required this.caption,
    this.color=SalusSkin.green,this.size=126});
  final double? value; final double maximum,size; final String center,caption; final Color color;
  @override Widget build(BuildContext context){final p=SalusSkin(SalusAppearance.light.value);
    final ratio=value==null||maximum<=0?0.0:(value!/maximum).clamp(0.0,1.0);
    return SizedBox(width:size,height:size,child:Stack(fit:StackFit.expand,children:[
      CircularProgressIndicator(value:ratio,backgroundColor:p.track,valueColor:AlwaysStoppedAnimation<Color>(color),strokeWidth:11,strokeCap:StrokeCap.round),
      Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(center,style:TextStyle(color:p.ink,fontSize:size>115?25:20,fontWeight:FontWeight.w800)),
        const SizedBox(height:2),Text(caption,textAlign:TextAlign.center,style:TextStyle(color:p.secondary,fontSize:10))])),
    ]));
  }
}

/// Chart points are only drawn for measured values. Nulls break the line.
class PremiumLineChart extends StatelessWidget {
  const PremiumLineChart({super.key,required this.values,this.color=SalusSkin.blue,this.height=140,this.unit=''});
  final List<double?> values;final Color color;final double height;final String unit;
  @override Widget build(BuildContext context){final p=SalusSkin(SalusAppearance.light.value);
    if(values.whereType<double>().length<2) return SizedBox(height:height,child:Center(child:Text('More recorded days needed for a trend',style:TextStyle(color:p.secondary,fontSize:12))));
    return SizedBox(height:height,child:CustomPaint(painter:_PremiumLinePainter(values,color,p.border,p.secondary)));
  }
}
class _PremiumLinePainter extends CustomPainter {
  _PremiumLinePainter(this.values,this.color,this.grid,this.text);
  final List<double?> values;final Color color,grid,text;
  @override void paint(Canvas c,Size size){
    final finite=values.whereType<double>().where((v)=>v.isFinite).toList();if(finite.length<2)return;
    var min=finite.reduce(math.min),max=finite.reduce(math.max);
    if((max-min).abs()<0.001){min-=1;max+=1;}else{final pad=(max-min)*0.12;min-=pad;max+=pad;}
    final graph=Rect.fromLTWH(38,10,size.width-46,size.height-30);
    final axis=Paint()..color=grid..strokeWidth=1;
    for(var i=0;i<=3;i++){final y=graph.top+graph.height*i/3;
      c.drawLine(Offset(graph.left,y),Offset(graph.right,y),axis);
      final v=max-(max-min)*i/3;
      final tp=TextPainter(text:TextSpan(text:v.toStringAsFixed(v.abs()<10?1:0),style:TextStyle(color:text,fontSize:10)),textDirection:TextDirection.ltr)..layout();
      tp.paint(c,Offset(0,y-tp.height/2));
    }
    Offset? previous;final pen=Paint()..color=color..strokeWidth=2.5..strokeCap=StrokeCap.round;
    for(var i=0;i<values.length;i++){
      final v=values[i];if(v==null||!v.isFinite){previous=null;continue;}
      final pt=Offset(graph.left+graph.width*i/math.max(1,values.length-1), graph.bottom-(v-min)/(max-min)*graph.height);
      if(previous!=null)c.drawLine(previous,pt,pen);
      c.drawCircle(pt,3,Paint()..color=color);previous=pt;
    }
  }
  @override bool shouldRepaint(covariant _PremiumLinePainter old)=>old.values!=values||old.color!=color;
}

String premiumNumber(num? v,{int decimal=0})=>v==null?'—':v.toStringAsFixed(decimal);

/// Navigation follows existing app routes; all original feature pages remain.
class PremiumDestinationBar extends StatelessWidget {
  const PremiumDestinationBar({super.key,required this.index,required this.onChanged,required this.items});
  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData,String)> items;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable:SalusAppearance.light,
    builder:(context,light,_){
      final p=SalusSkin(light);
      return Material(
        color:p.panel,
        child:SafeArea(
          top:false,
          child:Container(
            decoration:BoxDecoration(border:Border(top:BorderSide(color:p.border))),
            height:64,
            child:Row(children:[
              for(var i=0;i<items.length;i++)
                Expanded(
                  child:InkWell(
                    onTap:()=>onChanged(i),
                    child:Column(
                      mainAxisAlignment:MainAxisAlignment.center,
                      children:[
                        Icon(items[i].$1,size:22,color:i==index?p.accent:p.muted),
                        const SizedBox(height:4),
                        Text(items[i].$2,maxLines:1,overflow:TextOverflow.ellipsis,
                          style:TextStyle(fontSize:10,color:i==index?p.accent:p.secondary,
                            fontWeight:i==index?FontWeight.w800:FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
    },
  );
}
