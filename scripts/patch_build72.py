"""Salus Build 72: the approved light/dark premium dashboard UI.

Runs after Build 71 feature patches. Does not change application IDs, signers,
wearable registration, persisted journal models, or the user's stored values.
"""
from pathlib import Path

# Re-running the workflow on an already-updated branch must be safe.
if 'version: 0.21.34+72' in Path('pubspec.yaml').read_text(encoding='utf-8'):
    print('Build 72 already installed; preserving validated source.')
    raise SystemExit(0)


def replace(path: str, before: str, after: str):
    p = Path(path)
    original = p.read_text(encoding='utf-8')
    if after in original:
        return
    count = original.count(before)
    if count != 1:
        raise RuntimeError(f'{path}: expected one match; got {count}: {before[:110]!r}')
    p.write_text(original.replace(before, after, 1), encoding='utf-8')


replace('pubspec.yaml', 'version: 0.21.33+71', 'version: 0.21.34+72')

# Backwards-compatible optional macro estimates for saved AI recipe objects.
replace('lib/services/ai_meal_planner_service.dart',
        '  final double? calories;\n  final double? protein;',
        '  final double? calories;\n  final double? protein;\n  final double? carbs;\n  final double? fat;\n  final double? fiber;')
replace('lib/services/ai_meal_planner_service.dart',
        '    required this.minutes, this.calories, this.protein, this.date, this.slot});',
        '    required this.minutes, this.calories, this.protein, this.carbs, this.fat, this.fiber, this.date, this.slot});')
replace('lib/services/ai_meal_planner_service.dart',
        "      protein: _credible(_number(j['estimated_protein_g_per_serving']), 0, 300),",
        "      protein: _credible(_number(j['estimated_protein_g_per_serving']), 0, 300),\n"
        "      carbs: _credible(_number(j['estimated_carbs_g_per_serving']), 0, 600),\n"
        "      fat: _credible(_number(j['estimated_fat_g_per_serving']), 0, 300),\n"
        "      fiber: _credible(_number(j['estimated_fiber_g_per_serving']), 0, 100),")
replace('lib/services/ai_meal_planner_service.dart',
        "    'estimated_protein_g_per_serving': protein,",
        "    'estimated_protein_g_per_serving': protein,\n"
        "    'estimated_carbs_g_per_serving': carbs,\n"
        "    'estimated_fat_g_per_serving': fat,\n"
        "    'estimated_fiber_g_per_serving': fiber,")
replace('lib/services/ai_meal_planner_service.dart',
        '"estimated_protein_g_per_serving":35,"date":null,"slot":null}',
        '"estimated_protein_g_per_serving":35,"estimated_carbs_g_per_serving":42,\n'
        '"estimated_fat_g_per_serving":13,"estimated_fiber_g_per_serving":7,"date":null,"slot":null}')
# Build 71 passed Flutter analysis/tests, but Kotlin failed at this one syntax error.
replace('native/android/SalusProtocolReader.kt',
        'if (temperatures.isEmpty) notes.add("COLMI 0x25: no verified temperature samples")',
        'if (temperatures.isEmpty()) notes.add("COLMI 0x25: no verified temperature samples")')

replace('lib/screens/home_shell.dart',
        "import 'home_screen.dart';",
        "import 'premium/salus_premium_home.dart';\nimport '../widgets/salus_premium_ui.dart';")
replace('lib/screens/home_shell.dart',
        '''    const screens = [
      HomeScreen(),''',
        '''    const screens = [
      SalusPremiumHome(),''')
replace('lib/screens/home_shell.dart',
        '''      appBar: index == 0
          ? _SalusBrandAppBar(''',
        '''      appBar: index == 0
          ? null // Premium dashboard owns its SALUS header.
          : _SalusBrandAppBar(''')
text = Path('lib/screens/home_shell.dart').read_text(encoding='utf-8')
old = '''      appBar: index == 0
          ? null // Premium dashboard owns its SALUS header.
          : _SalusBrandAppBar(
              onModuleSelected: selectModule,
              onCoach: () => Navigator.of(context).pushNamed('/coach'),
              onProfile: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            )
          : AppBar('''
new = '''      appBar: index == 0
          ? null // Premium dashboard owns its SALUS header.
          : AppBar('''
