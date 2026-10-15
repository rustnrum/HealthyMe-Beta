"""Build 86 safety boundary: restore the original live-data beta Home.

Build 85 accidentally made an illustrative mockup the real dashboard. The
original Home and all data-driven services remain in the repository. This
preflight preserves the historical Android/native build and updates only stale
static test expectations that were rewritten to assert the mockup is active.
No sample readings are promoted to production values and no data migration runs.
"""
from pathlib import Path
import re

pubspec = Path('pubspec.yaml').read_text(encoding='utf-8')
if not re.search(r'^version:\s*0\.21\.48\+86\s*$', pubspec, re.M):
    raise RuntimeError('Recovery build requires exactly version 0.21.48+86.')
home = Path('lib/screens/home_shell.dart').read_text(encoding='utf-8')
old = Path('lib/screens/premium/salus_home_77.dart').read_text(encoding='utf-8')
required_home = ['SalusHome77()', 'SalusVoiceLauncher(',
                 'bottomNavigationBar: _SalusBottomNav(', 'healthSyncProvider']
for token in required_home:
    if token not in home:
        raise RuntimeError(f'Original Home capability missing: {token}')
if 'SalusHome85()' in home or 'SalusHome85Nav(' in home:
    raise RuntimeError('Sample-data design preview must not be active Home.')
for token in ['RecoveryService.build(', 'HrvSourceService.resolve(',
              'HomeInsightService.build(', 'ref.watch(appStateProvider)',
              'Navigator.pushNamed', 'SalusEnergyService.estimate(']:
    if token not in old:
        raise RuntimeError(f'Original live Home service missing: {token}')
for asset in ['assets/premium/salus_mountain_79.webp',
              'assets/premium/salus_mountain_85.webp',
              'assets/preview84/img/ring_recovery.png']:
    if not Path(asset).is_file():
        raise RuntimeError(f'Preserved design reference missing: {asset}')

# Existing Build85 tests (committed by the previous workflow) assert Home85
# as the production screen, which is precisely the regression we're fixing.
# Update those exact source-contract strings; leave functional tests intact.
updates = {
    'test/build73_renderer_contract_test.dart': [
        ('SalusHome85()', 'SalusHome77()'),
    ],
    'test/build76_light_dark_navigation_contract_test.dart': [
        ('SalusHome85Nav(', 'bottomNavigationBar: _SalusBottomNav('),
    ],
    'test/build77_visual_navigation_contract_test.dart': [
        ('SalusHome85()', 'SalusHome77()'),
        ('SalusHome85Nav(', 'bottomNavigationBar: _SalusBottomNav('),
    ],
    'test/build78_visual_match_test.dart': [
        ('SalusHome85Nav(', 'bottomNavigationBar: _SalusBottomNav('),
    ],
    'test/build80_design_energy_contract_test.dart': [
        ('SalusHome85Nav(', 'bottomNavigationBar: _SalusBottomNav('),
    ],
    'test/build75_dark_premium_contract_test.dart': [
        ('37|38|39|40|41|42|43|44|45|46|47',
         '37|38|39|40|41|42|43|44|45|46|47|48'),
        ('75|76|77|78|79|80|81|82|83|84|85',
         '75|76|77|78|79|80|81|82|83|84|85|86'),
    ],
}
version_tests = (
    'build76_light_dark_navigation_contract_test.dart',
    'build77_visual_navigation_contract_test.dart',
    'build78_visual_match_test.dart',
    'build79_energy_contract_test.dart',
    'build80_design_energy_contract_test.dart',
    'build81_rhr_hrv_contract_test.dart',
    'build82_ring_hrv_visibility_test.dart',
    'build83_hrv_sources_test.dart',
)
for name in version_tests:
    updates.setdefault('test/' + name, []).append(
        ('version: 0.21.47+85', 'version: 0.21.48+86'))

for filepath, changes in updates.items():
    path = Path(filepath)
    content = path.read_text(encoding='utf-8')
    for prev, current in changes:
        if prev == current:
            continue
        if current in content:
            if content.count(current) != 1:
                raise RuntimeError(f'{filepath}: duplicated migrated contract {current!r}')
            continue  # Old alternatives can be a prefix of the migrated regex.
        if content.count(prev) != 1:
            raise RuntimeError(f'{filepath}: expected one {prev!r}, found {content.count(prev)}')
        content = content.replace(prev, current, 1)
    path.write_text(content, encoding='utf-8')
print('Salus recovery Build 86: original provider-connected Home, tabs and voice preserved; legacy tests updated')
