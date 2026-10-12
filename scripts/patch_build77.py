#!/usr/bin/env python3
"""Install the Salus 77 visual-dashboard routes over validated Build 76.

Only presentation routes and matching tests change. All existing storage,
service providers, original module selectors and Android signing remain intact.
"""
from pathlib import Path
version = Path('pubspec.yaml')
pubspec = version.read_text()
if 'version: 0.21.39+77' in pubspec:
    assert 'SalusNutrition77(' in Path('lib/screens/diet/diet_shell.dart').read_text()
    assert 'SalusHome77()' in Path('lib/screens/home_shell.dart').read_text()
    print('Salus 77 already installed')
    raise SystemExit(0)
if pubspec.count('version: 0.21.38+76') != 1:
    raise RuntimeError('Build 77 requires the validated Build 76 source')
updates={}
def read(path): return updates.get(path,Path(path).read_text())
def write(path,data): updates[path]=data
def change(path,before,after):
    data=read(path)
    count=data.count(before)
    if count != 1: raise RuntimeError(f'Unexpected {path} anchor count={count}: {before!r}')
    write(path,data.replace(before,after,1))
change('pubspec.yaml','version: 0.21.38+76','version: 0.21.39+77')
change('lib/screens/home_shell.dart',"import 'premium/salus_premium_home.dart';", "import 'premium/salus_home_77.dart';")
change('lib/screens/home_shell.dart','SalusPremiumHome()','SalusHome77()')
change('lib/screens/home_shell.dart','SafeArea(top: false, bottom: false, child: IndexedStack',
       'SafeArea(top: index == 0, bottom: false, child: IndexedStack')
change('lib/screens/diet/diet_shell.dart',"import '../premium/salus_nutrition_overview.dart';", "import '../premium/salus_nutrition_77.dart';")
change('lib/screens/diet/diet_shell.dart','SalusNutritionOverview(','SalusNutrition77(')
change('lib/screens/diet/diet_shell.dart','SafeArea(top: false, child: IndexedStack',
       'SafeArea(top: _index == 0, child: IndexedStack')
change('lib/screens/health/health_shell.dart',"import '../premium/salus_premium_health.dart';", "import '../premium/salus_health_77.dart';")
change('lib/screens/health/health_shell.dart','SalusPremiumHealth()','SalusHealth77()')
change('lib/screens/health/health_shell.dart','SafeArea(top: false, child: IndexedStack',
       'SafeArea(top: _index == 0, child: IndexedStack')
change('lib/screens/workout_screen.dart',"import 'premium/salus_training_overview.dart';", "import 'premium/salus_training_77.dart';")
change('lib/screens/workout_screen.dart','SalusTrainingOverview(','SalusTraining77(')
# Old tests must evolve with, not veto, the new user-approved visuals.
change('test/build73_renderer_contract_test.dart',"contains('SalusPremiumHome()')", "contains('SalusHome77()')")
change('test/build75_dark_premium_contract_test.dart',
       r"r'^version: 0\.21\.(37|38)\+(75|76)$'",r"r'^version: 0\.21\.(37|38|39)\+(75|76|77)$'")
change('test/build75_dark_premium_contract_test.dart',"contains('SalusPremiumHealth()')","contains('SalusHealth77()')")
change('test/build76_light_dark_navigation_contract_test.dart',"contains('version: 0.21.38+76')","contains('version: 0.21.39+77')")
for path,data in updates.items(): Path(path).write_text(data)
print('Salus Build 77 live dashboards and version applied; source data unchanged')
