import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

enum HealthyMeModule { fitness, workout, diet, health }

class HealthyMeModuleMenuButton extends StatelessWidget {
  final HealthyMeModule current;
  final ValueChanged<HealthyMeModule> onSelected;
  final Color? iconColor;
  final bool showLabel, lightSurface;
  const HealthyMeModuleMenuButton({super.key, required this.current, required this.onSelected,
    this.iconColor, this.showLabel=false, this.lightSurface=false});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<HealthyMeModule>(
      tooltip: 'Salus modules',
      icon: showLabel?null:Icon(Icons.grid_view_rounded, size:22,color:iconColor),
      child: showLabel ? Container(
        padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
        decoration:BoxDecoration(
          color:lightSurface?const Color(0xffd8edf6):const Color(0xff102936),
          borderRadius:BorderRadius.circular(13),
          border:Border.all(color:lightSurface?const Color(0xff80b7c9):const Color(0xff285264))),
        child:Row(mainAxisSize:MainAxisSize.min,children:[
          Icon(Icons.grid_view_rounded,color:iconColor,size:18),
          const SizedBox(width:5),Text('Modules',style:TextStyle(
            color:iconColor,fontSize:11,fontWeight:FontWeight.w900)),
        ])) : null,
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem<HealthyMeModule>(enabled: false, child: Text('SALUS MODULES', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.8))),
        _item(module: HealthyMeModule.fitness, current: current, icon: Icons.eco_rounded, color: AppTheme.mint, title: 'Main', subtitle: 'Today • Activity • Sleep • Body'),
        const PopupMenuDivider(),
        _item(module: HealthyMeModule.workout, current: current, icon: Icons.fitness_center_rounded, color: AppTheme.cyan, title: 'Workout', subtitle: 'Today • Schedule • Templates • History'),
        const PopupMenuDivider(),
        _item(module: HealthyMeModule.diet, current: current, icon: Icons.restaurant_rounded, color: AppTheme.amber, title: 'Diet', subtitle: 'Today • Meals • Plan • Grocery'),
        const PopupMenuDivider(),
        _item(module: HealthyMeModule.health, current: current, icon: Icons.health_and_safety_outlined, color: AppTheme.blue, title: 'Health', subtitle: 'Overview • Vitals • Labs'),
      ],
    );
  }

  static PopupMenuItem<HealthyMeModule> _item({required HealthyMeModule module, required HealthyMeModule current, required IconData icon, required Color color, required String title, required String subtitle}) {
    final selected = module == current;
    return PopupMenuItem<HealthyMeModule>(
      value: module,
      enabled: !selected,
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 21)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          Text(selected ? 'Current module' : subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ])),
        if (selected) Icon(Icons.check_rounded, color: color, size: 20),
      ]),
    );
  }
}
