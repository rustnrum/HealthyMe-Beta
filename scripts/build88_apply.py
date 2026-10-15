"""Build 88: preserve the real app, restore missing trend and signal cards.

The deployed Build87 is already a validated app. Do not replay historical
patch scripts or mutate module, navigation, permissions or persisted data.
"""
from pathlib import Path
import re

VERSION='version: 0.21.50+88'
pub=Path('pubspec.yaml').read_text(encoding='utf-8')
if not re.search(r'^version: 0\.21\.50\+88\s*$',pub,re.M):
    raise RuntimeError('Expected Build88 version 0.21.50+88')
for name in [
    'lib/screens/premium/salus_home_87.dart',
    'lib/screens/premium/salus87_ui.dart',
    'lib/screens/premium/salus_training_87.dart',
    'lib/screens/premium/salus_nutrition_87.dart',
    'lib/services/recovery_service.dart',
    'lib/services/hrv_source_service.dart',
    'lib/services/direct_metric_service.dart',
    'lib/widgets/salus77_design.dart',
    'lib/widgets/salus_premium_ui.dart',
    'native/android/AndroidManifest.xml',
    'test/build87_visual_preservation_test.dart',
    'test/build88_metrics_contract_test.dart',
]:
    if not Path(name).is_file():raise RuntimeError(f'Missing validated dependency: {name}')

home=Path('lib/screens/premium/salus_home_87.dart').read_text(encoding='utf-8')
for token in [
    'RecoveryService.build(', 'HrvSourceService.resolve(',
    'SalusEnergyService.estimate(', 'HomeInsightService.build(',
    'ref.watch(appStateProvider)', 'ref.watch(dietLogStateProvider)',
    'ref.watch(workoutStateProvider)',
    'S77RestingHeartChart(', 'PremiumLineChart(',
    "health.restingHeartRate30", "hrv.rmssdHistory", "hrv.indexHistory",
    "sample.metric=='Body battery'", "sample.sourceId.isNotEmpty",
    "sample.capturedAt", "sourceLabel", "'Additional Health Metrics'",
    "health.bloodOxygenPercent", "health.respiratoryRate",
    "health.latestHeartRate", "health.activeCaloriesToday",
]:
    if token not in home:raise RuntimeError(f'Home missing a real metric requirement: {token}')
for bad in ['Data.recovery','DESIGN PREVIEW','SAMPLE DATA','SalusHome85(']:
    if bad in home:raise RuntimeError(f'Unacceptable mock data in Home: {bad}')

shell=Path('lib/screens/home_shell.dart').read_text(encoding='utf-8')
for needle in ['SalusHome87()', 'healthSyncProvider', 'bottomNavigationBar: _SalusBottomNav(', 'SalusVoiceLauncher(']:
    if needle not in shell:raise RuntimeError(f'Preservation requirement lost: {needle}')
for name,expect in [('lib/screens/workout_screen.dart','SalusTraining87('),('lib/screens/diet/diet_shell.dart','SalusNutrition87(')]:
    if expect not in Path(name).read_text(encoding='utf-8'):
        raise RuntimeError(f'Existing module implementation changed: {name}')
if 'com.rustnrum.healthyme.beta03' not in Path('scripts/prepare_android.sh').read_text():
    raise RuntimeError('Existing beta Android identity was changed')

# Previous releases contain historical tests with exact version strings.
# Modernize those assertions without disabling functional tests.
for path in Path('test').glob('*.dart'):
    content=path.read_text(encoding='utf-8')
    updated=content.replace('version: 0.21.49+87',VERSION)
    if path.name=='build75_dark_premium_contract_test.dart':
        if '37|38|39|40|41|42|43|44|45|46|47|48|49|50' not in updated:
            updated=updated.replace('37|38|39|40|41|42|43|44|45|46|47|48|49',
                '37|38|39|40|41|42|43|44|45|46|47|48|49|50')
        if '75|76|77|78|79|80|81|82|83|84|85|86|87|88' not in updated:
            updated=updated.replace('75|76|77|78|79|80|81|82|83|84|85|86|87',
                '75|76|77|78|79|80|81|82|83|84|85|86|87|88')
    if content!=updated:path.write_text(updated,encoding='utf-8')
print('Build88: real RHR/HRV trends, body battery, additional metrics; old routes/data intact')
