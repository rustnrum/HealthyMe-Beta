#!/usr/bin/env python3
"""Build 75 premium DARK UI upgrade from last validated Build 74.

Only edits presentation sources; health providers, databases, backups, keys,
Bluetooth collectors, package IDs and medical score algorithms stay intact.
Reapplying on committed Build 75 must be a no-op.
"""
from pathlib import Path

VER = Path('pubspec.yaml')
vs = VER.read_text()
if 'version: 0.21.37+75' in vs:
    assert 'class SalusPremiumHealth' in Path('lib/screens/premium/salus_premium_health.dart').read_text()
    assert "salus_premium_light_v2" in Path('lib/widgets/salus_premium_ui.dart').read_text()
    print('Build 75 premium dark source already applied')
    raise SystemExit(0)
if vs.count('version: 0.21.36+74') != 1:
    raise RuntimeError('Expected installed Build 74 source; refusing to mutate other versions')

pending = {}
def load(path):
    return pending.get(path, Path(path).read_text())
def put(path, text):
    pending[path] = text

def swap(path, old, new):
    s = load(path)
    count = s.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one match, found {count}: {old[:125]!r}')
    put(path, s.replace(old, new, 1))

swap('pubspec.yaml', 'version: 0.21.36+74', 'version: 0.21.37+75')
s = 'lib/widgets/salus_premium_ui.dart'
swap(s, "import 'package:shared_preferences/shared_preferences.dart';", "import 'package:shared_preferences/shared_preferences.dart';\nimport 'salus_premium_visuals.dart';")
swap(s, "static const _key = 'salus_premium_light_v1';", "static const _key = 'salus_premium_light_v2';")
swap(s, 'ValueNotifier<bool>(true)', 'ValueNotifier<bool>(false)')
swap(s, 'prefs.getBool(_key) ?? true', 'prefs.getBool(_key) ?? false')
# Keep opt-in light mode, but default all premium views to approved dark.
for old, new in {
    '0xff071118': '0xff050d16',
    '0xff14232a': '0xff0d1e2b',
    '0xfff4f8f6': '0xfff4f9fc',
    '0xffa2bab8': '0xffabc0c9',
    '0xff79918f': '0xff77919d',
    '0xff60e6b1': '0xff03d8f4',
    '0xff294038': '0xff274554',
    '0xff2b3d40': '0xff274554',
    '0xff36b974': '0xff12e3a2',
    '0xff69a6ed': '0xff4b9df9',
    '0xff49c5bf': '0xff03d8f4',
    '0xffef9957': '0xffffa32a',
    '0xffa18bee': '0xffb785ff',
}.items():
    swap(s, old, new)
# Wrap old dashboard sections in shared tinted premium panel, preserving action callbacks.
a = load(s)
start = '  @override Widget build(BuildContext context) {\n    final p=SalusSkin(SalusAppearance.light.value);\n    return Material(color:p.panel,borderRadius:BorderRadius.circular(20),'
stop = '\n  }\n}\n\nclass PremiumTitle'
if a.count(start) != 1 or a.count(stop) != 1: raise RuntimeError('PremiumCard implementation changed')
pos = a.index(start); end = a.index(stop,pos)+len('\n  }\n}')
replacement = '''  @override Widget build(BuildContext context) => SalusGlass(
    padding: padding, onTap: onTap, child: child);
}'''
put(s, a[:pos]+replacement+a[end:])

# Update the existing nutrition overview while retaining its journal, goals,
# user-controlled targets, calendar integration, source identity, and log logic.
n = 'lib/screens/premium/salus_nutrition_overview.dart'
swap(n,"import '../../widgets/salus_premium_ui.dart';",
     "import '../../widgets/salus_premium_ui.dart';\nimport '../../widgets/salus_premium_visuals.dart';")
swap(n,
    "PremiumRing(value:_goals['Calories']==null?null:kcal,maximum:_goals['Calories']??1,center:kcal==null?'—':'${kcal.round()}',caption:_goals['Calories']==null?'kcal logged':'of ${_goals['Calories']!.round()} kcal',size:133,color:SalusSkin.blue)",
    "SalusMacroRing(protein:protein,carbs:carbs,fat:fat,kcal:kcal,target:_goals['Calories'],size:143)")
swap(n,
    "Row(children:[Expanded(child:PremiumTitle(subtitle:'YOUR FOOD & YOUR GOALS',title:'Nutrition')),const PremiumThemeButton()]),",
    "Row(children:[Expanded(child:SalusHeading('Nutrition',caption:'YOUR FOOD & YOUR GOALS')),const PremiumThemeButton()]),")
