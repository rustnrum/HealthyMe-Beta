"""Salus Build 87 design integration, starting from the validated Build 86.

Reuses the original HomeShell, WorkoutScreen, DietShell, Android native bridge,
persisted stores, signing identity and routes.  Activates mockup-led dashboards
without ever promoting the archived Build85 sample data to production.
Idempotent so CI can invoke it twice for migration verification.
"""
from pathlib import Path
import re

VERSION = 'version: 0.21.49+87'
version_file = Path('pubspec.yaml').read_text(encoding='utf-8')
if not re.search(r'^version: 0\.21\.49\+87\s*$', version_file, re.M):
    raise RuntimeError(f'Wrong Salus release version, expected {VERSION}')
for relative in [
    'lib/screens/premium/salus_home_77.dart',
    'lib/screens/premium/salus_home_87.dart',
    'lib/screens/premium/salus_training_87.dart',
    'lib/screens/premium/salus_nutrition_87.dart',
    'lib/screens/premium/salus87_ui.dart',
    'assets/premium/salus_mountain_85.webp',
    'assets/premium/training_hero.jpg',
    'assets/premium/muscle_reference.jpg',
    'assets/premium/nutrition_photo77.jpg',
    'assets/preview84/img/ring_recovery.png',
    'assets/preview84/img/ring_calories.png',
    'native/android/AndroidManifest.xml',
]:
    if not Path(relative).is_file():
        raise RuntimeError(f'Missing existing app dependency: {relative}')

# This checks the actual implementation: arbitrary app resets or sample-data
# fallbacks must cause the build to fail even if the UI compiles.
home87 = Path('lib/screens/premium/salus_home_87.dart').read_text(encoding='utf-8')
for token in ['RecoveryService.build(', 'HrvSourceService.resolve(',
              'SalusEnergyService.estimate(', 'HomeInsightService.build(',
              'ref.watch(appStateProvider)', 'ref.watch(dietLogStateProvider)',
              'ref.watch(workoutStateProvider)', 'assets/premium/salus_mountain_85.webp',
              'assets/preview84/img/ring_recovery.png', "'/voice'", "'/workout'", "'/diet'"]:
    if token not in home87:
        raise RuntimeError(f'Build87 Home is missing a required live-data/visual contract: {token}')
for forbidden in ['Data.recovery', 'DESIGN PREVIEW', 'SAMPLE DATA', 'SalusHome85(']:
    if forbidden in home87:
        raise RuntimeError(f'Illustrative fixtures cannot be an active Home: {forbidden}')

def change(path_name, before, after):
    path = Path(path_name)
    value = path.read_text(encoding='utf-8')
    if before == after:
        return
    if before not in value:
        if after in value:
            return
        raise RuntimeError(f'{path_name}: missing exact migration anchor {before!r}')
    if value.count(before) != 1:
        raise RuntimeError(f'{path_name}: expected one migration anchor {before!r}; found {value.count(before)}')
    path.write_text(value.replace(before, after, 1), encoding='utf-8')

home = 'lib/screens/home_shell.dart'
change(home, "import 'premium/salus_home_77.dart';", "import 'premium/salus_home_87.dart';")
change(home, 'SalusHome77(),', 'SalusHome87(),')
change(home, 'floatingActionButton: SalusVoiceLauncher(',
       'floatingActionButton: index == 0 ? null : SalusVoiceLauncher(')
# Keep existing 5-tab navigation and automatic sync. The Home header now owns
# its small voice control rather than an overlay obscuring the cards.
workout = 'lib/screens/workout_screen.dart'
change(workout, "import 'premium/salus_training_77.dart';",
       "import 'premium/salus_training_87.dart';")
change(workout, 'SalusTraining77(', 'SalusTraining87(')
change(workout, 'floatingActionButton: SalusVoiceLauncher(',
       "floatingActionButton: _tab == 'Overview' ? null : SalusVoiceLauncher(")
diet = 'lib/screens/diet/diet_shell.dart'
change(diet, "import '../premium/salus_nutrition_77.dart';",
       "import '../premium/salus_nutrition_87.dart';")
change(diet, 'SalusNutrition77(', 'SalusNutrition87(')
change(diet, 'floatingActionButton: SalusVoiceLauncher(',
       'floatingActionButton: _index == 0 ? null : SalusVoiceLauncher(')

# Static contracts from old releases were exact string snapshots of the active
# widgets. Correct their expectations; do not disable or delete the tests.
all_tests = list(Path('test').glob('*.dart'))
for path in all_tests:
    original = path.read_text(encoding='utf-8')
    adjusted = original.replace('version: 0.21.48+86', VERSION)
    # Historical visual contract regular expression accepts 87 as newer build.
    if path.name == 'build75_dark_premium_contract_test.dart':
        if '37|38|39|40|41|42|43|44|45|46|47|48|49' not in adjusted:
            adjusted = adjusted.replace('37|38|39|40|41|42|43|44|45|46|47|48',
                '37|38|39|40|41|42|43|44|45|46|47|48|49')
        if '75|76|77|78|79|80|81|82|83|84|85|86|87' not in adjusted:
            adjusted = adjusted.replace('75|76|77|78|79|80|81|82|83|84|85|86',
                '75|76|77|78|79|80|81|82|83|84|85|86|87')
    if path.name in {
        'build73_renderer_contract_test.dart',
        'build77_visual_navigation_contract_test.dart',
        'build85_home_layout_test.dart',
        'build86_preservation_contract_test.dart',
    }:
        adjusted = adjusted.replace('SalusHome77()', 'SalusHome87()')
    if path.name == 'build77_visual_navigation_contract_test.dart':
        adjusted = adjusted.replace('SalusTraining77(', 'SalusTraining87(')
        adjusted = adjusted.replace('SalusNutrition77(', 'SalusNutrition87(')
    if path.name == 'build86_preservation_contract_test.dart':
        adjusted = adjusted.replace("lib/screens/premium/salus_home_77.dart",
                                    "lib/screens/premium/salus_home_87.dart")
    if original != adjusted:
        path.write_text(adjusted, encoding='utf-8')

active = Path(home).read_text(encoding='utf-8')
assert 'SalusHome87()' in active and 'SalusHome85()' not in active
assert 'healthSyncProvider' in active and 'bottomNavigationBar: _SalusBottomNav(' in active
assert 'com.rustnrum.healthyme.beta03' in Path('scripts/prepare_android.sh').read_text()
print('Salus Build87: real data and original routes preserved; Home, Training and Nutrition artwork-led dashboards active')
