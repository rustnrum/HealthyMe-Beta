// Salus visual language, Build 87.  Pure presentation; no simulated readings.
import 'package:flutter/material.dart';

class S87 {
  static const bg = Color(0xFF060A10);
  static const card = Color(0xFF111A24);
  static const card2 = Color(0xFF172430);
  static const border = Color(0xFF2A3848);
  static const muted = Color(0xFF9DADBC);
  static const teal = Color(0xFF39D9D0);
  static const green = Color(0xFF35DDB0);
  static const blue = Color(0xFF3CB1F7);
  static const orange = Color(0xFFFFB13A);
  static const purple = Color(0xFFAB87F8);
  static const red = Color(0xFFFF656D);
  static const ink = Color(0xFFF4F8FC);
  static const surfaceGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1A2935), Color(0xFF0C141D)],
  );
}

class S87Panel extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const S87Panel({super.key, required this.child, this.accent,
    this.padding = const EdgeInsets.all(16), this.onTap});
  @override Widget build(BuildContext context) {
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: S87.surfaceGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent?.withValues(alpha: .52) ?? S87.border),
        boxShadow: const [BoxShadow(color: Color(0x45000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: child,
    );
    return onTap == null ? panel : Material(color: Colors.transparent, child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(20), child: panel));
  }
}

class S87Brand extends StatelessWidget {
  final String? subtitle;
  final Widget? trailing;
  const S87Brand({super.key, this.subtitle, this.trailing});
  @override Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('S A L U S', style: TextStyle(fontWeight: FontWeight.w700,
        color: S87.ink, fontSize: 22, letterSpacing: 2.1)),
      if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 3),
        child: Text(subtitle!.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: S87.muted, fontSize: 9.5, letterSpacing: 2.1))),
    ])),
    if (trailing != null) trailing!,
  ]);
}

class S87Heading extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;
  const S87Heading(this.title, {super.key, this.action, this.onTap});
  @override Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(color:S87.ink, fontWeight: FontWeight.w700, fontSize: 18))),
    if (action != null) TextButton(onPressed: onTap, child: Text(action!,
      style: const TextStyle(color: S87.blue, fontWeight: FontWeight.w600, fontSize: 12))),
  ]);
}

class S87Stat extends StatelessWidget {
  final IconData icon;
  final String title, value, detail;
  final Color color;
  final VoidCallback? onTap;
  const S87Stat({super.key, required this.icon, required this.title,
    required this.value, required this.detail, required this.color, this.onTap});
  @override Widget build(BuildContext context) => S87Panel(
    padding: const EdgeInsets.fromLTRB(12, 14, 11, 13), accent: color.withValues(alpha:.43), onTap: onTap,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20, color: color), const SizedBox(height: 11),
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color:S87.muted, fontSize: 11)),
      const SizedBox(height: 5),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color:S87.ink,fontSize:23,fontWeight:FontWeight.w700)),
      const SizedBox(height: 4),
      Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color:S87.muted,fontSize:10.2)),
    ]));
}

class S87Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const S87Chip(this.label,{super.key,this.selected=false,this.onTap});
  @override Widget build(BuildContext context) => InkWell(
    onTap:onTap,borderRadius:BorderRadius.circular(12),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 15,vertical: 9),
      decoration: BoxDecoration(borderRadius:BorderRadius.circular(12),
        color:selected ? S87.teal.withValues(alpha:.24):S87.card,
        border:Border.all(color:selected ? S87.teal : S87.border)),
      child:Text(label,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
        color:selected ? S87.teal : S87.muted))));
}

class S87MetricLine extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const S87MetricLine({super.key,required this.label,required this.value,
    required this.icon,required this.color});
  @override Widget build(BuildContext context) => Padding(
    padding:const EdgeInsets.symmetric(vertical:7), child:Row(children:[
      Icon(icon,color:color,size:18),const SizedBox(width:9),
      Expanded(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
        style:const TextStyle(color:S87.muted,fontSize:12))),
      const SizedBox(width:5),
      Flexible(child:Text(value,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.end,
        style:const TextStyle(color:S87.ink,fontWeight:FontWeight.w700,fontSize:12))),
    ]));
}

/// Artwork supplied with the approved design; readings are rendered separately.
/// For missing data, the artwork is muted so it does not imply a measurement.
class S87ArtworkRing extends StatelessWidget {
  final String asset, value, caption;
  final double size;
  final bool measured;
  const S87ArtworkRing({super.key,required this.asset,required this.value,
    required this.caption,required this.size,this.measured=true});
  @override Widget build(BuildContext context) => SizedBox(width:size,height:size,
    child:Stack(alignment:Alignment.center,children:[
      Opacity(opacity: measured ? 1 : .18,
        child:Image.asset(asset,width:size,height:size,fit:BoxFit.contain)),
      Column(mainAxisSize:MainAxisSize.min,children:[
        Text(value,textAlign:TextAlign.center,style:TextStyle(color:S87.ink,
          fontSize:size>=135?30:23,fontWeight:FontWeight.w800)),
        const SizedBox(height:3),Text(caption,textAlign:TextAlign.center,
          style:TextStyle(color:measured?S87.green:S87.muted,fontSize:11,fontWeight:FontWeight.w600)),
      ]),
    ]));
}

class S87GroupBar extends StatelessWidget {
  final String label,value;
  final Color color;
  final double fraction;
  const S87GroupBar({super.key,required this.label,required this.value,
    required this.fraction,required this.color});
  @override Widget build(BuildContext context) => Padding(padding:const EdgeInsets.symmetric(vertical:9),
    child:Row(children:[
      SizedBox(width:77,child:Text(label,style:const TextStyle(color:S87.ink,fontSize:12))),
      Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(8),
        child:LinearProgressIndicator(value:fraction.clamp(0.0,1.0).toDouble(),minHeight:8,
          backgroundColor:S87.border,color:color))),
      const SizedBox(width:10),SizedBox(width:46,child:Text(value,textAlign:TextAlign.end,
        style:const TextStyle(color:S87.muted,fontSize:10))),
    ]));
}

class S87PhotoBanner extends StatelessWidget {
  final String asset, title;
  final String? caption;
  final double height;
  const S87PhotoBanner({super.key,required this.asset,required this.title,this.caption,this.height=170});
  @override Widget build(BuildContext context) => ClipRRect(borderRadius:BorderRadius.circular(19),
    child:SizedBox(height:height,width:double.infinity,child:Stack(fit:StackFit.expand,children:[
      Image.asset(asset,fit:BoxFit.cover),
      const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(
        begin:Alignment.centerLeft,end:Alignment.centerRight,
        colors:[Color(0xE6060A10),Color(0x22060A10)]))),
      Padding(padding:const EdgeInsets.all(18),child:Column(
        mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:const TextStyle(color:S87.ink,fontSize:25,fontWeight:FontWeight.w800,height:1.13)),
          if(caption!=null)Padding(padding:const EdgeInsets.only(top:9),child:
            SizedBox(width:190,child:Text(caption!,style:const TextStyle(color:S87.muted,fontSize:11,height:1.35)))),
        ])),
    ])));
}
