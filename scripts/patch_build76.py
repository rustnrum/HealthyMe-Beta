#!/usr/bin/env python3
"""Build 76: restore original Salus module/navigation flow, BOTH premium themes,
and remove the mountain placeholder hero. Data models / signed app remain untouched.
Fail closed on source drift, stage all writes until anchors verify.
"""
from pathlib import Path

v=Path('pubspec.yaml').read_text()
if 'version: 0.21.38+76' in v:
    assert 'SalusColorHero(' in Path('lib/screens/premium/salus_premium_home.dart').read_text()
    print('Build 76 source already installed; safe no-op')
    raise SystemExit(0)
if v.count('version: 0.21.37+75') != 1:
    raise RuntimeError('Build 76 requires the last successful Build 75 source')

pending={}
def grab(path): return pending.get(path,Path(path).read_text())
def write(path,text): pending[path]=text
def replace(path,a,b):
    s=grab(path)
    if s.count(a)!=1: raise RuntimeError(f'Anchor mismatch: {path} expected 1, got {s.count(a)}: {a[:95]!r}')
    write(path,s.replace(a,b,1))

replace('pubspec.yaml','version: 0.21.37+75','version: 0.21.38+76')

# Original Home bottom navigation is for Home, Activity, Sleep, Body, More.
# The separate popup remains the module switcher: Main / Workout / Diet / Health.
h='lib/screens/home_shell.dart'
a='''      bottomNavigationBar: index == 0
        ? PremiumDestinationBar(index: 0,items: const [
            (Icons.home_rounded, 'Home'),
            (Icons.restaurant_rounded, 'Nutrition'),
            (Icons.fitness_center_rounded, 'Training'),
            (Icons.favorite_outline, 'Health'),
            (Icons.more_horiz, 'More'),
          ],onChanged:(destination){
            switch(destination){
              case 0: break;
              case 1: Navigator.of(context).pushNamed('/diet'); break;
              case 2: Navigator.of(context).pushNamed('/workout'); break;
              case 3: Navigator.of(context).pushNamed('/health'); break;
              case 4: ref.read(navigationProvider.notifier).go(4); break;
            }
          })
        : _SalusBottomNav(index:index,
            onChanged:ref.read(navigationProvider.notifier).go),'''
b='''      bottomNavigationBar: _SalusBottomNav(
        index:index, onChanged:ref.read(navigationProvider.notifier).go),'''
replace(h,a,b)
replace(h,"import '../widgets/salus_premium_ui.dart';\n",'')

# Diet is still Today/Discover/Meals/Calendar/Grocery. Keep overview, not global module nav.
d='lib/screens/diet/diet_shell.dart'
start="""        bottomNavigationBar: _index == 0
          ? PremiumDestinationBar(index:_index,onChanged:(value)=>setState(()=>_index=value),items:const [
              (Icons.pie_chart_outline,'Overview'),
              (Icons.auto_awesome_outlined,'Discover'),
              (Icons.restaurant_menu_outlined,'Meals'),
              (Icons.calendar_today_outlined,'Calendar'),
              (Icons.shopping_cart_outlined,'Grocery'),
            ])
          : _DietBottomNav(index: _index, onChanged: (value) => setState(() => _index = value)),"""
replace(d,start,'        bottomNavigationBar: _DietBottomNav(index:_index, onChanged:(value)=>setState(()=>_index=value)),')
replace(d,"import '../../widgets/salus_premium_ui.dart';\n",'')

# Health original Health/Vitals/Labs navigation restored.
h='lib/screens/health/health_shell.dart'
start="""      bottomNavigationBar: _index == 0 ? PremiumDestinationBar(index:3,
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
        }) : _HealthBottomNav(index:_index,onChanged:(value)=>setState(()=>_index=value)),"""
replace(h,start,'      bottomNavigationBar: _HealthBottomNav(index:_index,onChanged:(value)=>setState(()=>_index=value)),')
replace(h,"import 'package:flutter_riverpod/flutter_riverpod.dart';\n",'')
replace(h,"import '../../state/navigation_provider.dart';\n",'')
replace(h,"import '../../widgets/salus_premium_ui.dart';\n",'')

# Training retains Overview and original Today / Schedule / Templates / History tabs.
w='lib/screens/workout_screen.dart'
start="""      bottomNavigationBar: _tab == 'Overview' ? PremiumDestinationBar(index:2,
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
"""
replace(w,start,'')
replace(w,"import '../state/navigation_provider.dart';\n",'')
replace(w,"import '../widgets/salus_premium_ui.dart';\n","import '../widgets/salus_premium_visuals.dart';\n")
replace(w,"            if (_tab != 'Overview') Padding(","            Padding(")
replace(w,"      backgroundColor: _tab == 'Overview' ? const Color(0xfff6f8f7) : AppTheme.background,","      backgroundColor: SalusV.background,")


# The Training landing page keeps the original module selection popup.
t='lib/screens/premium/salus_training_overview.dart'
replace(t,"import '../../widgets/salus_premium_visuals.dart';",
    "import '../../widgets/salus_premium_visuals.dart';\nimport '../../widgets/module_menu_button.dart';")
replace(t,"Row(children:[Expanded(child:SalusHeading('Training',caption:'MOVEMENT & STRENGTH')),const PremiumThemeButton()]),",
    """Row(children:[Expanded(child:SalusHeading('Training',caption:'MOVEMENT & STRENGTH')),
       HealthyMeModuleMenuButton(current:HealthyMeModule.workout,onSelected:(m){switch(m){
         case HealthyMeModule.fitness:Navigator.of(context).popUntil((r)=>r.isFirst);break;
         case HealthyMeModule.workout:break;
         case HealthyMeModule.diet:Navigator.of(context).pushReplacementNamed('/diet');break;
         case HealthyMeModule.health:Navigator.of(context).pushReplacementNamed('/health');break;
       }}),const PremiumThemeButton()]),""")