replace('lib/screens/home_shell.dart', old, new)
# Dead former home toolbar widgets would otherwise produce analyzer diagnostics.
home = Path('lib/screens/home_shell.dart')
source = home.read_text(encoding='utf-8')
start = source.index('class _SalusBrandAppBar extends StatelessWidget')
end = source.index('class _SalusBottomNav extends StatelessWidget')
source = source[:start] + source[end:]
source = source.replace("import 'profile_screen.dart';\n", '')
source = source.replace("import '../widgets/salus_widgets.dart';\n", '')
home.write_text(source, encoding='utf-8')
replace('lib/screens/home_shell.dart',
        '''      bottomNavigationBar: _SalusBottomNav(
        index: index,
        onChanged: ref.read(navigationProvider.notifier).go,
      ),''',
        '''      bottomNavigationBar: index == 0
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
            onChanged:ref.read(navigationProvider.notifier).go),''')

replace('lib/screens/diet/diet_shell.dart',
        "import 'diet_home_screen.dart';",
        "import 'diet_home_screen.dart';\nimport '../premium/salus_nutrition_overview.dart';\nimport '../../widgets/salus_premium_ui.dart';")
replace('lib/screens/diet/diet_shell.dart',
        '''        appBar: AppBar(''',
        '''        appBar: _index == 0 ? null : AppBar(''')
replace('lib/screens/diet/diet_shell.dart',
        '''          const DietHomeScreen(), const AiMealDiscoveryScreen(),''',
        '''          SalusNutritionOverview(
            onDiscover:()=>setState(()=>_index=1),
            onCalendar:()=>setState(()=>_index=3),
            onMeals:()=>setState(()=>_index=2),
            onJournal:()=>Navigator.of(context).push(MaterialPageRoute(
              builder:(_)=>Scaffold(appBar:AppBar(title:const Text('Food journal')),
                body:const DietHomeScreen()))),
          ), const AiMealDiscoveryScreen(),''')
replace('lib/screens/diet/diet_shell.dart',
        '''        bottomNavigationBar: _DietBottomNav(index: _index, onChanged: (value) => setState(() => _index = value)),''',
        '''        bottomNavigationBar: _index == 0
          ? PremiumDestinationBar(index:_index,onChanged:(value)=>setState(()=>_index=value),items:const [
              (Icons.pie_chart_outline,'Overview'),
              (Icons.auto_awesome_outlined,'Discover'),
              (Icons.restaurant_menu_outlined,'Meals'),
              (Icons.calendar_today_outlined,'Calendar'),
              (Icons.shopping_cart_outlined,'Grocery'),
            ])
          : _DietBottomNav(index: _index, onChanged: (value) => setState(() => _index = value)),''')

replace('lib/screens/workout_screen.dart',
        "import '../core/theme/app_theme.dart';",
        "import '../core/theme/app_theme.dart';\nimport 'premium/salus_training_overview.dart';")
replace('lib/screens/workout_screen.dart',
        "  String _tab = 'Today';",
        "  String _tab = 'Overview';")
replace('lib/screens/workout_screen.dart',
        '''      appBar: AppBar(
        title: const Text('Workout'),''',
        '''      appBar: _tab == 'Overview' ? null : AppBar(
        title: const Text('Workout'),''')
# On the premium overview hide legacy dark-styled tabs, but retain access to
# the complete previous Today/Schedule/Templates/History UI from its actions.
replace('lib/screens/workout_screen.dart',
        '''          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: HmTabs(
                labels: const ['Today', 'Schedule', 'Templates', 'History'],''',
        '''          children: [
            if (_tab != 'Overview') Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: HmTabs(
                labels: const ['Overview', 'Today', 'Schedule', 'Templates', 'History'],''')
replace('lib/screens/workout_screen.dart',
        '''      'History' => _HistoryView(library: library, connected: health.workouts),
      _ => _TodayView(library: library, connected: health.workouts),''',
        '''      'History' => _HistoryView(library: library, connected: health.workouts),
      'Overview' => SalusTrainingOverview(
        onToday:()=>setState(()=>_tab='Today'),
        onSchedule:()=>setState(()=>_tab='Schedule'),
        onHistory:()=>setState(()=>_tab='History')),
      _ => _TodayView(library: library, connected: health.workouts),''')
# Ensure the premium workout screen is light, without restyling old dark pages.
replace('lib/screens/workout_screen.dart',
        '''      backgroundColor: AppTheme.background,
      appBar: _tab == 'Overview' ? null : AppBar(''',
        '''      backgroundColor: _tab == 'Overview' ? const Color(0xfff6f8f7) : AppTheme.background,
      appBar: _tab == 'Overview' ? null : AppBar(''')

assert 'version: 0.21.34+72' in Path('pubspec.yaml').read_text()
assert 'com.rustnrum.healthyme.beta03' in Path('native/android/MainActivity.kt').read_text()
print('Build 72: premium Home/Nutrition/Training screens and Build 71 Kotlin fix installed')
