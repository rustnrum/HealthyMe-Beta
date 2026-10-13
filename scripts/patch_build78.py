#!/usr/bin/env python3
"""Build 78 visuals: preserve original modules, data, signing and history."""
from pathlib import Path

def replace(path, old, new):
    p=Path(path)
    text=p.read_text()
    count=text.count(old)
    if count!=1:
        raise RuntimeError(f'Build78 anchor mismatch in {path}: {count} occurrences of {old[:90]!r}')
    p.write_text(text.replace(old,new,1))

pubspec=Path('pubspec.yaml')
if 'version: 0.21.40+78' in pubspec.read_text():
    print('Build 78 already installed; keeping source unchanged')
    raise SystemExit(0)
if 'version: 0.21.39+77' not in pubspec.read_text():
    raise RuntimeError('Build 78 requires validated Build 77 source')

replace('pubspec.yaml','version: 0.21.39+77','version: 0.21.40+78')
menu='lib/widgets/module_menu_button.dart'
replace(menu,'  final ValueChanged<HealthyMeModule> onSelected;\n',
        '  final ValueChanged<HealthyMeModule> onSelected;\n  final Color? iconColor;\n  final bool showLabel, lightSurface;\n')
replace(menu,
        '  const HealthyMeModuleMenuButton({super.key, required this.current, required this.onSelected});',
        '  const HealthyMeModuleMenuButton({super.key, required this.current, required this.onSelected,\n    this.iconColor, this.showLabel=false, this.lightSurface=false});')
replace(menu,
        "      icon: const Icon(Icons.grid_view_rounded, size: 22),",
        """      icon: showLabel?null:Icon(Icons.grid_view_rounded, size:22,color:iconColor),
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
        ])) : null,""")
for path in [
 'lib/screens/premium/salus_home_77.dart',
 'lib/screens/premium/salus_nutrition_77.dart',
 'lib/screens/premium/salus_training_77.dart',
 'lib/screens/premium/salus_health_77.dart',
]:
    replace(path,'iconColor:S77.ink,showLabel:true,current:',
                 'iconColor:S77.ink,showLabel:true,lightSurface:light,current:')

# Older version assertions are updated only when the new source is installed.
replace('test/build75_dark_premium_contract_test.dart',
        r"r'^version: 0\.21\.(37|38|39)\+(75|76|77)$'",
        r"r'^version: 0\.21\.(37|38|39|40)\+(75|76|77|78)$'")
replace('test/build76_light_dark_navigation_contract_test.dart',
        "contains('version: 0.21.39+77')","contains('version: 0.21.40+78')")
replace('test/build77_visual_navigation_contract_test.dart',
        "contains('version: 0.21.39+77')","contains('version: 0.21.40+78')")
print('Build 78 premium dashboard visuals installed; data and module routing unchanged')