swap(n,
    "const SizedBox(height:12),PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[\n          Row(children:[Icon(Icons.eco_outlined",
    "const SizedBox(height:12),Row(children:[\n          Expanded(child:_quickKpi('Calories',kcal,'kcal',SalusV.orange,Icons.local_fire_department)),const SizedBox(width:8),\n          Expanded(child:_quickKpi('Protein',protein,'g',SalusV.green,Icons.fitness_center)),const SizedBox(width:8),\n          Expanded(child:_quickKpi('Carbs',carbs,'g',SalusV.blue,Icons.grain)),\n        ]),const SizedBox(height:10),Row(children:[\n          Expanded(child:_quickKpi('Fat',fat,'g',SalusV.red,Icons.water_drop)),const SizedBox(width:8),\n          Expanded(child:_quickKpi('Fiber',fiber,'g',SalusV.purple,Icons.eco)),\n        ]),\n        const SizedBox(height:12),PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[\n          Row(children:[Icon(Icons.eco_outlined")
swap(n,
    "  Widget _planValue(SalusSkin p,String label,double? value,String unit)=>Column(",
    "  Widget _quickKpi(String name,double? value,String unit,Color color,IconData icon)=>\n"
    "    SalusGlass(glow:color,padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[\n"
    "      Icon(icon,color:color,size:19),const SizedBox(height:7),\n"
    "      Text(name,style:const TextStyle(color:SalusV.secondary,fontSize:11)),\n"
    "      Text(value==null?'—':'${value.round()} $unit',style:const TextStyle(color:SalusV.ink,fontSize:15,fontWeight:FontWeight.w900))]));\n"
    "  Widget _planValue(SalusSkin p,String label,double? value,String unit)=>Column(")
# Every food image thumbnail must remain attached to an actual user food entry.
# Inspiration is visibly separate from logged meals.
swap(n,
    "const SizedBox(height:20),PremiumSection(title:\"Today's meals\",trailing:'Calendar',onTap:widget.onCalendar),",
    "const SizedBox(height:14),SalusGlass(glow:SalusV.green,onTap:widget.onDiscover,child:Row(children:[\n"
    " ClipRRect(borderRadius:BorderRadius.circular(11),child:Image.asset('assets/premium/meal_illustration.jpg',width:64,height:64,fit:BoxFit.cover)),\n"
    " const SizedBox(width:10),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[\n"
    " Text('Find meals that fit your goals',style:TextStyle(color:SalusV.ink,fontWeight:FontWeight.w800,fontSize:13)),\n"
    " SizedBox(height:5),Text('Illustration · browse recipe ideas, not your food log',style:TextStyle(color:SalusV.secondary,fontSize:10))])),\n"
    " const Icon(Icons.chevron_right,color:SalusV.cyan)])),\n"
    "const SizedBox(height:20),PremiumSection(title:\"Today's meals\",trailing:'Calendar',onTap:widget.onCalendar),")

# Training overview stays powered by existing completed/scheduled workouts.
t = 'lib/screens/premium/salus_training_overview.dart'
swap(t,"import '../../widgets/salus_premium_ui.dart';",
    "import '../../widgets/salus_premium_ui.dart';\nimport '../../widgets/salus_premium_visuals.dart';")
swap(t,
    "Row(children:[Expanded(child:PremiumTitle(subtitle:'MOVEMENT & STRENGTH',title:'Training')),const PremiumThemeButton()]),\n      const SizedBox(height:18),Row(children:[",
    "Row(children:[Expanded(child:SalusHeading('Training',caption:'MOVEMENT & STRENGTH')),const PremiumThemeButton()]),\n"
    "      const SizedBox(height:13),const SalusWeekStrip(),const SizedBox(height:16),\n"
    "      SalusPhotoHero(asset:'assets/premium/training_hero.jpg',title:'Build a\\nstronger you.',\n"
    "        subtitle:'Keep up your program, one session at a time.',height:157,buttonText:'View workouts',onTap:widget.onToday),\n"
    "      const SizedBox(height:18),Row(children:[")
swap(t,
    "PremiumLineChart(values:activity,height:145,color:SalusSkin.blue),",
    "if(completed.isNotEmpty||connected.isNotEmpty)PremiumLineChart(values:activity,height:145,color:SalusSkin.blue)\n"
    "        else const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Text('No completed training sessions recorded this week.',style:TextStyle(color:SalusV.secondary,fontSize:12))),")