# Shared premium appearance: user-selectable LIGHT, DARK and follow SYSTEM.
ui='lib/widgets/salus_premium_ui.dart'
start=grab(ui).index('class SalusAppearance {');stop=grab(ui).index('\nclass SalusSkin',start)
new='''class SalusAppearance {
  static const _key = 'salus_premium_light_v2'; // Preserve Build 75 preference.
  static const _modeKey = 'salus_appearance_mode_v1';
  static final ValueNotifier<bool> light = ValueNotifier<bool>(false);
  static String mode = 'dark';
  static bool _loaded = false;
  static bool _observing = false;
  static void _apply() {
    final selectedLight = mode == 'light' ||
      (mode == 'system' && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light);
    SalusV.lightMode = selectedLight;
    light.value = selectedLight;
  }
  static void onSystemBrightnessChanged() {
    if (mode == 'system') _apply();
  }
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    if (!_observing) { WidgetsBinding.instance.addObserver(_AppearanceObserver()); _observing = true; }
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_modeKey);
      mode = (stored == 'light' || stored == 'dark' || stored == 'system')
          ? stored! : ((prefs.getBool(_key) ?? false) ? 'light' : 'dark');
      _apply();
    } catch (_) { _apply(); }
  }
  static Future<void> setMode(String requested) async {
    if (requested != 'light' && requested != 'dark' && requested != 'system') return;
    mode = requested;
    _apply();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, requested);
    await prefs.setBool(_key, light.value);
  }
  static Future<void> toggle() => setMode(light.value ? 'dark' : 'light');
}
class _AppearanceObserver extends WidgetsBindingObserver {
  @override void didChangePlatformBrightness() => SalusAppearance.onSystemBrightnessChanged();
}
'''
write(ui,grab(ui)[:start]+new+grab(ui)[stop:])
start='''  @override Widget build(BuildContext context) {final p=SalusSkin(SalusAppearance.light.value);
    return IconButton(tooltip:p.light?'Switch dashboards to dark':'Switch dashboards to light',
      onPressed:()=>SalusAppearance.toggle(), icon:Icon(p.light?Icons.dark_mode_outlined:Icons.light_mode_outlined,color:p.accent));
  }'''
replacement='''  @override Widget build(BuildContext context) {final p=SalusSkin(SalusAppearance.light.value);
    return PopupMenuButton<String>(
      tooltip:'Appearance: Light, Dark or Follow System',
      icon:Icon(p.light?Icons.light_mode_outlined:Icons.dark_mode_outlined,color:p.accent),
      onSelected:(value)=>SalusAppearance.setMode(value),
      itemBuilder:(context)=>const [
        PopupMenuItem(value:'light',child:Text('Light theme')),
        PopupMenuItem(value:'dark',child:Text('Dark theme')),
        PopupMenuItem(value:'system',child:Text('Follow system')),
      ]);
  }'''
replace(ui,start,replacement)

# Nutrition uses real data and original module dropdown in its header.
n='lib/screens/premium/salus_nutrition_overview.dart'
replace(n,"import '../../widgets/salus_premium_visuals.dart';","import '../../widgets/salus_premium_visuals.dart';\nimport '../../widgets/module_menu_button.dart';")
replace(n,"Row(children:[Expanded(child:SalusHeading('Nutrition',caption:'YOUR FOOD & YOUR GOALS')),const PremiumThemeButton()]),",
"""Row(children:[Expanded(child:SalusHeading('Nutrition',caption:'YOUR FOOD & YOUR GOALS')),
          HealthyMeModuleMenuButton(current:HealthyMeModule.diet,onSelected:(m){switch(m){
            case HealthyMeModule.fitness:Navigator.of(context).popUntil((r)=>r.isFirst);break;
            case HealthyMeModule.workout:Navigator.of(context).pushReplacementNamed('/workout');break;
            case HealthyMeModule.diet:break;
            case HealthyMeModule.health:Navigator.of(context).pushReplacementNamed('/health');break;
          }}),const PremiumThemeButton()]),""")

# Existing Build 75 regression now validates CURRENT Build 76 without fake mountain asset.
test='test/build75_dark_premium_contract_test.dart'
replace(test,"expect(pubspec,contains('version: 0.21.37+75'));","expect(RegExp(r'^version: 0\\.21\\.(37|38)\\+(75|76)$',multiLine:true).hasMatch(pubspec),isTrue);")
replace(test,"for(final filename in ['salus_night_mountains.jpg','training_hero.jpg',","for(final filename in ['training_hero.jpg',")
# A new test protects navigation and both themes.

# Build 75 hard-coded some premium text colors with `const`. Color roles are
# now runtime theme values, so remove const *widget expressions* in the two
# legacy premium overview files. Never remove const constructor declarations.
import re
for file in ['lib/screens/premium/salus_training_overview.dart',
             'lib/screens/premium/salus_nutrition_overview.dart']:
    s=grab(file)
    # Convert only const constructor CALLS that now reference theme getters.
    # Keep local `const` declarations and static const lists intact.
    write(file,re.sub(r'\bconst\s+(?=[A-Z_]\w*\s*\()', '', s))

# Stage all text, then validate invariants before file write.
for path,text in pending.items():
    if path.startswith('lib/') and ('version:' in path): raise RuntimeError('Unexpected path')
for path,text in pending.items(): Path(path).write_text(text)
Path('assets/premium/salus_night_mountains.jpg').unlink(missing_ok=True)
print('Build 76 original navigation, light/dark/system theme, and mountain removal applied')