swap(t,
    "if(programSets==0)Text('Complete a workout containing exercises to see your program distribution.',style:TextStyle(color:p.secondary,fontSize:13)),\n        if(programSets>0)...[\n          SizedBox(height:190,child:Center(child:CustomPaint(size:const Size(145,178),painter:_MuscleDiagram(p,counts)))),",
    "Center(child:ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.asset('assets/premium/muscle_reference.jpg',height:225,fit:BoxFit.contain))),\n"
    "        const SizedBox(height:8),Text('Anatomy reference illustration · colors are not measured activation.',style:TextStyle(color:p.muted,fontSize:10)),\n"
    "        const SizedBox(height:10),\n"
    "        if(programSets==0)Text('Log a completed workout to show actual sets by muscle group.',style:TextStyle(color:p.secondary,fontSize:13)),\n"
    "        if(programSets>0)...[")
# Keep actual existing per-muscle progress bars underneath the anatomy asset.
anatomy = load(t)
marker = '/// Deliberately diagrammatic, not medical anatomy. Front-body zones are tinted'
if anatomy.count(marker)!=1: raise RuntimeError('Legacy muscle diagram painter location changed')
put(t, anatomy[:anatomy.index(marker)].rstrip()+'\n')

# Replace first Health landing page only. Legacy Vitals and Labs remain available.
h = 'lib/screens/health/health_shell.dart'
swap(h,"import 'health_home_screen.dart';",
    "import '../premium/salus_premium_health.dart';\nimport '../../widgets/salus_premium_ui.dart';")
swap(h,"import 'package:flutter/material.dart';",
    "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\nimport '../../state/navigation_provider.dart';")
swap(h,'static const _pages = [HealthHomeScreen(), HealthVitalsScreen(), LabsScreen(embedded: true)];',
    'static const _pages = [SalusPremiumHealth(), HealthVitalsScreen(), LabsScreen(embedded: true)];')
swap(h,'      appBar: AppBar(\n        flexibleSpace:',
    '      appBar: _index == 0 ? null : AppBar(\n        flexibleSpace:')
swap(h,
    '      bottomNavigationBar: _HealthBottomNav(index: _index, onChanged: (value) => setState(() => _index = value)),',
    '''      bottomNavigationBar: _index == 0 ? PremiumDestinationBar(index:3,
        items:const [
          (Icons.home_rounded,'Home'),
          (Icons.restaurant_rounded,'Nutrition'),
          (Icons.fitness_center_rounded,'Training'),
          (Icons.favorite_rounded,'Health'),
          (Icons.more_horiz_rounded,'More')],
        onChanged:(v){
          if(v==0||v==4){Navigator.of(context).popUntil((r)=>r.isFirst);}
          if(v==4)ProviderScope.containerOf(context,listen:false).read(navigationProvider.notifier).go(4);
          if(v==1)Navigator.of(context).pushReplacementNamed('/diet');
          if(v==2)Navigator.of(context).pushReplacementNamed('/workout');
        }) : _HealthBottomNav(index:_index,onChanged:(value)=>setState(()=>_index=value)),''')

# Global dark theme now reflects the selected design. Existing legacy pages
# keep their same dark theme rather than a confusing uncoordinated light shell.
# Upgrade the Workout overview with the same main module navigation.
w = 'lib/screens/workout_screen.dart'
swap(w,"import '../widgets/module_menu_button.dart';",
    "import '../widgets/module_menu_button.dart';\nimport '../widgets/salus_premium_ui.dart';")
swap(w,"import '../state/workout_state.dart';",
    "import '../state/workout_state.dart';\nimport '../state/navigation_provider.dart';")
swap(w,'      body: SafeArea(\n        child: Column(',
    '''      bottomNavigationBar: _tab == 'Overview' ? PremiumDestinationBar(index:2,
        items:const [
          (Icons.home_rounded,'Home'),
          (Icons.restaurant_rounded,'Nutrition'),
          (Icons.fitness_center_rounded,'Training'),
          (Icons.favorite_rounded,'Health'),
          (Icons.more_horiz_rounded,'More')],
        onChanged:(v){
          if(v==0||v==4)Navigator.of(context).popUntil((r)=>r.isFirst);
          if(v==4)ref.read(navigationProvider.notifier).go(4);
          if(v==1)Navigator.of(context).pushReplacementNamed('/diet');
          if(v==3)Navigator.of(context).pushReplacementNamed('/health');
        }) : null,
      body: SafeArea(
        child: Column(''')

# Test Build 75 app asset registration by preserving existing pubspec assets.
pub = load('pubspec.yaml')
needle='    - lib/assets/images/hero_mountains.jpg\n'
if pub.count(needle)!=1: raise RuntimeError('Flutter asset list changed')
put('pubspec.yaml',pub.replace(needle,needle+'    - assets/premium/\n',1))
# Avoid saving any file if even one anchor failed.
for filename, text in pending.items():
    Path(filename).write_text(text)
print('Build 75 dark premium styling and module overview integration applied')
